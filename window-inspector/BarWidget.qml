import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

  // ═══════════════════════════════════════════════════════════════
  // PLUGIN STATE
  // ═══════════════════════════════════════════════════════════════

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool hasWindow: pluginMain?.hasActiveWindow ?? false
  readonly property var windowData: pluginMain?.windowData ?? {}

  // Settings from Main.qml
  readonly property bool showIcon: pluginMain?.showIcon ?? true
  readonly property int maxWidth: pluginMain?.maxWidth ?? 200
  readonly property string scrollingMode: pluginMain?.scrollingMode ?? "hover"
  readonly property bool hideWhenNoWindow: pluginMain?.hideWhenNoWindow ?? true

  // ═══════════════════════════════════════════════════════════════
  // BAR LAYOUT
  // ═══════════════════════════════════════════════════════════════

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  // Widget sizing - match ActiveWindow.qml
  readonly property real capsuleHeight: Style.capsuleHeight
  readonly property real iconSize: Math.round(18 * scaling)
  readonly property real textSize: Style.fontSizeS * scaling

  // Visibility
  visible: !hideWhenNoWindow || hasWindow
  opacity: hasWindow ? 1.0 : 0.5

  Behavior on opacity {
    NumberAnimation { duration: Style.animationNormal; easing.type: Easing.OutCubic }
  }

  // Dynamic width calculation
  readonly property real contentWidth: {
    if (isBarVertical) return capsuleHeight;
    if (!hasWindow) return capsuleHeight;

    var w = Style.marginS * 2; // Padding
    if (showIcon) w += iconSize + Style.marginS;
    w += titleMetrics.contentWidth;
    w += Style.marginXXS * 2;

    return Math.min(Math.ceil(w), maxWidth);
  }

  implicitWidth: isBarVertical ? capsuleHeight : contentWidth
  implicitHeight: capsuleHeight

  Behavior on implicitWidth {
    NumberAnimation { duration: Style.animationNormal; easing.type: Easing.InOutCubic }
  }

  // Hidden text for measuring
  NText {
    id: titleMetrics
    visible: false
    text: windowData.title || "No active window"
    pointSize: textSize
    applyUiScale: false
    font.weight: Style.fontWeightMedium
  }

  // ═══════════════════════════════════════════════════════════════
  // CONTEXT MENU
  // ═══════════════════════════════════════════════════════════════

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("context.refresh") || "Refresh",
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": pluginApi?.tr("context.settings") || "Widget Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      var popup = PanelService.getPopupMenuWindow(screen);
      if (popup) popup.close();

      if (action === "refresh") {
        pluginMain?.refreshData();
      } else if (action === "settings") {
        openPluginSettings();
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════

  property bool hovered: false
  property var settingsPopupComponent: null

  Rectangle {
    id: pill
    anchors.fill: parent
    radius: Style.radiusM
    color: Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    // Horizontal layout
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.marginS
      anchors.rightMargin: Style.marginS
      spacing: Style.marginS
      visible: !isBarVertical

      // Icon - match ActiveWindow styling
      Item {
        Layout.preferredWidth: iconSize
        Layout.preferredHeight: iconSize
        Layout.alignment: Qt.AlignVCenter
        visible: showIcon

        IconImage {
          id: appIcon
          anchors.fill: parent
          source: hasWindow ? ThemeIcons.iconForAppId(windowData.appId?.toLowerCase() || "") : ThemeIcons.iconFromName("app-window")
          asynchronous: true
          smooth: true

          layer.enabled: true
          layer.effect: ShaderEffect {
            property color targetColor: Settings.data.colorSchemes.darkMode ? Color.mOnSurface : Color.mSurfaceVariant
            property real colorizeMode: 0.0
            fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
          }
        }
      }

      // Title with scrolling
      Item {
        id: titleContainer
        Layout.fillWidth: true
        Layout.preferredHeight: titleText.height
        clip: true

        property bool needsScrolling: titleMetrics.contentWidth > width
        property bool isScrolling: false

        NText {
          id: titleText
          text: windowData.title || (pluginApi?.tr("no-window") || "No active window")
          pointSize: textSize
          applyUiScale: false
          font.weight: Style.fontWeightMedium
          verticalAlignment: Text.AlignVCenter
          color: Color.mOnSurface

          x: scrollAnim.running ? scrollAnim.currentX : 0

          property real scrollX: 0

          NumberAnimation {
            id: scrollAnim
            target: titleText
            property: "scrollX"
            property real currentX: titleText.scrollX
            running: titleContainer.isScrolling
            from: 0
            to: -(titleMetrics.contentWidth + 50)
            duration: Math.max(4000, (windowData.title?.length || 0) * 100)
            loops: Animation.Infinite
            easing.type: Easing.Linear
          }

          Binding {
            target: titleText
            property: "x"
            value: titleText.scrollX
            when: scrollAnim.running
          }
        }

        // Second copy for seamless scroll
        NText {
          visible: titleContainer.isScrolling
          text: titleText.text
          pointSize: textSize
          applyUiScale: false
          font.weight: Style.fontWeightMedium
          verticalAlignment: Text.AlignVCenter
          color: Color.mOnSurface
          x: titleText.x + titleMetrics.contentWidth + 50
        }
      }
    }

    // Vertical layout (icon only) - match ActiveWindow styling
    Item {
      anchors.centerIn: parent
      width: Style.baseWidgetSize * 0.5 * scaling
      height: width
      visible: isBarVertical

      IconImage {
        anchors.fill: parent
        source: hasWindow ? ThemeIcons.iconForAppId(windowData.appId?.toLowerCase() || "") : ThemeIcons.iconFromName("app-window")
        asynchronous: true
        smooth: true

        layer.enabled: true
        layer.effect: ShaderEffect {
          property color targetColor: Color.mOnSurface
          property real colorizeMode: 0.0
          fragmentShader: Qt.resolvedUrl(Quickshell.shellDir + "/Shaders/qsb/appicon_colorize.frag.qsb")
        }
      }
    }

    // Mouse handling
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor

      onEntered: {
        hovered = true;

        // Start scrolling on hover (if mode is "hover")
        if (scrollingMode === "hover" && titleContainer.needsScrolling) {
          titleContainer.isScrolling = true;
        }

        // Show tooltip
        var tooltip = hasWindow
          ? `${windowData.title}\n${windowData.appId} - ${windowData.workspaceName}`
          : (pluginApi?.tr("tooltip.no-window") || "No active window");
        TooltipService.show(root, tooltip, BarService.getTooltipDirection());
      }

      onExited: {
        hovered = false;
        titleContainer.isScrolling = false;
        TooltipService.hide();
      }

      onClicked: mouse => {
        TooltipService.hide();

        if (mouse.button === Qt.LeftButton) {
          // Open inspector panel
          if (hasWindow) {
            pluginApi?.withCurrentScreen(s => pluginApi.openPanel(s, pill));
          }
        } else if (mouse.button === Qt.RightButton) {
          // Context menu
          var popup = PanelService.getPopupMenuWindow(screen);
          if (popup) {
            popup.showContextMenu(contextMenu);
            contextMenu.openAtItem(pill, screen);
          }
        }
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  function openPluginSettings() {
    if (!pluginApi) return;

    var popupMenuWindow = PanelService.getPopupMenuWindow(screen);

    function instantiateDialog(component) {
      var parentItem = popupMenuWindow ? popupMenuWindow.dialogParent : Overlay.overlay;
      var dialog = component.createObject(parentItem, {
        "showToastOnSave": true
      });
      if (!dialog) {
        Logger.e("WindowInspector", "Failed to instantiate plugin settings dialog:", component.errorString());
        return;
      }

      dialog.openPluginSettings(pluginApi.manifest);

      if (popupMenuWindow) {
        popupMenuWindow.hasDialog = true;
        popupMenuWindow.open();
        dialog.closed.connect(() => {
          popupMenuWindow.hasDialog = false;
          popupMenuWindow.close();
        });
      }

      dialog.closed.connect(() => dialog.destroy());
    }

    function handleReady(component) {
      instantiateDialog(component);
    }

    if (!settingsPopupComponent) {
      settingsPopupComponent = Qt.createComponent(Quickshell.shellDir + "/Widgets/NPluginSettingsPopup.qml");
    }

    if (settingsPopupComponent.status === Component.Ready) {
      handleReady(settingsPopupComponent);
    } else if (settingsPopupComponent.status === Component.Loading) {
      var handler = function settingsComponentStatusChanged() {
        if (settingsPopupComponent.status === Component.Ready) {
          settingsPopupComponent.statusChanged.disconnect(handler);
          handleReady(settingsPopupComponent);
        } else if (settingsPopupComponent.status === Component.Error) {
          Logger.e("WindowInspector", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
          settingsPopupComponent.statusChanged.disconnect(handler);
          settingsPopupComponent = null;
        }
      };
      settingsPopupComponent.statusChanged.connect(handler);
    } else {
      Logger.e("WindowInspector", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
      settingsPopupComponent = null;
    }
  }
}
