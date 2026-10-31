import QtQuick
import "Glyphs.js" as Glyphs

// A short burst of glyphs and a phosphor ripple from a point. Position the
// item's centre on the origin (it has zero size) and call play().
Item {
  id: root

  property color color: "#00ff41"
  property color hotColor: "#eaffea"
  property string glyphFamily: "Noto Sans CJK JP"
  property int count: 10
  property real radius: 34
  property real glyphSize: 11
  property real progress: 0
  property int seed: 0
  readonly property bool running: anim.running
  readonly property int tick: Math.floor(progress * 14)

  width: 0
  height: 0
  visible: anim.running

  function play() {
    root.seed = Math.floor(Math.random() * 1000)
    anim.restart()
  }

  NumberAnimation {
    id: anim
    target: root
    property: "progress"
    from: 0
    to: 1
    duration: 380
    easing.type: Easing.OutCubic
  }

  Loader {
    active: root.visible
    sourceComponent: Item {
      // Ripple ring
      Rectangle {
        readonly property real d: 6 + root.progress * root.radius * 1.1
        x: -d / 2
        y: -d / 2
        width: d
        height: d
        radius: d / 2
        color: "transparent"
        border.width: 1.5
        border.color: root.hotColor
        opacity: (1 - root.progress) * 0.9
      }

      Repeater {
        model: root.count

        Text {
          required property int index
          readonly property real angle: (index / root.count) * Math.PI * 2 + Glyphs.hash(root.seed + index) * 0.6
          readonly property real dist: root.progress * root.radius * (0.55 + Glyphs.hash(root.seed * 3 + index) * 0.6)
          x: Math.cos(angle) * dist - width / 2
          // Flattened: the bar is short, so the burst spreads along it.
          y: Math.sin(angle) * dist * 0.42 - height / 2 + root.progress * 4
          text: Glyphs.at(root.seed + index * 11 + root.tick)
          color: index % 3 === 0 ? root.hotColor : root.color
          opacity: 1 - root.progress
          font.family: root.glyphFamily
          font.pixelSize: root.glyphSize
        }
      }
    }
  }
}
