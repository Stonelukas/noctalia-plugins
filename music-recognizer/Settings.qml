import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  property var pluginApi: null

  spacing: Style.marginL

  // Local state mirrors pluginSettings
  property int recordDuration: pluginApi?.pluginSettings?.recordDurationSecs ?? 5
  property int historyLimit: pluginApi?.pluginSettings?.historyLimit ?? 50
  property bool showNotifications: pluginApi?.pluginSettings?.showNotifications ?? true
  property int resetDelay: pluginApi?.pluginSettings?.resetDelaySecs ?? 5

  // Header
  NText {
    text: pluginApi?.tr("settings.header") || "Music Recognizer Settings"
    font.pointSize: Style.fontSizeL
    font.weight: Font.Medium
    color: Color.mOnSurface
  }

  // Recording Duration
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true

      NText {
        text: pluginApi?.tr("settings.duration.label") || "Recording Duration"
        font.pointSize: Style.fontSizeM
        color: Color.mOnSurface
      }

      Item { Layout.fillWidth: true }

      NText {
        text: root.recordDuration + "s"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
        color: Color.mPrimary
      }
    }

    NText {
      text: pluginApi?.tr("settings.duration.description") || "How long to capture audio (longer = better recognition)"
      font.pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    NSlider {
      Layout.fillWidth: true
      from: 3
      to: 15
      stepSize: 1
      value: root.recordDuration
      onMoved: root.recordDuration = Math.round(value)
    }
  }

  NDivider {}

  // Reset Delay (per plan validation)
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true

      NText {
        text: pluginApi?.tr("settings.reset.label") || "Reset Delay"
        font.pointSize: Style.fontSizeM
        color: Color.mOnSurface
      }

      Item { Layout.fillWidth: true }

      NText {
        text: root.resetDelay + "s"
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
        color: Color.mPrimary
      }
    }

    NText {
      text: pluginApi?.tr("settings.reset.description") || "Time before widget returns to idle after success/error"
      font.pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    NSlider {
      Layout.fillWidth: true
      from: 3
      to: 15
      stepSize: 1
      value: root.resetDelay
      onMoved: root.resetDelay = Math.round(value)
    }
  }

  NDivider {}

  // History Limit
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    RowLayout {
      Layout.fillWidth: true

      NText {
        text: pluginApi?.tr("settings.history.label") || "History Limit"
        font.pointSize: Style.fontSizeM
        color: Color.mOnSurface
      }

      Item { Layout.fillWidth: true }

      NText {
        text: root.historyLimit + " " + (pluginApi?.tr("settings.history.songs") || "songs")
        font.pointSize: Style.fontSizeM
        font.weight: Font.Medium
        color: Color.mPrimary
      }
    }

    NText {
      text: pluginApi?.tr("settings.history.description") || "Maximum number of songs to keep in history"
      font.pointSize: Style.fontSizeS
      color: Color.mOnSurfaceVariant
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    }

    NSlider {
      Layout.fillWidth: true
      from: 10
      to: 100
      stepSize: 10
      value: root.historyLimit
      onMoved: root.historyLimit = Math.round(value)
    }
  }

  NDivider {}

  // Notifications Toggle
  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.notifications.label") || "Show Notifications"
    description: pluginApi?.tr("settings.notifications.description") || "Display toast when song is recognized"
    checked: root.showNotifications
    onToggled: checked => { root.showNotifications = checked }
  }

  Item { Layout.fillHeight: true }

  // Info section
  Rectangle {
    Layout.fillWidth: true
    height: infoContent.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant
    radius: Style.radiusM

    ColumnLayout {
      id: infoContent
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      RowLayout {
        spacing: Style.marginS

        NIcon { icon: "info"; color: Color.mOnSurfaceVariant }

        NText {
          text: pluginApi?.tr("settings.info.title") || "Requirements"
          font.pointSize: Style.fontSizeS
          font.weight: Font.Medium
          color: Color.mOnSurfaceVariant
        }
      }

      NText {
        text: pluginApi?.tr("settings.info.content") || "• PipeWire with pw-record\n• Python 3.10+\n• Internet connection"
        font.pointSize: Style.fontSizeS
        color: Color.mOnSurfaceVariant
        opacity: 0.8
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
      }
    }
  }

  // Called by Noctalia when settings panel closes
  function saveSettings() {
    if (!pluginApi) return;

    pluginApi.pluginSettings.recordDurationSecs = root.recordDuration;
    pluginApi.pluginSettings.historyLimit = root.historyLimit;
    pluginApi.pluginSettings.showNotifications = root.showNotifications;
    pluginApi.pluginSettings.resetDelaySecs = root.resetDelay;
    pluginApi.saveSettings();

    Logger.i("MusicRecognizer", "Settings saved: duration=" + root.recordDuration +
             "s, reset=" + root.resetDelay + "s, limit=" + root.historyLimit +
             ", notifications=" + root.showNotifications);
  }
}
