import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "fx"
import "fx/Glyphs.js" as Glyphs

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  // ---- Matrix FX. Switching workspace: a glyph streak runs from
  //      the old button to the new one, a rain drop falls through the new
  //      cell and its label decodes from katakana. Hover: a short glitch.
  //      "matrixFx" setting: theme (default) | always | off.
  readonly property string fxMode: String(setting("matrixFx", "theme"))
  readonly property bool fxOn: fxMode === "always" || (fxMode === "theme" && fxGate.active)
  readonly property color fxColor: root.bar ? root.bar.barForeground : Commons.Color.foreground
  readonly property color fxHot: Qt.tint(root.fxColor, Qt.rgba(1, 1, 1, 0.78))
  property int fxLastId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1

  MatrixGate { id: fxGate }

  function fxButtonFor(id) {
    var ids = root.workspaceIds()
    var i = ids.indexOf(id)
    return i < 0 ? null : wsRepeater.itemAt(i)
  }

  Connections {
    target: Hyprland
    function onFocusedWorkspaceChanged() {
      var next = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
      var prev = root.fxLastId
      root.fxLastId = next
      if (!root.fxOn || next === prev) return
      var to = root.fxButtonFor(next)
      if (!to) return
      to.fxDecode(300, true)
      var from = root.fxButtonFor(prev)
      if (from && !root.vertical) {
        streak.fromX = from.x + grid.x + from.width / 2
        streak.toX = to.x + grid.x + to.width / 2
        streak.y = to.y + grid.y + to.height - streak.height - Style.space(2)
        streakAnim.restart()
      }
    }
  }

  // Streak: a hot bar with a short glyph tail along the bottom of the row.
  Item {
    id: streak
    property real fromX: 0
    property real toX: 0
    property real t: 0
    readonly property real dir: toX >= fromX ? 1 : -1
    readonly property real headX: fromX + (toX - fromX) * t
    z: 10
    width: 0
    height: Style.space(2)
    visible: streakAnim.running

    Rectangle {
      x: Math.min(streak.headX, streak.headX - streak.dir * Math.abs(streak.toX - streak.fromX) * 0.45 * (1 - streak.t))
      width: Math.max(2, Math.abs(streak.toX - streak.fromX) * 0.45 * (1 - streak.t))
      height: parent.height
      color: root.fxColor
      opacity: 0.9
    }

    Rectangle {
      x: streak.headX - 2
      width: 4
      height: parent.height
      color: root.fxHot
    }

    Repeater {
      model: streak.visible ? 3 : 0
      Text {
        required property int index
        x: streak.headX - streak.dir * (index + 1) * Style.space(9) - width / 2
        y: -Style.space(9)
        text: Glyphs.at(index * 17 + Math.floor(streak.t * 12))
        color: index === 0 ? root.fxHot : root.fxColor
        opacity: (1 - index / 3) * (1 - streak.t * 0.6)
        font.family: "Noto Sans CJK JP"
        font.pixelSize: Style.space(8)
      }
    }

    NumberAnimation {
      id: streakAnim
      target: streak
      property: "t"
      from: 0
      to: 1
      duration: 220
      easing.type: Easing.OutCubic
    }
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      id: wsRepeater
      model: root.workspaceIds()

      WidgetButton {
        id: wsButton
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
        labelVisible: !wsButton.fxRunning

        // ---- Matrix FX: label churn + rain drop (fixed-width cell, so no
        //      layout shift). Nothing ticks unless a decode is playing.
        property bool fxRunning: false
        property int fxFrame: 0
        property int fxFrames: 9
        property bool fxDrop: false
        property string fxChar: ""

        function fxDecode(duration, drop) {
          wsButton.fxFrames = Math.max(3, Math.round(duration / fxTimer.interval))
          wsButton.fxFrame = 0
          wsButton.fxDrop = drop === true
          wsButton.fxChar = Glyphs.random()
          wsButton.fxRunning = true
          fxTimer.restart()
          if (wsButton.fxDrop) dropAnim.restart()
        }

        Timer {
          id: fxTimer
          interval: 33
          repeat: true
          onTriggered: {
            wsButton.fxFrame++
            if (wsButton.fxFrame >= wsButton.fxFrames) {
              stop()
              wsButton.fxRunning = false
              return
            }
            wsButton.fxChar = Glyphs.random()
          }
        }

        Text {
          visible: wsButton.fxRunning
          anchors.centerIn: parent
          text: wsButton.fxChar
          color: wsButton.fxFrame >= wsButton.fxFrames - 2 ? root.fxHot : wsButton.foreground
          font.family: Glyphs.isKata(wsButton.fxChar) ? "Noto Sans CJK JP" : wsButton.fontFamily
          font.pixelSize: wsButton.fontSize
          transform: Scale { origin.x: width / 2; xScale: wsButton.fxFrame % 3 === 1 ? -1 : 1 }
        }

        Item {
          anchors.fill: parent
          clip: true
          visible: dropAnim.running

          Rectangle {
            id: drop
            x: (parent.width - width) / 2
            width: Math.max(2, Style.space(2))
            height: parent.height * 0.7
            gradient: Gradient {
              GradientStop { position: 0.0; color: "transparent" }
              GradientStop { position: 0.85; color: root.fxColor }
              GradientStop { position: 1.0; color: root.fxHot }
            }
          }

          NumberAnimation {
            id: dropAnim
            target: drop
            property: "y"
            from: -drop.height
            to: wsButton.height
            duration: 280
            easing.type: Easing.InQuad
          }
        }

        HoverHandler {
          enabled: root.fxOn
          onHoveredChanged: if (hovered && !wsButton.fxRunning) wsButton.fxDecode(130, false)
        }
      }
    }
  }
}
