import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
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

  readonly property string barPosition: Settings.data.bar.position
  readonly property bool isBarVertical: barPosition === "left" || barPosition === "right"

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool hasDevice: pluginMain?.hasDevice || false
  readonly property bool deviceReachable: pluginMain?.deviceReachable || false
  readonly property int batteryLevel: pluginMain?.batteryLevel ?? -1
  readonly property bool isCharging: pluginMain?.isCharging || false
  readonly property string deviceName: pluginMain?.deviceName || ""
  readonly property bool lowBattery: pluginMain?.lowBattery || false

  readonly property string batteryIcon: {
    // Use device-mobile icon with variants
    if (!hasDevice || batteryLevel < 0) return "device-mobile-off";
    if (!deviceReachable) return "device-mobile-off";
    return "device-mobile";
  }

  readonly property string labelText: {
    if (!hasDevice || batteryLevel < 0) return "";
    return batteryLevel + "%";
  }

  readonly property string pillText: isBarVertical ? "" : labelText

  readonly property string tooltipText: {
    if (!hasDevice) {
      return pluginApi?.tr("tooltips.no-device") || "No phone connected\nClick to configure";
    }
    if (!deviceReachable) {
      return pluginApi?.tr("tooltips.unreachable") || deviceName + " (unreachable)";
    }
    if (isCharging) {
      return pluginApi?.tr("tooltips.charging", { name: deviceName, level: batteryLevel }) 
        || deviceName + " - " + batteryLevel + "% (charging)";
    }
    return pluginApi?.tr("tooltips.battery", { name: deviceName, level: batteryLevel }) 
      || deviceName + " - " + batteryLevel + "%";
  }

  readonly property color pillBackgroundColor: {
    if (!hasDevice || !deviceReachable) return Qt.rgba(0, 0, 0, 0);
    if (lowBattery) return Color.mError;
    if (isCharging) return Color.mPrimary;
    return Qt.rgba(0, 0, 0, 0);
  }

  readonly property color pillTextIconColor: {
    if (!hasDevice || !deviceReachable) return Color.mOnSurface;
    if (lowBattery) return Color.mOnError;
    if (isCharging) return Color.mOnPrimary;
    return Color.mOnSurface;
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
        "label": pluginApi?.tr("actions.ping") || "Ping Device",
        "action": "ping",
        "icon": "bell",
        "enabled": hasDevice && deviceReachable
      },
      {
        "label": pluginApi?.tr("actions.ring") || "Find Phone",
        "action": "ring",
        "icon": "phone-ringing",
        "enabled": hasDevice && deviceReachable
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
      if (action === "ping") {
        pluginMain?.pingDevice();
      } else if (action === "ring") {
        pluginMain?.ringDevice();
      } else if (action === "refresh") {
        pluginMain?.refreshDevices();
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
            icon: batteryIcon
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
            icon: batteryIcon
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
          pluginMain?.pingDevice();
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
        Logger.e("KDEConnectWidget", "Failed to instantiate plugin settings dialog:", component.errorString());
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
          Logger.e("KDEConnectWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
          settingsPopupComponent.statusChanged.disconnect(handler);
          settingsPopupComponent = null;
        }
      };
      settingsPopupComponent.statusChanged.connect(handler);
    } else {
      Logger.e("KDEConnectWidget", "Failed to load plugin settings dialog:", settingsPopupComponent.errorString());
      settingsPopupComponent = null;
    }
  }
}
