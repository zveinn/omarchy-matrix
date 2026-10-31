import QtQuick

// Matrix glyph decode in/out (sveinn): the exact effect the matrix theme plays
// for a window toggle / workspace switch (rain/TransitionFx.qml, winfx.frag
// mode 0, copied here so the plugin stays self-contained). An opaque block
// of 14px scrambling katakana covers `target`; the cells resolve top-left ->
// bottom-right with noise, each flaring white before it vanishes.
//   playIn()        : block -> content, 200 ms InOutQuad.
//   playOut(fn, lead): the reverse (cells scramble back in bottom-right ->
//                     top-left), then fn(); the full block is held while
//                     hidden so a remap never flashes stale content. `lead`
//                     ms calls fn that much earlier (for hosts that fade).
//   cloak           : optional content item that is made transparent while
//                     the block is held, so the host's own fade-out after
//                     hide shows only the glyph block (no ghost of the
//                     content through it); restored on reset()/playIn().
// Never takes input; nothing ticks while idle.
Item {
  id: gd

  property Item target: null
  property int duration: 200
  property real prog: 1
  property real time: 0
  property bool held: false
  property bool outgoing: false
  property var doneFn: null
  property Item cloak: null
  readonly property bool running: anim.running

  enabled: false
  visible: anim.running || held
  z: 100
  width: target ? target.width : (parent ? parent.width : 0)
  height: target ? target.height : (parent ? parent.height : 0)

  function place() {
    if (gd.target && gd.parent && gd.target !== gd.parent) {
      var p = gd.parent.mapFromItem(gd.target, 0, 0)
      gd.x = p.x
      gd.y = p.y
    } else {
      gd.x = 0
      gd.y = 0
    }
  }

  function reset() {
    anim.stop()
    lead.stop()
    gd.doneFn = null
    gd.outgoing = false
    gd.held = false
    gd.prog = 1
    if (gd.cloak && gd.cloak.opacity === 0) gd.cloak.opacity = 1
  }

  function playIn() {
    reset()
    place()
    gd.prog = 0
    anim.from = 0
    anim.to = 1
    anim.duration = gd.duration
    anim.start()
  }

  function playOut(fn, leadMs) {
    var from = (anim.running && !gd.outgoing) ? gd.prog : 1
    anim.stop()
    lead.stop()
    place()
    gd.held = false
    gd.outgoing = true
    gd.doneFn = fn || null
    gd.prog = from
    anim.from = from
    anim.to = 0
    anim.duration = Math.max(1, Math.round(gd.duration * from))
    anim.start()
    if (leadMs > 0 && anim.duration > leadMs) {
      lead.interval = anim.duration - leadMs
      lead.start()
    }
  }

  function fire() {
    var f = gd.doneFn
    gd.doneFn = null
    if (f) f()
  }

  NumberAnimation {
    id: anim
    target: gd
    property: "prog"
    easing.type: Easing.InOutQuad
    onFinished: {
      if (gd.outgoing) {
        gd.held = true
        if (gd.cloak) gd.cloak.opacity = 0
        gd.fire()
      } else {
        gd.held = false
      }
    }
  }
  Timer { id: lead; onTriggered: gd.fire() }

  FrameAnimation { running: anim.running; onTriggered: gd.time += frameTime * 2.0 }

  // 8x8 atlas of 64px katakana, as in TransitionFx.qml
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
    property real time: gd.time
    property real prog: gd.prog
    property real fmode: 0
    property real blockH: height
    property real cell: 14
    property real atlasCols: 8
    property real atlasCount: 64
    property vector2d res: Qt.vector2d(width, height)
    property variant atlas: atlasTex
    fragmentShader: Qt.resolvedUrl("winfx.frag.qsb")
  }
}
