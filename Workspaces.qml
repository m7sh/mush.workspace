import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "mush.workspaces"

  // Sizing tokens
  readonly property int dotDiameter: root.setting("dotSize", 7)
  readonly property int pillLength: root.setting("pillWidth", 24)
  readonly property int itemSpacing: root.setting("spacing", 6)
  readonly property bool showNumbers: root.setting("showNumbers", false)
  readonly property bool hideEmpty: root.setting("hideEmptyWorkspaces", false)

  // Color tokens — seamlessly matches the active theme
  readonly property color fgColor: root.bar ? root.bar.barForeground : Color.bar.text
  readonly property color themeAccent: Color.accent

  readonly property color activePillColor: {
    var custom = root.setting("activeColor", "")
    if (custom !== "") {
      if (custom === "foreground" || custom === "text" || custom === "white") return fgColor
      if (custom === "accent" || custom === "theme") return themeAccent
      return custom
    }
    var st = root.setting("style", "theme")
    if (st === "foreground" || st === "gnome" || st === "white") return fgColor
    // Default to the current theme's accent color
    return themeAccent
  }

  // Workspaces list calculation (GNOME / Ubuntu dynamic model)
  readonly property var activeWorkspaces: {
    var values = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : []
    var focusedWs = Hyprland.focusedWorkspace
    var focusedId = (focusedWs && focusedWs.id > 0) ? focusedWs.id : 1

    // Hide-empty mode: only occupied workspaces are shown. The focused workspace
    // stays visible even when empty so the current position is always indicated.
    if (root.setting("hideEmptyWorkspaces", false)) {
      var visible = []
      var seen = {}
      if (focusedWs && focusedWs.id > 0 && focusedWs.id <= 10) {
        visible.push(focusedWs.id)
        seen[focusedWs.id] = true
      }
      for (var i = 0; i < values.length; i++) {
        var ws = values[i]
        if (ws && ws.id > 0 && ws.id <= 10 && !seen[ws.id] &&
            ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0) {
          visible.push(ws.id)
        }
      }
      visible.sort(function(a, b) { return a - b })
      if (visible.length === 0) visible.push(focusedId)
      return visible
    }

    var dynamicMode = root.setting("dynamic", true)
    var minWs = Math.max(1, root.setting("minWorkspaces", 2))
    var maxWs = Math.min(10, Math.max(minWs, root.setting("maxWorkspaces", 10)))

    var maxId = focusedId
    for (var i = 0; i < values.length; i++) {
      var ws = values[i]
      if (ws && ws.id > 0 && ws.id <= 10) {
        if (ws.toplevels && ws.toplevels.values && ws.toplevels.values.length > 0) {
          if (ws.id > maxId) {
            maxId = ws.id
          }
        }
      }
    }

    var count = dynamicMode ? Math.max(minWs, maxId + 1) : Math.max(minWs, maxId)
    if (count > maxWs) count = maxWs

    var ids = []
    for (var j = 1; j <= count; j++) {
      ids.push(j)
    }
    return ids
  }

  function workspaceById(id) {
    var values = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : []
    for (var i = 0; i < values.length; i++) {
      if (values[i] && values[i].id === id) return values[i]
    }
    return null
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function focusNextWorkspace() {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"+1\" })"))
  }

  function focusPreviousWorkspace() {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"-1\" })"))
  }

  function handleWheel(wheel) {
    if (wheel.angleDelta.y > 0 || wheel.angleDelta.x < 0) {
      root.focusPreviousWorkspace()
    } else if (wheel.angleDelta.y < 0 || wheel.angleDelta.x > 0) {
      root.focusNextWorkspace()
    }
  }

  // Click registration with host bar
  property var registeredBar: null
  function syncClickRegistration() {
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)
    registeredBar = root.bar
    if (registeredBar && registeredBar.registerClickTarget) registeredBar.registerClickTarget(root)
  }
  onBarChanged: syncClickRegistration()
  Component.onCompleted: syncClickRegistration()
  Component.onDestruction: {
    if (registeredBar && registeredBar.unregisterClickTarget) registeredBar.unregisterClickTarget(root)
    if (root.bar && typeof root.bar.hideTooltip === "function") root.bar.hideTooltip(root)
  }

  readonly property bool isVertical: root.vertical
  readonly property real trailingGap: isVertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: isVertical ? root.barSize : (container.implicitWidth + trailingGap)
  implicitHeight: isVertical ? (container.implicitHeight + Style.spaceReal(1.5)) : root.barSize

  Behavior on implicitWidth {
    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
  }
  Behavior on implicitHeight {
    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
  }

  // Ubuntu-style pill container
  Rectangle {
    id: container
    anchors.verticalCenter: root.isVertical ? undefined : parent.verticalCenter
    anchors.horizontalCenter: root.isVertical ? parent.horizontalCenter : undefined
    anchors.left: root.isVertical ? undefined : parent.left
    anchors.top: root.isVertical ? parent.top : undefined

    implicitWidth: root.isVertical
      ? root.barSize
      : (contentRow.implicitWidth + Style.space(12))

    implicitHeight: root.isVertical
      ? (contentCol.implicitHeight + Style.space(12))
      : root.barSize

    radius: Style.cornerRadius > 0 ? Style.cornerRadius : (Math.min(implicitWidth, implicitHeight) / 2)

    // Completely borderless and transparent by default to blend seamlessly with other bar plugins
    color: containerMouseArea.containsMouse
      ? Qt.rgba(root.fgColor.r, root.fgColor.g, root.fgColor.b, 0.07)
      : "transparent"

    border.width: 0

    Behavior on color { ColorAnimation { duration: 160 } }
    Behavior on implicitWidth { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    MouseArea {
      id: containerMouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onWheel: function(wheel) { root.handleWheel(wheel) }
    }

    // Horizontal layout
    Row {
      id: contentRow
      visible: !root.isVertical
      anchors.centerIn: parent
      spacing: root.itemSpacing

      Repeater {
        model: root.isVertical ? null : root.activeWorkspaces

        Item {
          id: wsDelegateH
          required property int modelData

          readonly property int wsId: modelData
          readonly property var wsObj: root.workspaceById(wsId)
          readonly property bool isOccupied: wsObj !== null && wsObj.toplevels && wsObj.toplevels.values && wsObj.toplevels.values.length > 0
          readonly property bool isFocused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId
          readonly property bool isHovered: delegateMouseAreaH.containsMouse

          width: isFocused ? root.pillLength : root.dotDiameter
          height: root.dotDiameter
          anchors.verticalCenter: parent.verticalCenter

          Behavior on width {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          Rectangle {
            id: shapeH
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: isFocused ? root.activePillColor : root.fgColor
            opacity: isFocused ? 1.0 : (isHovered ? 0.90 : (isOccupied ? 0.65 : 0.30))
            scale: delegateMouseAreaH.pressed ? 0.92 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
              anchors.centerIn: parent
              visible: root.showNumbers && parent.width >= 12
              text: wsId === 10 ? "0" : String(wsId)
              color: isFocused ? "#ffffff" : root.fgColor
              font.pixelSize: 8
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.bold: true
            }
          }

          MouseArea {
            id: delegateMouseAreaH
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(14, parent.width + 4)
            height: Math.max(22, container.height)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: function(mouse) {
              root.focusWorkspace(wsId)
            }

            onEntered: {
              if (root.bar && typeof root.bar.showTooltip === "function") {
                var tip = "Workspace " + wsId
                if (isOccupied && wsObj && wsObj.toplevels && wsObj.toplevels.values) {
                  var n = wsObj.toplevels.values.length
                  tip += " • " + n + (n === 1 ? " window" : " windows")
                } else if (isFocused) {
                  tip += " (current)"
                }
                root.bar.showTooltip(root, tip)
              }
            }

            onExited: {
              if (root.bar && typeof root.bar.hideTooltip === "function") {
                root.bar.hideTooltip(root)
              }
            }

            onWheel: function(wheel) {
              root.handleWheel(wheel)
            }
          }
        }
      }
    }

    // Vertical layout
    Column {
      id: contentCol
      visible: root.isVertical
      anchors.centerIn: parent
      spacing: root.itemSpacing

      Repeater {
        model: root.isVertical ? root.activeWorkspaces : null

        Item {
          id: wsDelegateV
          required property int modelData

          readonly property int wsId: modelData
          readonly property var wsObj: root.workspaceById(wsId)
          readonly property bool isOccupied: wsObj !== null && wsObj.toplevels && wsObj.toplevels.values && wsObj.toplevels.values.length > 0
          readonly property bool isFocused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === wsId
          readonly property bool isHovered: delegateMouseAreaV.containsMouse

          width: root.dotDiameter
          height: isFocused ? root.pillLength : root.dotDiameter
          anchors.horizontalCenter: parent.horizontalCenter

          Behavior on height {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
          }

          Rectangle {
            id: shapeV
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: isFocused ? root.activePillColor : root.fgColor
            opacity: isFocused ? 1.0 : (isHovered ? 0.90 : (isOccupied ? 0.65 : 0.30))
            scale: delegateMouseAreaV.pressed ? 0.92 : 1.0

            Behavior on color { ColorAnimation { duration: 180 } }
            Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 100 } }

            Text {
              anchors.centerIn: parent
              visible: root.showNumbers && parent.height >= 12
              text: wsId === 10 ? "0" : String(wsId)
              color: isFocused ? "#ffffff" : root.fgColor
              font.pixelSize: 8
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.bold: true
            }
          }

          MouseArea {
            id: delegateMouseAreaV
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(22, container.width)
            height: Math.max(14, parent.height + 4)
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

            onClicked: function(mouse) {
              root.focusWorkspace(wsId)
            }

            onEntered: {
              if (root.bar && typeof root.bar.showTooltip === "function") {
                var tip = "Workspace " + wsId
                if (isOccupied && wsObj && wsObj.toplevels && wsObj.toplevels.values) {
                  var n = wsObj.toplevels.values.length
                  tip += " • " + n + (n === 1 ? " window" : " windows")
                } else if (isFocused) {
                  tip += " (current)"
                }
                root.bar.showTooltip(root, tip)
              }
            }

            onExited: {
              if (root.bar && typeof root.bar.hideTooltip === "function") {
                root.bar.hideTooltip(root)
              }
            }

            onWheel: function(wheel) {
              root.handleWheel(wheel)
            }
          }
        }
      }
    }
  }
}
