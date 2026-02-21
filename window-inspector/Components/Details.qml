import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

NBox {
  id: root

  required property var windowData
  property var pluginApi: null
  property var pluginMain: null

  Layout.fillWidth: true
  implicitHeight: detailsColumn.implicitHeight + Style.marginL * 2

  ColumnLayout {
    id: detailsColumn
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginS

    // Header with title and copy button
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        // Title
        NText {
          Layout.fillWidth: true
          text: root.windowData.title || "Unknown"
          font.weight: Style.fontWeightBold
          pointSize: Style.fontSizeL
          wrapMode: Text.WrapAtWordBoundaryOrAnywhere
          color: Color.mOnSurface
        }

        // Class
        NText {
          text: root.windowData.appId || "Unknown"
          pointSize: Style.fontSizeM
          color: Color.mTertiary
        }
      }

      // Copy button
      NIconButton {
        icon: "clipboard-copy"
        baseSize: Style.baseWidgetSize * 0.7
        tooltipText: pluginApi?.tr("actions.copy") || "Copy info"
        onClicked: root.pluginMain?.copyWindowInfo()
      }
    }

    NDivider {
      Layout.fillWidth: true
      Layout.topMargin: Style.marginS
      Layout.bottomMargin: Style.marginS
    }

    // Details grid
    DetailRow {
      icon: "map-pin"
      label: pluginApi?.tr("details.address") || "Address"
      value: `0x${root.windowData.address}`
      accent: Color.mPrimary
    }

    DetailRow {
      icon: "arrows-move"
      label: pluginApi?.tr("details.position") || "Position"
      value: `${root.windowData.x}, ${root.windowData.y}`
    }

    DetailRow {
      icon: "dimensions"
      label: pluginApi?.tr("details.size") || "Size"
      value: `${root.windowData.width} x ${root.windowData.height}`
      accent: Color.mTertiary
    }

    DetailRow {
      icon: "layout-grid"
      label: pluginApi?.tr("details.workspace") || "Workspace"
      value: `${root.windowData.workspaceName} (${root.windowData.workspaceId})`
      accent: Color.mSecondary
    }

    DetailRow {
      icon: "device-desktop"
      label: pluginApi?.tr("details.monitor") || "Monitor"
      value: `${root.windowData.monitorName} at ${root.windowData.monitorX}, ${root.windowData.monitorY}`
    }

    DetailRow {
      icon: "text-caption"
      label: pluginApi?.tr("details.initial-title") || "Initial title"
      value: root.windowData.initialTitle || "-"
      accent: Color.mTertiary
    }

    DetailRow {
      icon: "category"
      label: pluginApi?.tr("details.initial-class") || "Initial class"
      value: root.windowData.initialClass || "-"
    }

    DetailRow {
      icon: "binary-tree"
      label: pluginApi?.tr("details.pid") || "Process ID"
      value: root.windowData.pid >= 0 ? root.windowData.pid.toString() : "-"
      accent: Color.mPrimary
    }

    DetailRow {
      icon: "float-left"
      label: pluginApi?.tr("details.floating") || "Floating"
      value: root.windowData.floating ? "yes" : "no"
      accent: Color.mSecondary
    }

    DetailRow {
      icon: "brand-xing"
      label: pluginApi?.tr("details.xwayland") || "XWayland"
      value: root.windowData.xwayland ? "yes" : "no"
    }

    DetailRow {
      icon: "pin"
      label: pluginApi?.tr("details.pinned") || "Pinned"
      value: root.windowData.pinned ? "yes" : "no"
      accent: Color.mSecondary
    }

    DetailRow {
      icon: "maximize"
      label: pluginApi?.tr("details.fullscreen") || "Fullscreen"
      value: root.windowData.fullscreen === 0 ? "off" : root.windowData.fullscreen === 1 ? "maximized" : "fullscreen"
      accent: Color.mTertiary
    }
  }

  // Detail row component
  component DetailRow: RowLayout {
    required property string icon
    required property string label
    required property string value
    property color accent: Color.mOnSurfaceVariant

    Layout.fillWidth: true
    spacing: Style.marginS

    NIcon {
      icon: parent.icon
      pointSize: Style.fontSizeM
      color: parent.accent
    }

    NText {
      text: `${parent.label}:`
      pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
    }

    Item { Layout.fillWidth: true }

    NText {
      text: parent.value
      pointSize: Style.fontSizeS
      color: Color.mOnSurface
      horizontalAlignment: Text.AlignRight
      Layout.maximumWidth: 180
      elide: Text.ElideMiddle
    }
  }
}
