// Matrix screensaver: the wallpaper's digital rain (same shader, ../rain/rain.frag.qsb,
// same uniforms) fullscreen on every monitor, on the Overlay layer above all windows and
// the bar. Nothing else is drawn. Any key, click, wheel or mouse movement quits.
// Launched by ~/.local/bin/omarchy-launch-screensaver via ./matrix-screensaver.
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  id: root
  property bool armed: false   // ignore the pointer-enter event fired as the layer maps
  function dismiss() { Qt.quit() }
  Timer { interval: 600; running: true; onTriggered: root.armed = true }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: win
      required property var modelData
      screen: modelData
      color: "black"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "org.omarchy.screensaver"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

      FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(e) { e.accepted = true; root.dismiss() }

        // Glyph atlas: identical to rain/shell.qml so the look matches exactly.
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
        ShaderEffectSource { id: atlasTex; sourceItem: atlasSrc; hideSource: true; smooth: true; mipmap: true }

        ShaderEffect {
          id: fx
          anchors.fill: parent
          property real time: 0
          property real cell: 24
          property real atlasCols: 8
          property real atlasCount: 64
          property vector2d res: Qt.vector2d(width, height)
          property variant atlas: atlasTex
          fragmentShader: Qt.resolvedUrl("rain.frag.qsb")  // symlink to ../rain/rain.frag.qsb (quickshell blocks URLs outside the config dir)
          opacity: 0
          NumberAnimation on opacity { from: 0; to: 1; duration: 400 }
          FrameAnimation { running: true; onTriggered: fx.time += frameTime }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.AllButtons
          cursorShape: Qt.BlankCursor
          property point p0: Qt.point(-1, -1)
          onPressed: root.dismiss()
          onWheel: root.dismiss()
          onPositionChanged: function(m) {
            if (!root.armed || p0.x < 0) { p0 = Qt.point(m.x, m.y); return }
            if (Math.abs(m.x - p0.x) + Math.abs(m.y - p0.y) > 6) root.dismiss()
          }
        }
      }
    }
  }
}
