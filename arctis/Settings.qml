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
  property int valuePollInterval: pluginApi?.pluginSettings?.pollIntervalMs || 30000
  property bool valueShowInBar: pluginApi?.pluginSettings?.showInBar ?? true

  readonly property var pluginMain: pluginApi?.mainInstance

  Component.onCompleted: {
    Logger.i("Arctis", "Settings UI loaded");
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("Arctis", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.pollIntervalMs = root.valuePollInterval;
    pluginApi.pluginSettings.showInBar = root.valueShowInBar;

    pluginApi.saveSettings();

    Logger.i("Arctis", "Settings saved successfully");
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Configure Arctis headset monitoring."
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
      label: pluginApi?.tr("settings.show-in-bar") || "Show in Bar"
      description: pluginApi?.tr("settings.show-in-bar-hint") || "Show headset status icon in the bar."
      checked: root.valueShowInBar
      onToggled: checked => root.valueShowInBar = checked
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
      description: pluginApi?.tr("settings.poll-interval-hint") || "How often to check headset status."

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
        text: pluginApi?.tr("settings.info-text") || "This plugin requires arctis-manager to be installed and running. It monitors headset connection status and displays microphone settings."
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }
    }
  }
}
