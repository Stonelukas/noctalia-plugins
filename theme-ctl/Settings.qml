import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  spacing: Style.marginL
  implicitWidth: Math.round(520 * Style.uiScaleRatio)
  Layout.minimumWidth: implicitWidth
  Layout.maximumWidth: implicitWidth
  Layout.preferredWidth: implicitWidth

  property bool showThemeName: true
  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property bool isApplying: pluginMain?.applying || false
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property bool isActive: pluginApi?.pluginSettings?.active || false
  readonly property string statusText: isApplying ? "Applying…" : (isAvailable ? "theme-ctl cache found" : "theme-ctl cache not found")

  function getSetting(key, fallback) {
    if (pluginApi?.pluginSettings && pluginApi.pluginSettings[key] !== undefined)
      return pluginApi.pluginSettings[key];
    if (defaultSettings && defaultSettings[key] !== undefined)
      return defaultSettings[key];
    return fallback;
  }

  function syncFromPlugin() {
    if (!pluginApi) return;
    showThemeName = getSetting("showThemeName", true) !== false;
  }

  onPluginApiChanged: syncFromPlugin()
  Component.onCompleted: syncFromPlugin()

  function saveSettings() {
    if (!pluginApi) return;
    var settings = pluginApi.pluginSettings || {};
    var changed = false;
    if (!!settings.showThemeName !== showThemeName) {
      settings.showThemeName = showThemeName;
      changed = true;
    }
    if (!changed) return;
    pluginApi.pluginSettings = settings;
    pluginApi.saveSettings();
  }

  NText {
    text: "Sync Noctalia colors from theme-ctl. Run 'theme-ctl set <name>' to switch themes."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NText {
    text: "Cache: ~/.cache/theme-ctl/colors.toml"
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    Layout.fillWidth: true
  }

  NToggle {
    label: "Show theme name in bar widget"
    description: "Display the current theme name next to the palette icon."
    checked: root.showThemeName
    onToggled: checked => {
      root.showThemeName = checked;
      root.saveSettings();
    }
  }

  NDivider { Layout.fillWidth: true }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: "Plugin controls"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      Layout.fillWidth: true
      text: statusText + " · " + (isActive ? "Active" : "Inactive")
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        Layout.fillWidth: true
        text: "Refresh"
        enabled: !!pluginMain
        onClicked: pluginMain?.refresh()
      }

      NButton {
        Layout.fillWidth: true
        text: isActive ? "Deactivate" : "Activate"
        enabled: !!pluginMain
        onClicked: {
          if (!pluginApi) return;
          if (pluginApi.pluginSettings.active) {
            pluginMain?.deactivate();
          } else {
            pluginMain?.activate();
          }
        }
      }

      NButton {
        Layout.fillWidth: true
        text: "Re-apply"
        enabled: !!pluginMain && isAvailable && !isApplying
        onClicked: pluginMain?.applyCurrentTheme()
      }
    }
  }
}
