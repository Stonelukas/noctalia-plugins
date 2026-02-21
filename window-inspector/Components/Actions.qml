import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.Commons
import qs.Widgets

NBox {
  id: root

  required property var pluginMain
  required property var windowData
  property var pluginApi: null

  property bool workspaceExpanded: false
  property bool specialWsExpanded: false

  // Special workspaces from Main.qml
  readonly property var specialWorkspaces: pluginMain?.specialWorkspaces ?? []
  readonly property bool hasSpecialWorkspaces: specialWorkspaces.length > 0

  Layout.fillWidth: true
  implicitHeight: actionsColumn.implicitHeight + Style.marginM * 2

  ColumnLayout {
    id: actionsColumn
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    // Move to workspace header
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("actions.move-to-workspace") || "Move to workspace"
        color: Color.mOnSurface
      }

      NIconButton {
        icon: root.workspaceExpanded ? "chevron-down" : "chevron-right"
        baseSize: Style.baseWidgetSize * 0.6
        onClicked: root.workspaceExpanded = !root.workspaceExpanded
      }
    }

    // Workspace grid (collapsible)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.workspaceExpanded ? wsGrid.implicitHeight : 0
      clip: true

      Behavior on Layout.preferredHeight {
        NumberAnimation { duration: Style.animationNormal; easing.type: Easing.InOutQuad }
      }

      GridLayout {
        id: wsGrid
        anchors.fill: parent
        columns: 5
        rowSpacing: Style.marginXS
        columnSpacing: Style.marginS
        opacity: root.workspaceExpanded ? 1 : 0

        Behavior on opacity {
          NumberAnimation { duration: Style.animationFast }
        }

        Repeater {
          model: 10

          Rectangle {
            id: wsButton
            required property int index
            readonly property int wsId: index + 1
            readonly property bool isCurrent: root.windowData.workspaceId === wsId

            Layout.fillWidth: true
            Layout.preferredHeight: wsLabel.implicitHeight + Style.marginS * 2

            radius: Style.radiusS
            color: isCurrent ? Color.mSurfaceVariant : (wsHover.containsMouse ? Qt.darker(Color.mTertiary, 1.1) : Color.mTertiary)

            Behavior on color {
              ColorAnimation { duration: Style.animationFast }
            }

            NText {
              id: wsLabel
              anchors.centerIn: parent
              text: wsButton.wsId.toString()
              color: wsButton.isCurrent ? Color.mOnSurfaceVariant : Color.mOnTertiary
            }

            MouseArea {
              id: wsHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: wsButton.isCurrent ? Qt.ArrowCursor : Qt.PointingHandCursor
              enabled: !wsButton.isCurrent

              onClicked: {
                if (!wsButton.isCurrent) {
                  root.pluginMain?.moveToWorkspace(wsButton.wsId);
                }
              }
            }
          }
        }
      }
    }

    // Special workspaces section (only if there are any)
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS
      visible: root.hasSpecialWorkspaces

      NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("actions.special-workspaces") || "Special Workspaces"
        color: Color.mOnSurface
      }

      NIconButton {
        icon: root.specialWsExpanded ? "chevron-down" : "chevron-right"
        baseSize: Style.baseWidgetSize * 0.6
        onClicked: root.specialWsExpanded = !root.specialWsExpanded
      }
    }

    // Special workspaces list (collapsible)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: root.specialWsExpanded && root.hasSpecialWorkspaces ? specialWsFlow.implicitHeight : 0
      clip: true
      visible: root.hasSpecialWorkspaces

      Behavior on Layout.preferredHeight {
        NumberAnimation { duration: Style.animationNormal; easing.type: Easing.InOutQuad }
      }

      Flow {
        id: specialWsFlow
        anchors.fill: parent
        spacing: Style.marginS
        opacity: root.specialWsExpanded ? 1 : 0

        Behavior on opacity {
          NumberAnimation { duration: Style.animationFast }
        }

        Repeater {
          model: root.specialWorkspaces

          Rectangle {
            id: specialWsButton
            required property var modelData
            readonly property string wsName: modelData.name || ""
            readonly property string displayName: wsName.replace("special:", "")
            readonly property bool isCurrent: root.windowData.workspaceName === wsName

            width: specialWsLabel.implicitWidth + Style.marginM * 2
            height: specialWsLabel.implicitHeight + Style.marginS * 2

            radius: Style.radiusS
            color: isCurrent ? Color.mSurfaceVariant : (specialWsHover.containsMouse ? Qt.darker(Color.mPrimary, 1.1) : Color.mPrimary)

            Behavior on color {
              ColorAnimation { duration: Style.animationFast }
            }

            NText {
              id: specialWsLabel
              anchors.centerIn: parent
              text: specialWsButton.displayName
              color: specialWsButton.isCurrent ? Color.mOnSurfaceVariant : Color.mOnPrimary
            }

            MouseArea {
              id: specialWsHover
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: specialWsButton.isCurrent ? Qt.ArrowCursor : Qt.PointingHandCursor
              enabled: !specialWsButton.isCurrent

              onClicked: {
                if (!specialWsButton.isCurrent) {
                  root.pluginMain?.moveToSpecialWorkspace(specialWsButton.wsName);
                }
              }
            }
          }
        }
      }
    }

    NDivider { Layout.fillWidth: true }

    // Action buttons row
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      // Float/Tile button
      Rectangle {
        id: floatButton
        Layout.fillWidth: true
        Layout.preferredHeight: floatLabel.implicitHeight + Style.marginS * 2

        radius: Style.radiusS
        color: floatHover.containsMouse ? Qt.darker(Color.mSecondary, 1.1) : Color.mSecondary

        Behavior on color {
          ColorAnimation { duration: Style.animationFast }
        }

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginXS

          NIcon {
            icon: root.windowData.floating ? "layout-grid" : "float-left"
            pointSize: Style.fontSizeS
            color: Color.mOnSecondary
          }

          NText {
            id: floatLabel
            text: root.windowData.floating
              ? (pluginApi?.tr("actions.tile") || "Tile")
              : (pluginApi?.tr("actions.float") || "Float")
            color: Color.mOnSecondary
          }
        }

        MouseArea {
          id: floatHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.pluginMain?.toggleFloating()
        }
      }

      // Pin button (only when floating)
      Rectangle {
        id: pinButton
        Layout.fillWidth: true
        Layout.preferredHeight: pinLabel.implicitHeight + Style.marginS * 2
        visible: root.windowData.floating

        radius: Style.radiusS
        color: pinHover.containsMouse ? Qt.darker(Color.mSecondary, 1.1) : Color.mSecondary

        Behavior on color {
          ColorAnimation { duration: Style.animationFast }
        }

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginXS

          NIcon {
            icon: root.windowData.pinned ? "pinned-off" : "pin"
            pointSize: Style.fontSizeS
            color: Color.mOnSecondary
          }

          NText {
            id: pinLabel
            text: root.windowData.pinned
              ? (pluginApi?.tr("actions.unpin") || "Unpin")
              : (pluginApi?.tr("actions.pin") || "Pin")
            color: Color.mOnSecondary
          }
        }

        MouseArea {
          id: pinHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.pluginMain?.togglePin()
        }
      }

      // Kill button
      Rectangle {
        id: killButton
        Layout.fillWidth: true
        Layout.preferredHeight: killLabel.implicitHeight + Style.marginS * 2

        radius: Style.radiusS
        color: killHover.containsMouse ? Qt.darker(Color.mError, 1.1) : Color.mError

        Behavior on color {
          ColorAnimation { duration: Style.animationFast }
        }

        RowLayout {
          anchors.centerIn: parent
          spacing: Style.marginXS

          NIcon {
            icon: "x"
            pointSize: Style.fontSizeS
            color: Color.mOnError
          }

          NText {
            id: killLabel
            text: pluginApi?.tr("actions.kill") || "Kill"
            color: Color.mOnError
          }
        }

        MouseArea {
          id: killHover
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.pluginMain?.killWindow()
        }
      }
    }
  }
}
