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
  property int valuePollInterval: pluginApi?.pluginSettings?.pollIntervalMs || 60000
  property bool valueShowBatteryPercent: pluginApi?.pluginSettings?.showBatteryPercent ?? true
  property int valueLowBatteryWarning: pluginApi?.pluginSettings?.lowBatteryWarning || 20

  readonly property var pluginMain: pluginApi?.mainInstance

  Component.onCompleted: {
    Logger.i("OpenRazer", "Settings UI loaded");
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("OpenRazer", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.pollIntervalMs = root.valuePollInterval;
    pluginApi.pluginSettings.showBatteryPercent = root.valueShowBatteryPercent;
    pluginApi.pluginSettings.lowBatteryWarning = root.valueLowBatteryWarning;

    pluginApi.saveSettings();

    Logger.i("OpenRazer", "Settings saved successfully");
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Configure OpenRazer device monitoring and control."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
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

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginM

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        NText {
          text: pluginApi?.tr("settings.low-battery") || "Low Battery Warning"
          color: Color.mOnSurface
        }

        NText {
          text: pluginApi?.tr("settings.low-battery-hint") || "Show warning color when battery is below this level."
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
      }

      NSlider {
        Layout.preferredWidth: 120
        from: 5
        to: 50
        stepSize: 5
        value: root.valueLowBatteryWarning
        onValueChanged: root.valueLowBatteryWarning = value
      }

      NText {
        text: root.valueLowBatteryWarning + "%"
        color: Color.mOnSurface
        Layout.preferredWidth: 35
      }
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
      description: pluginApi?.tr("settings.poll-interval-hint") || "How often to check device status."

      model: [
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
        text: pluginApi?.tr("settings.info-text") || "This plugin requires OpenRazer to be installed. Visit openrazer.github.io for installation instructions."
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }
    }
  }
}
