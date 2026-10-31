// Glyph-ring borders for the matrix theme. Driven by the theme's hyprland.lua
// over the matrix-fx feed: every window on a visible workspace gets a one-cell
// ring of tiny katakana in the gap just OUTSIDE it (never over its content).
// Inactive rings are green and scramble slowly; the focused window's ring is
// orange, scrambles faster and races in from the top-left when it gains focus.
// Two instances per screen: floatLayer false = tiled windows' rings on the
// Bottom layer (above the rain, under every window); floatLayer true = floating
// windows' rings on Overlay, with any floating window stacked above cut out.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
  id: fx
  required property var modelData
  property var atlasSource
  property bool floatLayer: false
  screen: modelData
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  // the Bottom instance starts parked on Overlay and drops to Bottom once the
  // rain is mapped, so it always lands above the rain
  property bool armed: false
  WlrLayershell.layer: (fx.floatLayer || !fx.armed) ? WlrLayer.Overlay : WlrLayer.Bottom
  WlrLayershell.namespace: fx.floatLayer ? "matrix-ring-float" : "matrix-ring"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}
  onVisibleChanged: { armed = false; if (visible) armTimer.restart() }
  Timer { id: armTimer; interval: 700; running: true; onTriggered: fx.armed = true }

  readonly property int band: 9          // ring thickness = glyph cell, fits the half-gap (gaps_in 9)
  property real activeTime: 0
  property real idleTime: 0
  readonly property color activeTint: "#00ff41"
  readonly property color idleTint: "#00872a"   // dimmed green for inactive windows

  ListModel { id: rings }

  // list: "addr x y w h floating active [mx my mw mh ...];..."
  function setList(list) {
    const want = []
    for (const e of list.split(";")) {
      const p = e.trim().split(/\s+/)
      if (p.length < 7) continue
      if ((p[5] === "1") !== fx.floatLayer) continue
      const n = p.slice(1).map(Number)
      want.push({ addr: p[0], gx: n[0], gy: n[1], gw: n[2], gh: n[3], act: n[5] === 1, masks: p.slice(7).join(" ") })
    }
    const keep = {}
    for (const w of want) keep[w.addr] = true
    for (let i = rings.count - 1; i >= 0; i--) if (!keep[rings.get(i).addr]) rings.remove(i)
    want.forEach((w, k) => {
      let i = -1
      for (let j = 0; j < rings.count; j++) if (rings.get(j).addr === w.addr) { i = j; break }
      if (i < 0) { rings.insert(Math.min(k, rings.count), w); return }
      if (i !== k && k < rings.count) { rings.move(i, k, 1); i = k }
      for (const key of ["gx", "gy", "gw", "gh", "act", "masks"])
        if (rings.get(i)[key] !== w[key]) rings.setProperty(i, key, w[key])
    })
  }

  Repeater {
    model: rings
    ShaderEffect {
      id: ring
      required property string addr
      required property real gx; required property real gy
      required property real gw; required property real gh
      required property bool act
      required property string masks
      required property int index
      x: gx - fx.modelData.x - fx.band; y: gy - fx.modelData.y - fx.band
      width: gw + 2 * fx.band; height: gh + 2 * fx.band
      property real boost: 0
      property real time: (act ? fx.activeTime : fx.idleTime) + boost + index * 3.7
      property real prog: 0
      property real fade: 0
      property real cell: fx.band
      property real atlasCols: 8
      property real atlasCount: 64
      property vector2d res: Qt.vector2d(width, height)
      property variant atlas: fx.atlasSource
      property color tint: act ? fx.activeTint : fx.idleTint
      property real bright: act ? 1.6 : 1.0
      property vector4d m0: mrect(0)
      property vector4d m1: mrect(1)
      property vector4d m2: mrect(2)
      property vector4d m3: mrect(3)
      // a floating window above, in this ring's pixels (w = 0: unused)
      function mrect(k) {
        const v = masks.length ? masks.split(" ").map(Number) : []
        if (v.length < k * 4 + 4) return Qt.vector4d(0, 0, 0, 0)
        return Qt.vector4d(v[k * 4] - gx + fx.band, v[k * 4 + 1] - gy + fx.band, v[k * 4 + 2], v[k * 4 + 3])
      }
      fragmentShader: Qt.resolvedUrl("focus.frag.qsb")
      Component.onCompleted: intro.restart()
      onActChanged: if (act) intro.restart()
      SequentialAnimation {
        id: intro
        ScriptAction { script: { ring.prog = 0; ring.fade = 0 } }
        NumberAnimation { target: ring; property: "prog"; from: 0; to: 1; duration: 380; easing.type: Easing.OutCubic }
      }
      // faster scramble during the race-in
      FrameAnimation { running: intro.running; onTriggered: ring.boost += frameTime * 0.6 }
    }
  }

  // focused ring scrambles a bit faster than the idle ones
  Timer { interval: 70;  repeat: true; running: fx.visible && rings.count > 0; onTriggered: fx.activeTime += 0.035 }
  Timer { interval: 220; repeat: true; running: fx.visible && rings.count > 0; onTriggered: fx.idleTime += 0.03 }

  // ask hyprland.lua to resend the ring list after this process (re)starts
  Process {
    running: true
    command: ["hyprctl", "repl", "if matrix_ring_resync then matrix_ring_resync() end"]
  }
}
