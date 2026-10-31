import QtQuick
import "Glyphs.js" as Glyphs

// A label that "decodes" into place, the menu's variant of
// matrix.*/fx/ScrambleText.qml: every character churns through half-width
// katakana/digits and locks to the real one, flaring white as it lands.
// Laid out per character on the real font's advances, so the resolved frame
// sits exactly on the real label. Only visible (and only ticking) while
// playing; the host hides its real Text while `running`.
//
// play(mode, duration, elapsed)
//   mode "full"   every glyph scrambles and resolves left to right
//        "glitch" one to three glyphs flicker and snap back (selection)
//        "tail"   only the last glyph churns (a freshly typed character)
//   elapsed       ms already spent: > 0 resumes mid-way (a delegate that was
//                 recreated during the decode), < 0 holds fully scrambled
//                 first (row stagger).
Item {
  id: root

  property string text: ""
  property string fontFamily: "monospace"
  property real pixelSize: 12
  property int fontWeight: Font.Normal
  property color color: "#00ff41"
  property color hotColor: "#eaffea"
  property string glyphFamily: "Noto Sans CJK JP"
  property int renderType: Text.QtRendering

  property var chars: []
  property var widths: []
  property var resolveAt: []
  property int frame: 0
  property int frames: 6
  property string playedText: ""
  readonly property bool running: ticker.running

  signal finished()

  implicitWidth: row.implicitWidth
  implicitHeight: metrics.height
  width: implicitWidth
  height: implicitHeight
  visible: running

  onTextChanged: if (ticker.running && root.text !== root.playedText) root.stop()

  FontMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: Math.max(1, root.pixelSize)
    font.weight: root.fontWeight
  }

  function play(mode, duration, elapsed) {
    var t = String(root.text)
    if (t.length === 0 || t.length > 72 || t.indexOf("\n") !== -1 || /[\uD800-\uDFFF]/.test(t)) {
      root.stop()
      return false
    }
    var n = Math.max(3, Math.round((duration || 160) / ticker.interval))
    var start = Math.floor((elapsed || 0) / ticker.interval)
    if (start >= n) {
      root.stop()
      return false
    }

    var w = [], r = []
    var picks = ({})
    if (mode === "glitch") {
      var want = Math.min(3, Math.max(1, Math.floor(t.length / 4)))
      var got = 0
      for (var p = 0; p < want * 4 && got < want; p++) {
        var k = Math.floor(Math.random() * t.length)
        if (t.charAt(k) !== " " && !picks[k]) { picks[k] = true; got++ }
      }
    }
    var last = t.length - 1
    while (last > 0 && t.charAt(last) === " ") last--

    for (var i = 0; i < t.length; i++) {
      w.push(metrics.advanceWidth(t.charAt(i)))
      if (mode === "glitch") {
        r.push(picks[i] ? Math.round(n * (0.4 + Math.random() * 0.6)) : 0)
      } else if (mode === "tail") {
        r.push(i === last ? n - 1 : 0)
      } else {
        var lead = n * 0.15 + (i / Math.max(1, t.length)) * n * 0.6
        r.push(Math.min(n - 1, Math.round(lead + Math.random() * n * 0.22)))
      }
    }
    root.playedText = t
    root.frames = n
    root.widths = w
    root.resolveAt = r
    root.frame = start
    root.step()
    ticker.restart()
    return true
  }

  function stop() {
    ticker.stop()
  }

  function step() {
    var t = root.playedText
    var out = []
    for (var i = 0; i < root.widths.length; i++) {
      var real = t.charAt(i)
      var at = root.resolveAt[i] || 0
      if (real === " " || (root.frame >= 0 && root.frame >= at)) {
        out.push({ c: real, k: false, m: false, h: at > 0 && root.frame - at < 2, s: false })
      } else {
        var g = Glyphs.random()
        out.push({ c: g, k: Glyphs.isKata(g), m: Math.random() < 0.5, h: root.frame + 1 >= at, s: true })
      }
    }
    root.chars = out
  }

  Timer {
    id: ticker
    interval: 30
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
          font.weight: root.fontWeight
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
