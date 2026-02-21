import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  spacing: Style.marginL
  implicitWidth: Math.round(480 * Style.uiScaleRatio)
  Layout.minimumWidth: implicitWidth
  Layout.maximumWidth: implicitWidth
  Layout.preferredWidth: implicitWidth

  // Local state
  property string valuePreferredDevice: pluginApi?.pluginSettings?.preferredDevice || ""
  property int valuePollInterval: pluginApi?.pluginSettings?.pollIntervalMs || 30000
  property bool valueShowBatteryPercent: pluginApi?.pluginSettings?.showBatteryPercent ?? true
  property int valueLowBatteryWarning: pluginApi?.pluginSettings?.lowBatteryWarning || 20

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property var devices: pluginMain?.devices || []

  Component.onCompleted: {
    Logger.i("KDEConnect", "Settings UI loaded");
    pluginMain?.refreshDevices();
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("KDEConnect", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.preferredDevice = root.valuePreferredDevice;
    pluginApi.pluginSettings.pollIntervalMs = root.valuePollInterval;
    pluginApi.pluginSettings.showBatteryPercent = root.valueShowBatteryPercent;
    pluginApi.pluginSettings.lowBatteryWarning = root.valueLowBatteryWarning;

    pluginApi.saveSettings();

    if (pluginMain) {
      pluginMain.refreshDevices();
    }

    Logger.i("KDEConnect", "Settings saved successfully");
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Configure KDE Connect phone integration."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Device selection
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: pluginApi?.tr("settings.device") || "Device"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NComboBox {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.preferred-device") || "Preferred Device"
      description: pluginApi?.tr("settings.preferred-device-hint") || "Select which device to show in the bar widget."
      enabled: devices.length > 0

      model: {
        if (devices.length === 0) {
          return [{ key: "", name: pluginApi?.tr("settings.no-devices") || "No devices found" }];
        }
        const options = [{ key: "", name: pluginApi?.tr("settings.auto") || "(Auto - first available)" }];
        for (const deviceId of devices) {
          options.push({ key: deviceId, name: deviceId });
        }
        return options;
      }

      currentKey: root.valuePreferredDevice || ""
      onSelected: key => root.valuePreferredDevice = key
    }

    NButton {
      text: pluginApi?.tr("actions.refresh-devices") || "Refresh Devices"
      icon: "refresh"
      onClicked: pluginMain?.refreshDevices()
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Display settings
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: pluginApi?.tr("settings.display") || "Display"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NToggle {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.show-percent") || "Show Battery Percentage"
      description: pluginApi?.tr("settings.show-percent-hint") || "Show the battery percentage next to the icon in the bar."
      checked: root.valueShowBatteryPercent
      onToggled: checked => root.valueShowBatteryPercent = checked
    }

    NSlider {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.low-battery") || "Low Battery Warning"
      description: pluginApi?.tr("settings.low-battery-hint") || "Show warning color when battery is below this level."
      from: 5
      to: 50
      stepSize: 5
      value: root.valueLowBatteryWarning
      onValueChanged: root.valueLowBatteryWarning = value
      valueFormatter: v => v + "%"
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Polling settings
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: pluginApi?.tr("settings.polling") || "Polling"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NComboBox {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.poll-interval") || "Update Interval"
      description: pluginApi?.tr("settings.poll-interval-hint") || "How often to check the device status."

      model: [
        { key: 10000, name: pluginApi?.tr("settings.interval.10s") || "10 seconds" },
        { key: 30000, name: pluginApi?.tr("settings.interval.30s") || "30 seconds" },
        { key: 60000, name: pluginApi?.tr("settings.interval.1m") || "1 minute" },
        { key: 120000, name: pluginApi?.tr("settings.interval.2m") || "2 minutes" },
        { key: 300000, name: pluginApi?.tr("settings.interval.5m") || "5 minutes" }
      ]

      currentKey: root.valuePollInterval
      onSelected: key => root.valuePollInterval = key
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // Info section
  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: infoColumn.implicitHeight + Style.marginM * 2

    ColumnLayout {
      id: infoColumn
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NText {
        text: pluginApi?.tr("settings.info") || "Information"
        pointSize: Style.fontSizeM
        font.weight: Style.fontWeightMedium
        color: Color.mOnSurface
      }

      NText {
        Layout.fillWidth: true
        text: pluginApi?.tr("settings.info-text") || "This plugin requires KDE Connect to be installed and running. Make sure your phone is paired and the KDE Connect app is running on your device."
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }
    }
  }
}
