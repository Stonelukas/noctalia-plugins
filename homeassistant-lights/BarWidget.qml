import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Modules.Panels.Settings
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen

  // Widget properties passed from Bar.qml
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0
  property real scaling: 1.0

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isConnected: pluginMain?.connected || false
  readonly property bool isConnecting: pluginMain?.connecting || false
  readonly property int lightsOnCount: pluginMain?.lightsOnCount || 0
  readonly property int totalLightsCount: pluginMain?.totalLightsCount || 0
  property bool hasEverConnected: false

  onIsConnectedChanged: {
    if (isConnected) {
      hasEverConnected = true;
    }
  }

  readonly property string labelText: {
    if (!isConnected) {
      return pluginApi?.tr("title") || "Lights";
    }
    if (lightsOnCount > 0) {
      return lightsOnCount.toString();
    }
    return pluginApi?.tr("status.all-off") || "Off";
  }

  readonly property string pillText: isBarVertical ? "" : labelText

  readonly property string iconName: {
    if (isConnecting)
      return "bulb-search";
    if (!isConnected)
      return "bulb-off";
    if (lightsOnCount > 0)
      return "bulb";
    return "bulb-off";
  }

  readonly property string tooltipText: {
    if (isConnecting) {
      return pluginApi?.tr("status.connecting") || "Connecting...";
    }
    if (!isConnected) {
      return pluginApi?.tr("tooltips.disconnected") || "Lights (disconnected)\nClick to configure";
    }
    if (lightsOnCount > 0) {
      return pluginApi?.tr("tooltips.lights-on", { count: lightsOnCount, total: totalLightsCount }) 
        || lightsOnCount + " of " + totalLightsCount + " lights on\nClick to control";
    }
    return pluginApi?.tr("tooltips.all-off") || "All lights off\nClick to control";
  }

  readonly property var palette: typeof Color !== "undefined" ? Color : null
  readonly property color fallbackSurfaceLow: "#1f1f1f"
  readonly property color fallbackOnSurface: "#f0f0f0"

  readonly property color pillBackgroundColor: {
    if (!isConnected && hasEverConnected)
      return palette?.mSurfaceContainerLow ?? fallbackSurfaceLow;
    if (lightsOnCount > 0)
      return palette?.mPrimaryContainer ?? "#3d3a00";
    return Qt.rgba(0, 0, 0, 0);
  }
  readonly property color pillTextIconColor: {
    if (!isConnected && hasEverConnected)
      return palette?.mOnSurface ?? fallbackOnSurface;
    if (lightsOnCount > 0)
      return palette?.mOnPrimaryContainer ?? "#fff9c0";
    return Qt.rgba(0, 0, 0, 0);
  }

  property var settingsPopupComponent: null

  readonly property real capsuleHeight: Style.capsuleHeight
  readonly property real iconPixelSize: {
    switch (Settings.data.bar.density) {
    case "compact":
      return Math.max(1, Math.round(capsuleHeight * 0.65));
    default:
      return Math.max(1, Math.round(capsuleHeight * 0.48));
    }
  }
  readonly property real textPointSize: {
    switch (Settings.data.bar.density) {
    case "compact":
      return Math.max(1, Math.round(capsuleHeight * 0.45));
    default:
      return Math.max(1, Math.round(capsuleHeight * 0.33));
    }
  }
  readonly property bool showText: !isBarVertical && pillText !== ""
  property bool hovered: false

  function calculateContentWidth() {
    if (!showText) {
      return capsuleHeight;
    }
    var contentWidth = 0;
    var margins = Style.marginS * scaling * 2;
    contentWidth += margins;
    contentWidth += iconPixelSize + (Style.marginS * scaling);
    contentWidth += Math.ceil(fullTitleMetrics.contentWidth || 0);
    contentWidth += Style.marginXXS * 2;
    return Math.ceil(contentWidth);
  }

  readonly property real dynamicWidth: {
    if (!showText)
      return capsuleHeight;
    return Math.min(calculateContentWidth(), 100);
  }

  implicitWidth: dynamicWidth
  implicitHeight: capsuleHeight

  function popupWindow() {
    if (!screen)
      return null;
    return PanelService.getPopupMenuWindow(screen);
  }

  NText {
    id: fullTitleMetrics
    visible: false
    text: pillText
    pointSize: textPointSize
    applyUiScale: false
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("actions.all-on") || "Turn All On",
        "action": "all-on",
        "icon": "bulb",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.all-off") || "Turn All Off",
        "action": "all-off",
        "icon": "bulb-off",
        "enabled": isConnected
      },
      {
        "label": pluginApi?.tr("actions.refresh") || "Refresh",
        "action": "refresh",
        "icon": "refresh"
      },
      {
        "label": pluginApi?.tr("tooltips.widget-settings") || "Widget settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      var popupMenuWindow = popupWindow();
      if (popupMenuWindow) {
        popupMenuWindow.close();
      }
      if (action === "all-on") {
        pluginMain?.turnAllOn();
      } else if (action === "all-off") {
        pluginMain?.turnAllOff();
      } else if (action === "refresh") {
        pluginMain?.refresh();
      } else if (action === "settings") {
        openPluginSettings();
      }
    }
  }

  Rectangle {
    id: pill

    width: dynamicWidth
    height: capsuleHeight
    radius: Style.radiusM
    color: hovered ? Color.mHover : (pillBackgroundColor.a > 0 ? pillBackgroundColor : Style.capsuleColor)
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color {
      ColorAnimation {
        duration: Style.animationFast
        easing.type: Easing.InOutQuad
      }
    }

    Item {
      id: mainContainer
      anchors.fill: parent
      anchors.leftMargin: Style.marginS * scaling
      anchors.rightMargin: Style.marginS * scaling

      RowLayout {
        id: rowLayout
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.marginS * scaling
        visible: !isBarVertical

        Item {
          Layout.preferredWidth: iconPixelSize
          Layout.preferredHeight: iconPixelSize
          Layout.alignment: Qt.AlignVCenter

          NIcon {
            anchors.fill: parent
            icon: iconName
            pointSize: iconPixelSize
            applyUiScale: false
            color: hovered ? Color.mOnHover : (pillTextIconColor.a > 0 ? pillTextIconColor : Color.mOnSurface)
          }
        }

        NText {
          id: titleText
          visible: showText
          text: pillText
          pointSize: textPointSize
          applyUiScale: false
          verticalAlignment: Text.AlignVCenter
          color: hovered ? Color.mOnHover : (pillTextIconColor.a > 0 ? pillTextIconColor : Color.mOnSurface)
        }
      }

      Item {
        id: verticalLayout
        anchors.centerIn: parent
        width: parent.width - Style.marginM * 2
        height: parent.height - Style.marginM * 2
        visible: isBarVertical

        Item {
          width: iconPixelSize
          height: width
          anchors.centerIn: parent

          NIcon {
            anchors.fill: parent
            icon: iconName
            pointSize: iconPixelSize
            applyUiScale: false
            color: hovered ? Color.mOnHover : (pillTextIconColor.a > 0 ? pillTextIconColor : Color.mOnSurface)
          }
        }
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        hovered = true;
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection(), Style.tooltipDelayLong);
      }
      onExited: {
        hovered = false;
        TooltipService.hide();
      }
      onClicked: mouse => {
        TooltipService.hide();
        if (mouse.button === Qt.LeftButton) {
          openPanel();
        } else if (mouse.button === Qt.RightButton) {
          var popupMenuWindow = popupWindow();
          if (popupMenuWindow) {
            popupMenuWindow.showContextMenu(contextMenu);
            contextMenu.openAtItem(pill, screen);
          }
        } else if (mouse.button === Qt.MiddleButton) {
          // Toggle all lights
          if (lightsOnCount > 0) {
            pluginMain?.turnAllOff();
          } else {
            pluginMain?.turnAllOn();
          }
        }
      }
      onWheel: wheel => {
        TooltipService.hide();
        if (!isConnected) return;
        // Wheel up/down could adjust brightness of selected light
        if (pluginMain?.selectedLight && pluginMain?.supportsBrightness) {
          const currentBrightness = pluginMain?.brightnessPercent || 0;
          const delta = wheel.angleDelta.y > 0 ? 10 : -10;
          const newBrightness = Math.max(0, Math.min(100, currentBrightness + delta));
          pluginMain?.setBrightness(null, newBrightness);
        }
      }
    }
  }

  function openPanel() {
    if (!pluginApi)
      return;
    pluginApi.withCurrentScreen(s => {
      pluginApi.openPanel(s, pill);
    });
  }

  function openPluginSettings() {
    if (!pluginApi)
      return;

    var popupMenuWindow = popupWindow();

    function instantiateDialog(component) {
      var parentItem = popupMenuWindow ? popupMenuWindow.dialogParent : Overlay.overlay;
      var dialog = component.createObject(parentItem, {
        "showToastOnSave": true
      });
      if (!dialog) {
        Logger.e("HomeAssistantLightsWidget", "Failed to instantiate plugin settings dialog:", component.errorString());
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
          Logger.e("HomeAssistantLightsWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
          settingsPopupComponent.statusChanged.disconnect(handler);
          settingsPopupComponent = null;
        }
      };
      settingsPopupComponent.statusChanged.connect(handler);
    } else {
      Logger.e("HomeAssistantLightsWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
      settingsPopupComponent = null;
    }
  }
}
