import QtQuick

// Glyph-ring border for the launcher card (sveinn). Same shader and focused
// style as the matrix theme's window rings (focus.frag, copied here so the
// plugin is self-contained): a one-cell band of katakana drawn just OUTSIDE
// the card's visual edge (follows the open/close scale and every resize),
// never over the card and never taking input.
//   open : races in from the top-left both ways round with a white-hot
//          front (240 ms, OutCubic), scrambling faster while it runs.
//   close: dissolves cell by cell (200 ms), alongside the card's glyph
//          decode-out.
Item {
  id: ring

  property Item target: null
  property real scaleX: 1
  property real scaleY: 1
  property int band: 9
  property color tint: "#00ff41"
  property real bright: 1.6
  property real prog: 0
  property real fade: 0
  property real time: 0
  property real boost: 0

  enabled: false
  visible: !!target && prog > 0 && fade < 1

  readonly property real vw: target ? target.width * scaleX : 0
  readonly property real vh: target ? target.height * scaleY : 0
  x: target ? target.x + (target.width - vw) / 2 - band : 0
  y: target ? target.y + (target.height - vh) / 2 - band : 0
  width: vw + 2 * band
  height: vh + 2 * band

  function playOpen() {
    closeAnim.stop()
    fade = 0
    prog = 0
    introAnim.restart()
  }

  function playClose() {
    introAnim.stop()
    if (prog <= 0) return
    closeAnim.restart()
  }

  function reset() {
    introAnim.stop()
    closeAnim.stop()
    prog = 0
    fade = 0
  }

  NumberAnimation { id: introAnim; target: ring; property: "prog"; from: 0; to: 1; duration: 240; easing.type: Easing.OutCubic }
  NumberAnimation { id: closeAnim; target: ring; property: "fade"; from: 0; to: 1; duration: 200 }

  // focused-window scramble rate, faster during the race-in
  Timer { interval: 70; repeat: true; running: ring.visible; onTriggered: ring.time += 0.035 }
  FrameAnimation { running: introAnim.running; onTriggered: ring.boost += frameTime * 0.6 }

  // 8x8 atlas of 64px katakana, rendered once into a texture
  Grid {
    id: atlasSrc
    columns: 8
    readonly property string g: "ｦｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ0123457789Z:.=*+-<>¦|ｸ"
    Repeater {
      model: 64
      Text {
        required property int index
        width: 64; height: 64
        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        text: atlasSrc.g.charAt(index % atlasSrc.g.length)
        color: "white"; font.family: "Noto Sans CJK JP"; font.pixelSize: 54; font.bold: true
      }
    }
  }
  ShaderEffectSource { id: atlasTex; sourceItem: atlasSrc; hideSource: true; smooth: true; mipmap: true }

  ShaderEffect {
    anchors.fill: parent
    property real time: ring.time + ring.boost
    property real prog: ring.prog
    property real fade: ring.fade
    property real cell: ring.band
    property real atlasCols: 8
    property real atlasCount: 64
    property vector2d res: Qt.vector2d(width, height)
    property variant atlas: atlasTex
    property color tint: ring.tint
    property real bright: ring.bright
    property vector4d m0: Qt.vector4d(0, 0, 0, 0)
    property vector4d m1: Qt.vector4d(0, 0, 0, 0)
    property vector4d m2: Qt.vector4d(0, 0, 0, 0)
    property vector4d m3: Qt.vector4d(0, 0, 0, 0)
    fragmentShader: Qt.resolvedUrl("focus.frag.qsb")
  }
}
