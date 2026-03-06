import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

// Minimal panel — theme switching is done via `theme-ctl set` keybind / walker menu.
// This panel just shows the current theme info.
ColumnLayout {
  id: root

  property var pluginApi: null

  spacing: Style.marginL
  implicitWidth: Math.round(400 * Style.uiScaleRatio)

  readonly property var pluginMain: pluginApi?.mainInstance
  readonly property bool isActive: pluginApi?.pluginSettings?.active || false
  readonly property bool isAvailable: pluginMain?.available || false
  readonly property string currentTheme: pluginMain?.themeName || ""

  NText {
    text: isAvailable ? ("Current theme: " + (currentTheme || "unknown")) : "theme-ctl not active"
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NText {
    text: "Switch themes with Super+Ctrl+T or run: theme-ctl set <name>"
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
    Layout.fillWidth: true
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NButton {
      Layout.fillWidth: true
      text: "Re-apply"
      enabled: isActive && isAvailable
      onClicked: pluginMain?.applyCurrentTheme()
    }
  }
}
