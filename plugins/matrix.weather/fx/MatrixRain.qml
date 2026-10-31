import QtQuick
import "Glyphs.js" as Glyphs

// Columns of falling glyphs over a surface.
//   mode "reveal":   an opaque cover sits below each column's head, so the
//                    content underneath is uncovered as the rain falls, with
//                    a bright scanline sweeping down ahead of it.
//   mode "dissolve": the cover grows down behind each head, eating the
//                    content into falling code.
// Drive it with play(), or animate `progress` yourself after setting `armed`.
// Nothing is instantiated while idle.
Item {
  id: root

  property color color: "#00ff41"
  property color hotColor: "#eaffea"
  property color coverColor: "#000a02"
  property string glyphFamily: "Noto Sans CJK JP"
  property real columnWidth: 16
  property real glyphSize: 14
  property int trail: 5
  property string mode: "reveal"
  property bool scanline: true
  property real progress: 0
  property bool armed: false
  // Keep the final frame up after a dissolve (until reset()).
  property bool hold: false

  readonly property bool running: anim.running
  readonly property int columns: Math.max(1, Math.ceil(width / columnWidth))
  readonly property int tick: Math.floor(progress * 28)
  readonly property real span: height + trail * glyphSize

  signal finished()

  clip: true
  visible: armed || anim.running || hold

  function play(m, duration) {
    anim.stop()
    root.mode = m || "reveal"
    root.hold = root.mode === "dissolve"
    anim.duration = Math.max(60, duration || 380)
    root.progress = 0
    anim.start()
  }

  function reset() {
    anim.stop()
    root.hold = false
    root.armed = false
    root.progress = 0
  }

  NumberAnimation {
    id: anim
    target: root
    property: "progress"
    from: 0
    to: 1
    easing.type: Easing.Linear
    onFinished: {
      if (root.mode === "reveal") root.hold = false
      root.finished()
    }
  }

  Loader {
    anchors.fill: parent
    active: root.visible
    sourceComponent: Item {
      Repeater {
        model: root.columns

        Item {
          id: col
          required property int index
          readonly property real delay: Glyphs.hash(index * 13 + 7) * 0.42
          readonly property real curve: 0.75 + Glyphs.hash(index * 31 + 3) * 0.5
          readonly property real local: Math.pow(Math.max(0, Math.min(1, (root.progress - delay) / (1 - delay))), curve)
          readonly property real headY: local * root.span
          readonly property bool mirrored: Glyphs.hash(index * 5 + 1) > 0.5

          x: index * root.columnWidth
          width: root.columnWidth
          height: root.height

          Rectangle {
            width: parent.width
            color: root.coverColor
            y: root.mode === "reveal" ? Math.min(col.headY, root.height) : 0
            height: root.mode === "reveal"
              ? Math.max(0, root.height - y)
              : Math.max(0, Math.min(root.height, col.headY - root.trail * root.glyphSize * 0.6))
          }

          Repeater {
            model: root.trail

            Text {
              required property int index
              readonly property real gy: col.headY - (index + 1) * root.glyphSize
              visible: col.local > 0 && col.local < 1 && gy > -root.glyphSize && gy < root.height
              x: (col.width - width) / 2
              y: gy
              text: Glyphs.at(col.index * 7 + index * 3 + root.tick)
              color: index === 0 ? root.hotColor : root.color
              opacity: index === 0 ? 1 : (1 - index / root.trail) * 0.9
              font.family: root.glyphFamily
              font.pixelSize: root.glyphSize
              transform: Scale { origin.x: root.glyphSize / 2; xScale: col.mirrored ? -1 : 1 }
            }
          }
        }
      }

      // Phosphor scanline running ahead of the reveal.
      Item {
        visible: root.scanline && root.mode === "reveal" && root.progress < 1
        width: parent.width
        height: 22
        y: root.progress * (root.height + 22) - 22
        opacity: 1 - root.progress * 0.6

        Rectangle {
          anchors.fill: parent
          gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.85; color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.22) }
            GradientStop { position: 1.0; color: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.5) }
          }
        }
        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          height: 2
          color: root.hotColor
        }
      }
    }
  }
}
