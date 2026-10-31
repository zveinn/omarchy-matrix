// Matrix digital rain, movie style: pure black, full-screen columns of mirrored
// half-width katakana and digits streaming down fast, white-hot heads, green
// trails, glyphs mutating in place. Nothing else is drawn. Rendered on the GPU
// (rain.frag -> rain.frag.qsb). Opaque layer on WlrLayer.Bottom: covers the
// wallpaper, sits behind windows, click-through. Managed by ./matrix-rain.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
  id: shell
  property string themeName: "matrix"
  readonly property bool themeActive: themeName.trim() === "matrix"

  FileView {
    id: themeFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: shell.themeName = text()
  }

  signal ringList(string list)
  // hyprland.lua appends "ring|trans <cmd> args..." lines to this file
  FileView {
    id: fxFeed
    property int done: -1
    path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/matrix-fx"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      const lines = text().split("\n")
      const n = lines.length - 1
      if (done < 0 || n < done) done = (done < 0 ? n : 0)
      for (let i = done; i < n; i++) {
        const p = lines[i].trim().split(/\s+/)
        const v = p.slice(2).map(Number)
        if (p[0] === "ring" && p[1] === "list") shell.ringList(lines[i].trim().slice(9).trim())
        else if (p[0] === "trans") {
          if (p[1] === "workspace") shell.transCmd("ws", v[0], 0, 0, 0, 0)
          else shell.transCmd(p[1], 0, v[0], v[1], v[2], v[3])
        }
      }
      done = n
    }
  }
  signal transCmd(string cmd, int a, int x, int y, int w, int h)
  IpcHandler {
    target: "transfx"
    function workspace(id: int): void { shell.transCmd("ws", id, 0, 0, 0, 0) }
    function open(x: int, y: int, w: int, h: int): void { shell.transCmd("open", 0, x, y, w, h) }
    function close(x: int, y: int, w: int, h: int): void { shell.transCmd("close", 0, x, y, w, h) }
  }
  Variants {
    model: Quickshell.screens
    TransitionFx {
      id: tfx
      visible: shell.themeActive
      Connections {
        target: shell
        function onTransCmd(cmd, a, x, y, w, h) {
          if (cmd === "ws") tfx.workspace(a)
          else tfx.windowFx(0, x, y, w, h)  // open, close and toggle all use the glyph decode (mode 0)
        }
      }
    }
  }

  // glyph-ring borders: tiled windows' rings on the Bottom layer (in the gaps,
  // under every window), floating windows' rings on Overlay
  Variants {
    model: Quickshell.screens
    FocusFx {
      id: ffxT
      atlasSource: null
      floatLayer: false
      visible: shell.themeActive
      Connections {
        target: shell
        function onRingList(list) { ffxT.setList(list) }
      }
      // own glyph atlas for the scan shader
      Grid {
        id: fAtlasT
        columns: 8
        readonly property string g: "ｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123457789Z:.=*+-<>¦|ｸ"
        Repeater {
          model: 64
          Text {
            required property int index
            width: 64; height: 64
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: fAtlasT.g.charAt(index % fAtlasT.g.length)
            color: "white"; font.family: "Noto Sans CJK JP"; font.pixelSize: 54; font.bold: true
          }
        }
      }
      ShaderEffectSource { id: fTexT; sourceItem: fAtlasT; hideSource: true; smooth: true; mipmap: true }
      Component.onCompleted: atlasSource = fTexT
    }
  }
  Variants {
    model: Quickshell.screens
    FocusFx {
      id: ffxF
      atlasSource: null
      floatLayer: true
      visible: shell.themeActive
      Connections {
        target: shell
        function onRingList(list) { ffxF.setList(list) }
      }
      // own glyph atlas for the scan shader
      Grid {
        id: fAtlasF
        columns: 8
        readonly property string g: "ｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123457789Z:.=*+-<>¦|ｸ"
        Repeater {
          model: 64
          Text {
            required property int index
            width: 64; height: 64
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            text: fAtlasF.g.charAt(index % fAtlasF.g.length)
            color: "white"; font.family: "Noto Sans CJK JP"; font.pixelSize: 54; font.bold: true
          }
        }
      }
      ShaderEffectSource { id: fTexF; sourceItem: fAtlasF; hideSource: true; smooth: true; mipmap: true }
      Component.onCompleted: atlasSource = fTexF
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      color: "black"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.namespace: "matrix-rain"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      mask: Region {}
      visible: shell.themeActive

      // Glyph atlas: 8x8 grid rendered once into a texture for the shader.
      Grid {
        id: atlasSrc
        columns: 8
        readonly property string glyphs: "ｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123457789Z:.=*+-<>¦|ｸ"
        Repeater {
          model: 64
          Text {
            required property int index
            width: 64; height: 64
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: atlasSrc.glyphs.charAt(index % atlasSrc.glyphs.length)
            color: "white"
            font.family: "Noto Sans CJK JP"
            font.pixelSize: 54
            font.bold: true
          }
        }
      }
      ShaderEffectSource {
        id: atlasTex
        sourceItem: atlasSrc
        hideSource: true
        smooth: true
        mipmap: true
      }

      ShaderEffect {
        id: fx
        anchors.fill: parent
        property real time: 0
        property real cell: 24
        property real atlasCols: 8
        property real atlasCount: 64
        property vector2d res: Qt.vector2d(width, height)
        property variant atlas: atlasTex
        fragmentShader: Qt.resolvedUrl("rain.frag.qsb")
        FrameAnimation {
          running: shell.themeActive
          onTriggered: fx.time += frameTime
        }
      }
    }
  }
}
