import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  spacing: Style.marginL
  implicitWidth: Math.round(480 * Style.uiScaleRatio)

  // Local state
  property bool localShowIcon: pluginApi?.pluginSettings?.showIcon ?? true
  property int localMaxWidth: pluginApi?.pluginSettings?.maxWidth ?? 200
  property string localScrollingMode: pluginApi?.pluginSettings?.scrollingMode ?? "hover"
  property bool localHideWhenNoWindow: pluginApi?.pluginSettings?.hideWhenNoWindow ?? true
  property bool localShowPreview: pluginApi?.pluginSettings?.showPreview ?? true
  property bool localShowActions: pluginApi?.pluginSettings?.showActions ?? true
  property int localPreviewHeight: pluginApi?.pluginSettings?.previewHeight ?? 280

  function saveSettings() {
    if (!pluginApi) return;

    pluginApi.pluginSettings.showIcon = root.localShowIcon;
    pluginApi.pluginSettings.maxWidth = root.localMaxWidth;
    pluginApi.pluginSettings.scrollingMode = root.localScrollingMode;
    pluginApi.pluginSettings.hideWhenNoWindow = root.localHideWhenNoWindow;
    pluginApi.pluginSettings.showPreview = root.localShowPreview;
    pluginApi.pluginSettings.showActions = root.localShowActions;
    pluginApi.pluginSettings.previewHeight = root.localPreviewHeight;

    pluginApi.saveSettings();
    Logger.i("WindowInspector", "Settings saved");
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Configure the Window Inspector widget and panel."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NDivider { Layout.fillWidth: true }

  // Bar Widget section
  NText {
    text: pluginApi?.tr("settings.bar-widget") || "Bar Widget"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show-icon") || "Show Icon"
    description: pluginApi?.tr("settings.show-icon-hint") || "Display app icon in the bar widget"
    checked: root.localShowIcon
    onToggled: checked => root.localShowIcon = checked
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.hide-when-empty") || "Hide When No Window"
    description: pluginApi?.tr("settings.hide-when-empty-hint") || "Hide widget when no window is focused"
    checked: root.localHideWhenNoWindow
    onToggled: checked => root.localHideWhenNoWindow = checked
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NLabel {
      label: pluginApi?.tr("settings.max-width") || "Maximum Width"
      description: pluginApi?.tr("settings.max-width-hint") || "Maximum width of the bar widget"
    }

    NSlider {
      Layout.fillWidth: true
      from: 100
      to: 400
      stepSize: 10
      value: root.localMaxWidth
      onMoved: root.localMaxWidth = value
    }

    NText {
      text: `${root.localMaxWidth} px`
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
    }
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.scrolling-mode") || "Title Scrolling"
    description: pluginApi?.tr("settings.scrolling-mode-hint") || "When to scroll long window titles"

    model: [
      { key: "never", name: pluginApi?.tr("settings.scroll.never") || "Never" },
      { key: "hover", name: pluginApi?.tr("settings.scroll.hover") || "On Hover" },
      { key: "always", name: pluginApi?.tr("settings.scroll.always") || "Always" }
    ]

    currentKey: root.localScrollingMode
    onSelected: key => root.localScrollingMode = key
  }

  NDivider { Layout.fillWidth: true }

  // Panel section
  NText {
    text: pluginApi?.tr("settings.panel") || "Panel"
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightMedium
    color: Color.mOnSurface
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show-preview") || "Show Live Preview"
    description: pluginApi?.tr("settings.show-preview-hint") || "Display live window preview in panel"
    checked: root.localShowPreview
    onToggled: checked => root.localShowPreview = checked
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS
    enabled: root.localShowPreview

    NLabel {
      label: pluginApi?.tr("settings.preview-height") || "Preview Height"
      description: pluginApi?.tr("settings.preview-height-hint") || "Height of the live preview area"
    }

    NSlider {
      Layout.fillWidth: true
      from: 150
      to: 400
      stepSize: 10
      value: root.localPreviewHeight
      onMoved: root.localPreviewHeight = value
    }

    NText {
      text: `${root.localPreviewHeight} px`
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
    }
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.show-actions") || "Show Actions"
    description: pluginApi?.tr("settings.show-actions-hint") || "Display window control buttons"
    checked: root.localShowActions
    onToggled: checked => root.localShowActions = checked
  }

  NDivider { Layout.fillWidth: true }

  // Info
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
        text: pluginApi?.tr("settings.info-text") || "This plugin only works with Hyprland. The live preview uses the Wayland screencopy protocol."
        wrapMode: Text.WordWrap
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }
    }
  }
}
