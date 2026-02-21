import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets
import "Components"

Item {
  id: root

  property var pluginApi: null
  property var screen: null

  readonly property bool allowAttach: true
  readonly property int contentPreferredWidth: Math.round(450 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: mainColumn.implicitHeight + (Style.marginL * 2)

  // ═══════════════════════════════════════════════════════════════
  // PLUGIN STATE
  // ═══════════════════════════════════════════════════════════════

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool hasWindow: pluginMain?.hasActiveWindow ?? false
  readonly property var activeToplevel: pluginMain?.activeToplevel
  readonly property var windowData: pluginMain?.windowData ?? {}

  readonly property bool showPreview: pluginMain?.showPreview ?? true
  readonly property bool showActions: pluginMain?.showActions ?? true
  readonly property int previewHeight: pluginMain?.previewHeight ?? 280

  Component.onCompleted: {
    pluginMain?.refreshData();
  }

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // ═══════════════════════════════════════════════════════════════
    // HEADER
    // ═══════════════════════════════════════════════════════════════

    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight + (Style.marginM * 2)

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "app-window"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: pluginApi?.tr("title") || "Window Inspector"
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
          }

          NText {
            visible: hasWindow
            text: windowData.appId || ""
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }

        NIconButton {
          icon: "refresh"
          baseSize: Style.baseWidgetSize * 0.7
          tooltipText: pluginApi?.tr("actions.refresh") || "Refresh"
          onClicked: pluginMain?.refreshData()
        }

        NIconButton {
          icon: "x"
          baseSize: Style.baseWidgetSize * 0.7
          tooltipText: pluginApi?.tr("actions.close") || "Close"
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // LIVE PREVIEW
    // ═══════════════════════════════════════════════════════════════

    Loader {
      Layout.fillWidth: true
      Layout.preferredHeight: showPreview && hasWindow ? previewHeight : 0
      active: showPreview && hasWindow

      sourceComponent: Preview {
        screen: root.screen
        toplevel: root.activeToplevel
        windowData: root.windowData
        pluginApi: root.pluginApi
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // DETAILS
    // ═══════════════════════════════════════════════════════════════

    Loader {
      Layout.fillWidth: true
      active: hasWindow

      sourceComponent: Details {
        windowData: root.windowData
        pluginApi: root.pluginApi
        pluginMain: root.pluginMain
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // ACTIONS
    // ═══════════════════════════════════════════════════════════════

    Loader {
      Layout.fillWidth: true
      active: showActions && hasWindow

      sourceComponent: Actions {
        pluginMain: root.pluginMain
        windowData: root.windowData
        pluginApi: root.pluginApi
      }
    }

    // ═══════════════════════════════════════════════════════════════
    // NO WINDOW STATE
    // ═══════════════════════════════════════════════════════════════

    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: noWindowColumn.implicitHeight + (Style.marginL * 2)
      visible: !hasWindow

      ColumnLayout {
        id: noWindowColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NIcon {
          Layout.alignment: Qt.AlignHCenter
          icon: "app-window-off"
          pointSize: Style.fontSizeXXXL
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.no-window") || "No active window"
          horizontalAlignment: Text.AlignHCenter
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.no-window-hint") || "Focus a window to inspect it"
          horizontalAlignment: Text.AlignHCenter
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
        }
      }
    }

    Item { Layout.fillHeight: true }
  }
}
