// Matrix transitions, driven over IPC ("transfx") by the theme's hyprland.lua:
//   workspace N   code curtain pours down the screen + "[ 0N ]" decodes centre
//   open x y w h  new window materializes out of a block of glyphs
//   close x y w h closing window de-rezzes: glyph columns drop away
//   toggle x y w h fullscreen/floating toggle: same materialize as open (mode 2 rescan kept in winfx.frag, unused)
// Click-through overlay, idle when nothing is playing.
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
  id: fx
  required property var modelData
  screen: modelData
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "matrix-transfx"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  readonly property string glyphs: "ｦｱｳｴｵｶｷｹｺｻｼｽｾｿﾀﾂﾃﾅﾆﾇﾈﾊﾋﾎﾏﾐﾑﾒﾓﾔﾕﾗﾘﾜ012345789Z"
  function pick() { return glyphs.charAt(Math.floor(Math.random() * glyphs.length)) }

  // ── glyph atlas ──────────────────────────────────────────────────────────
  Grid {
    id: tAtlas
    columns: 8
    readonly property string g: "ｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123457789Z:.=*+-<>¦|ｸ"
    Repeater {
      model: 64
      Text {
        required property int index
        width: 64; height: 64
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        text: tAtlas.g.charAt(index % tAtlas.g.length)
        color: "white"; font.family: "Noto Sans CJK JP"; font.pixelSize: 54; font.bold: true
      }
    }
  }
  ShaderEffectSource { id: tTex; sourceItem: tAtlas; hideSource: true; smooth: true; mipmap: true }

  function local(x, y, w, h) {
    const sx = modelData.x, sy = modelData.y
    if (x + w < sx || y + h < sy || x > sx + modelData.width || y > sy + modelData.height) return null
    return { x: x - sx, y: y - sy, w: w, h: h }
  }

  function workspace(id) {
    wsLabel.target = "[ " + (id < 10 ? "0" + id : "" + id) + " ]"
    wsAnim.restart()
  }
  function windowFx(mode, x, y, w, h) {
    const r = local(x, y, w, h)
    if (!r || w < 60 || h < 40) return
    winModel.append({ mode: mode, rx: r.x, ry: r.y, rw: r.w, rh: r.h })
  }

  // ── workspace curtain ──────────────────────────────────────────────────
  ShaderEffect {
    id: curtain
    anchors.fill: parent
    visible: wsAnim.running
    property real time: 0
    property real prog: 0
    property real cell: 20
    property real atlasCols: 8
    property real atlasCount: 64
    property vector2d res: Qt.vector2d(width, height)
    property variant atlas: tTex
    fragmentShader: Qt.resolvedUrl("wsfx.frag.qsb")
    FrameAnimation { running: wsAnim.running; onTriggered: curtain.time += frameTime }
  }
  Rectangle {
    id: wsBox
    anchors.centerIn: parent
    visible: wsAnim.running
    color: "#f2010502"; border.color: "#00ff41"; border.width: 1
    width: wsLabel.implicitWidth + 40; height: wsLabel.implicitHeight + 18
    opacity: 0
    Text {
      id: wsLabel
      property string target: ""
      property int n: 0
      anchors.centerIn: parent
      color: "#f5f7fa"; font.family: "Hurmit Nerd Font"; font.pixelSize: 34; font.bold: true
    }
  }
  Timer {
    id: wsDecode
    interval: 30; repeat: true; running: wsAnim.running
    onRunningChanged: if (running) wsLabel.n = 0
    onTriggered: {
      wsLabel.n++
      const reveal = Math.floor(wsLabel.n / 2)
      let o = ""
      for (let i = 0; i < wsLabel.target.length; i++) {
        const ch = wsLabel.target[i]
        o += (i < reveal || ch === " " || ch === "[" || ch === "]") ? ch : fx.pick()
      }
      wsLabel.text = o
    }
  }
  SequentialAnimation {
    id: wsAnim
    ScriptAction { script: { curtain.prog = 0; wsBox.opacity = 0 } }
    ParallelAnimation {
      NumberAnimation { target: curtain; property: "prog"; from: 0; to: 1; duration: 380; easing.type: Easing.OutSine }
      SequentialAnimation {
        NumberAnimation { target: wsBox; property: "opacity"; to: 1; duration: 80 }
        PauseAnimation { duration: 200 }
        NumberAnimation { target: wsBox; property: "opacity"; to: 0; duration: 140 }
      }
    }
  }

  // ── window open / close ────────────────────────────────────────────────
  ListModel { id: winModel }
  Repeater {
    model: winModel
    ShaderEffect {
      id: wfx
      required property int index
      required property int mode
      required property real rx
      required property real ry
      required property real rw
      required property real rh
      x: rx; y: ry; width: rw
      height: mode === 1 ? Math.max(rh, fx.height - ry) : rh   // close: room to fall
      property real time: 0
      property real prog: 0
      property real fmode: mode   // uniform must be a real, not an int
      property real blockH: rh
      property real cell: 14
      property real atlasCols: 8
      property real atlasCount: 64
      property vector2d res: Qt.vector2d(width, height)
      property variant atlas: tTex
      fragmentShader: Qt.resolvedUrl("winfx.frag.qsb")
      FrameAnimation { running: true; onTriggered: wfx.time += frameTime * 2.0 }
      NumberAnimation on prog {
        from: 0; to: 1
        duration: wfx.mode === 1 ? 420 : wfx.mode === 2 ? 300 : 200
        easing.type: wfx.mode === 1 ? Easing.Linear : wfx.mode === 2 ? Easing.OutQuad : Easing.InOutQuad
        onFinished: cleanup.start()
      }
      Timer { id: cleanup; interval: 16; onTriggered: { for (let i = winModel.count - 1; i >= 0; i--) if (winModel.get(i).rx === wfx.rx && winModel.get(i).ry === wfx.ry && winModel.get(i).mode === wfx.mode) { winModel.remove(i); break } } }
    }
  }
}
