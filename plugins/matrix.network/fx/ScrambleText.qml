import QtQuick
import "Glyphs.js" as Glyphs

// A label that "decodes" into place: every character churns through
// katakana/digits and locks to the real one, left to right, with a bright
// leading edge. Laid out per character on the real font's advances, so the
// resolved frame sits exactly where the real label is drawn. Only visible
// (and only ticking) while an animation is playing.
Item {
  id: root

  property string text: ""
  property string fontFamily: "monospace"
  property real pixelSize: 12
  property bool bold: false
  property color color: "#00ff41"
  property color hotColor: "#eaffea"
  property string glyphFamily: "Noto Sans CJK JP"
  property int renderType: Text.NativeRendering

  property var chars: []
  property var widths: []
  property var resolveAt: []
  property int frame: 0
  property int frames: 12
  readonly property bool running: ticker.running

  signal finished()

  implicitWidth: row.implicitWidth
  implicitHeight: metrics.height
  width: implicitWidth
  height: implicitHeight
  visible: running

  FontMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: Math.max(1, root.pixelSize)
    font.bold: root.bold
  }

  // mode: "full"   every glyph scrambles and resolves left to right
  //       "glitch" two or three glyphs flicker and snap back
  function play(mode, duration) {
    var t = String(root.text)
    if (t.length === 0 || t.indexOf("\n") !== -1) return
    root.frames = Math.max(4, Math.round((duration || 360) / ticker.interval))
    var w = [], r = []
    var picks = {}
    if (mode === "glitch") {
      var n = Math.min(3, Math.max(1, Math.floor(t.length / 4)))
      for (var p = 0; p < n * 3 && Object.keys(picks).length < n; p++) {
        var k = Math.floor(Math.random() * t.length)
        if (t.charAt(k) !== " ") picks[k] = true
      }
    }
    for (var i = 0; i < t.length; i++) {
      w.push(metrics.advanceWidth(t.charAt(i)))
      if (mode === "glitch") {
        r.push(picks[i] ? Math.round(root.frames * (0.45 + Math.random() * 0.55)) : 0)
      } else {
        var lead = root.frames * 0.2 + (i / Math.max(1, t.length)) * root.frames * 0.62
        r.push(Math.min(root.frames - 1, Math.round(lead + Math.random() * root.frames * 0.18)))
      }
    }
    root.widths = w
    root.resolveAt = r
    root.frame = 0
    root.step()
    ticker.restart()
  }

  function stop() {
    ticker.stop()
  }

  function step() {
    var t = String(root.text)
    var out = []
    for (var i = 0; i < root.widths.length; i++) {
      var real = t.charAt(i)
      var at = root.resolveAt[i] || 0
      if (real === " " || root.frame >= at) {
        out.push({ c: real, k: false, m: false, h: root.frame - at < 2 && at > 0, s: false })
      } else {
        var g = Glyphs.random()
        out.push({ c: g, k: Glyphs.isKata(g), m: Math.random() < 0.5, h: root.frame + 1 >= at, s: true })
      }
    }
    root.chars = out
  }

  Timer {
    id: ticker
    interval: 33
    repeat: true
    onTriggered: {
      root.frame++
      if (root.frame > root.frames + 1) {
        ticker.stop()
        root.finished()
        return
      }
      root.step()
    }
  }

  Row {
    id: row
    anchors.centerIn: parent

    Repeater {
      model: root.running ? root.widths.length : 0

      Item {
        id: cellItem
        required property int index
        readonly property var cell: root.chars[index] || ({ c: "", k: false, m: false, h: false, s: false })
        width: root.widths[index] || 0
        height: metrics.height

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: cellItem.cell.c
          font.family: cellItem.cell.k ? root.glyphFamily : root.fontFamily
          font.pixelSize: Math.max(1, cellItem.cell.k ? root.pixelSize * 0.92 : root.pixelSize)
          font.bold: root.bold
          color: cellItem.cell.h ? root.hotColor : root.color
          opacity: cellItem.cell.s && !cellItem.cell.h ? 0.82 : 1
          renderType: root.renderType
          transform: Scale {
            origin.x: cellItem.width / 2
            xScale: cellItem.cell.m ? -1 : 1
          }
        }
      }
    }
  }
}
