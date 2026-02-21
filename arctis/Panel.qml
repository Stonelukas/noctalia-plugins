import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property var screen: null

  readonly property bool allowAttach: true
  readonly property int contentPreferredWidth: Math.round(340 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: mainColumn.implicitHeight + (Style.marginL * 2)

  readonly property var pluginMain: pluginApi?.mainInstance

  readonly property bool headsetConnected: pluginMain?.headsetConnected || false
  readonly property string headsetName: pluginMain?.headsetName || "Arctis"
  readonly property var micSettings: pluginMain?.micSettings || ({})

  // Volume state (read-only, controlled by physical dial via arctis-manager)
  readonly property int gameVolume: pluginMain?.gameVolume ?? 100
  readonly property int chatVolume: pluginMain?.chatVolume ?? 100
  readonly property bool gameMuted: pluginMain?.gameMuted || false
  readonly property bool chatMuted: pluginMain?.chatMuted || false
  readonly property bool micMuted: pluginMain?.micMuted || false

  Component.onCompleted: {
    pluginMain?.checkHeadset();
    pluginMain?.loadMicSettings();
  }

  ColumnLayout {
    id: mainColumn
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginM

    // Header
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: headerRow.implicitHeight + (Style.marginM * 2)

      RowLayout {
        id: headerRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: "headphones"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: pluginApi?.tr("title") || "Arctis Headset"
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
          }

          NText {
            visible: headsetConnected
            text: headsetName
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }

        Rectangle {
          width: Style.fontSizeM
          height: Style.fontSizeM
          radius: width / 2
          color: headsetConnected ? Color.mPrimary : Color.mError
          border.width: Style.borderS
          border.color: Color.mOutline
        }

        NIconButton {
          icon: "close"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: pluginApi?.tr("tooltips.close") || "Close"
          onClicked: pluginApi?.closePanel(root.screen)
        }
      }
    }

    // Mic settings card
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: micColumn.implicitHeight + (Style.marginL * 2)
      visible: headsetConnected && Object.keys(micSettings).length > 0

      ColumnLayout {
        id: micColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("panel.mic-settings") || "Microphone Settings"
          font.weight: Style.fontWeightMedium
          pointSize: Style.fontSizeM
          color: Color.mOnSurface
        }

        // Mic volume
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: micSettings.mic_volume !== undefined

          NIcon {
            icon: "microphone"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
          }

          NText {
            text: pluginApi?.tr("panel.mic-volume") || "Volume"
            color: Color.mOnSurfaceVariant
          }

          Item { Layout.fillWidth: true }

          NText {
            text: micSettings.mic_volume !== undefined ? micSettings.mic_volume.toString() : "-"
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }
        }

        // Sidetone
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: micSettings.mic_side_tone !== undefined

          NIcon {
            icon: "ear"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
          }

          NText {
            text: pluginApi?.tr("panel.sidetone") || "Sidetone"
            color: Color.mOnSurfaceVariant
          }

          Item { Layout.fillWidth: true }

          NText {
            text: micSettings.mic_side_tone !== undefined ? micSettings.mic_side_tone.toString() : "-"
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }
        }

        // Mic gain
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: micSettings.mic_gain !== undefined

          NIcon {
            icon: "adjustments"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
          }

          NText {
            text: pluginApi?.tr("panel.mic-gain") || "Gain"
            color: Color.mOnSurfaceVariant
          }

          Item { Layout.fillWidth: true }

          NText {
            text: micSettings.mic_gain !== undefined ? micSettings.mic_gain.toString() : "-"
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }
        }

        // Auto shutdown
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: micSettings.pm_shutdown !== undefined

          NIcon {
            icon: "power"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
          }

          NText {
            text: pluginApi?.tr("panel.auto-shutdown") || "Auto Shutdown"
            color: Color.mOnSurfaceVariant
          }

          Item { Layout.fillWidth: true }

          NText {
            text: {
              if (micSettings.pm_shutdown === undefined) return "-";
              if (micSettings.pm_shutdown === 0) return pluginApi?.tr("panel.never") || "Never";
              return micSettings.pm_shutdown + " " + (pluginApi?.tr("panel.minutes") || "min");
            }
            font.weight: Style.fontWeightMedium
            color: Color.mOnSurface
          }
        }
      }
    }

    // ChatMix Status (read-only, controlled by physical dial)
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: chatMixColumn.implicitHeight + (Style.marginL * 2)
      visible: headsetConnected

      ColumnLayout {
        id: chatMixColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            text: pluginApi?.tr("panel.chatmix") || "ChatMix"
            font.weight: Style.fontWeightMedium
            pointSize: Style.fontSizeM
            color: Color.mOnSurface
          }

          Item { Layout.fillWidth: true }

          NText {
            text: "via dial"
            pointSize: Style.fontSizeXS
            color: Color.mOnSurfaceVariant
          }
        }

        // Visual balance bar
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NIcon {
            icon: "message-circle"
            pointSize: Style.fontSizeM
            color: chatVolume >= gameVolume ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          Rectangle {
            Layout.fillWidth: true
            height: 8
            radius: 4
            color: Color.mSurfaceVariant

            Rectangle {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width * (chatVolume / 100)
              height: parent.height
              radius: 4
              color: Color.mSecondary
            }

            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width * (gameVolume / 100)
              height: parent.height
              radius: 4
              color: Color.mPrimary
            }
          }

          NIcon {
            icon: "device-gamepad-2"
            pointSize: Style.fontSizeM
            color: gameVolume >= chatVolume ? Color.mPrimary : Color.mOnSurfaceVariant
          }
        }

        // Percentage display
        RowLayout {
          Layout.fillWidth: true

          NText {
            text: "Chat " + chatVolume + "%"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }

          Item { Layout.fillWidth: true }

          NText {
            text: gameVolume + "% Game"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            horizontalAlignment: Text.AlignRight
          }
        }
      }
    }

    // Quick Actions (mute controls)
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: actionsRow.implicitHeight + (Style.marginM * 2)
      visible: headsetConnected

      RowLayout {
        id: actionsRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIconButton {
          icon: gameMuted ? "volume-off" : "device-gamepad-2"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: gameMuted ? "Unmute Game" : "Mute Game"
          color: gameMuted ? Color.mError : Color.mOnSurfaceVariant
          onClicked: pluginMain?.setGameMuted(!gameMuted)
        }

        NText {
          text: gameMuted ? "Game Muted" : "Game"
          pointSize: Style.fontSizeS
          color: gameMuted ? Color.mError : Color.mOnSurfaceVariant
        }

        Item { Layout.fillWidth: true }

        NText {
          text: chatMuted ? "Chat Muted" : "Chat"
          pointSize: Style.fontSizeS
          color: chatMuted ? Color.mError : Color.mOnSurfaceVariant
        }

        NIconButton {
          icon: chatMuted ? "volume-off" : "message-circle"
          baseSize: Style.baseWidgetSize * 0.8
          tooltipText: chatMuted ? "Unmute Chat" : "Mute Chat"
          color: chatMuted ? Color.mError : Color.mOnSurfaceVariant
          onClicked: pluginMain?.setChatMuted(!chatMuted)
        }
      }
    }

    // Mic Mute Status
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: micMuteRow.implicitHeight + (Style.marginM * 2)
      visible: headsetConnected

      RowLayout {
        id: micMuteRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          icon: micMuted ? "microphone-off" : "microphone"
          pointSize: Style.fontSizeXL
          color: micMuted ? Color.mError : Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: pluginApi?.tr("panel.microphone") || "Microphone"
            font.weight: Style.fontWeightMedium
            pointSize: Style.fontSizeM
            color: Color.mOnSurface
          }

          NText {
            text: micMuted 
              ? (pluginApi?.tr("status.muted") || "Muted")
              : (pluginApi?.tr("status.active") || "Active")
            pointSize: Style.fontSizeS
            color: micMuted ? Color.mError : Color.mOnSurfaceVariant
          }
        }

        NButton {
          text: micMuted ? "Unmute" : "Mute"
          icon: micMuted ? "microphone" : "microphone-off"
          onClicked: pluginMain?.toggleMicMute()
        }
      }
    }

    // Actions
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: actionsColumn.implicitHeight + (Style.marginM * 2)
      visible: headsetConnected

      ColumnLayout {
        id: actionsColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NButton {
          Layout.fillWidth: true
          text: pluginApi?.tr("actions.open-settings") || "Open Arctis Settings"
          icon: "settings"
          onClicked: pluginMain?.openSettings()
        }
      }
    }

    // Not connected hint
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: hintColumn.implicitHeight + (Style.marginM * 2)
      visible: !headsetConnected

      ColumnLayout {
        id: hintColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          Layout.alignment: Qt.AlignHCenter
          icon: "headphones-off"
          pointSize: Style.fontSizeXXXL
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.not-connected") || "Headset not connected"
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.not-connected-hint") || "Make sure your Arctis headset is connected and arctis-manager is running"
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          pointSize: Style.fontSizeS
          horizontalAlignment: Text.AlignHCenter
        }

        NButton {
          Layout.alignment: Qt.AlignHCenter
          text: pluginApi?.tr("actions.refresh") || "Refresh"
          icon: "refresh"
          onClicked: pluginMain?.checkHeadset()
        }
      }
    }

    // Spacer
    Item {
      Layout.fillHeight: true
    }
  }
}
