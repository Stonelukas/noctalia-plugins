import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Widgets

NBox {
  id: root

  required property var screen
  required property var toplevel
  required property var windowData
  property var pluginApi: null

  Layout.fillWidth: true
  implicitHeight: contentColumn.implicitHeight + Style.marginL * 2

  ColumnLayout {
    id: contentColumn
    anchors.fill: parent
    anchors.margins: Style.marginM
    spacing: Style.marginS

    // Preview container
    Rectangle {
      id: previewContainer
      Layout.fillWidth: true
      Layout.preferredHeight: 200

      color: Color.mSurfaceVariant
      radius: Style.radiusS
      clip: true

      // No window placeholder
      ColumnLayout {
        anchors.centerIn: parent
        visible: !root.toplevel
        spacing: Style.marginS

        NIcon {
          Layout.alignment: Qt.AlignHCenter
          icon: "photo-off"
          pointSize: Style.fontSizeXXL
          color: Color.mOutline
        }

        NText {
          Layout.alignment: Qt.AlignHCenter
          text: pluginApi?.tr("preview.no-preview") || "No preview available"
          color: Color.mOutline
        }
      }

      // Live preview using ScreencopyView
      ScreencopyView {
        id: screencopy
        anchors.centerIn: parent
        visible: root.toplevel !== null

        captureSource: root.toplevel?.wayland ?? null
        live: true

        // Calculate size maintaining aspect ratio
        readonly property real aspectRatio: {
          if (!root.windowData.width || !root.windowData.height) return 16/9;
          return root.windowData.width / root.windowData.height;
        }

        constraintSize.height: previewContainer.height - Style.marginS * 2
        constraintSize.width: Math.min(
          constraintSize.height * aspectRatio,
          previewContainer.width - Style.marginS * 2
        )
      }
    }

    // Label showing window info
    NText {
      id: label
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter

      text: root.toplevel
        ? `${root.windowData.title} on ${root.windowData.monitorName} at ${root.windowData.x}, ${root.windowData.y}`
        : (pluginApi?.tr("preview.no-window") || "No active window")

      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      elide: Text.ElideMiddle
    }
  }
}
