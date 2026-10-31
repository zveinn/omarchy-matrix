import QtQuick

// Matrix open/close for the Omarchy menu card. Both directions are
// the matrix theme's window-toggle glyph decode (GlyphDecode.qml = the
// theme's rain/TransitionFx winfx mode 0, 200 ms InOutQuad), the same as
// the bar panels. Purely visual: the window maps, takes focus and accepts
// typing on its first frame.
//   open : an opaque block of scrambling katakana over the card resolves
//          top-left -> bottom-right, each cell flaring white (200 ms);
//          the scrim fades in (140 ms).
//   close: the reverse (cells scramble back in bottom-right -> top-left,
//          200 ms) with the scrim fading out alongside, then hide.
// Plain Items, never take input; nothing ticks while idle.
Item {
  id: fx

  property Item card: null
  property bool active: false
  property color color: "#00ff41"
  property color hotColor: "#eaffea"
  property color coverColor: "#000602"
  property real columnWidth: 16
  property real glyphSize: 14
  property bool closing: false
  property real scrimOpacity: 1
  // the card's visual scale (for the glyph ring); the decode never scales
  readonly property real scaleX: 1
  readonly property real scaleY: 1

  signal closeFinished()

  z: 50

  // The decode is reparented onto the card so the glyph block covers the
  // border too.
  function attach() {
    if (!fx.card) return false
    if (dec.parent !== fx.card) dec.parent = fx.card
    dec.target = fx.card
    return true
  }

  function detach() {}

  function reset() {
    scrimAnim.stop()
    dec.reset()
    fx.closing = false
    fx.scrimOpacity = 1
  }

  function playOpen() {
    reset()
    if (!fx.active || !attach()) return
    fx.scrimOpacity = 0
    scrimAnim.to = 1
    scrimAnim.duration = 140
    scrimAnim.start()
    dec.playIn()
  }

  // Returns false when there is nothing to animate (caller hides at once).
  function playClose() {
    if (!fx.active || !attach()) return false
    fx.closing = true
    scrimAnim.stop()
    scrimAnim.to = 0
    scrimAnim.duration = 200
    scrimAnim.start()
    dec.playOut(fx.finishClose)
    return true
  }

  function finishClose() {
    if (!fx.closing) return
    // Hide first, then drop `closing`, so focus/input never flick back on
    // a still-mapped surface. The glyph block stays over the card while
    // hidden (no stale full frame on remap); the next playOpen()/reset()
    // clears it.
    fx.closeFinished()
    fx.closing = false
  }

  NumberAnimation { id: scrimAnim; target: fx; property: "scrimOpacity" }

  GlyphDecode { id: dec }
}
