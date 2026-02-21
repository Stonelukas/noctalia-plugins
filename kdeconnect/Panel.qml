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
  readonly property int contentPreferredWidth: Math.round(320 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: Math.round(400 * Style.uiScaleRatio)

  readonly property var pluginMain: pluginApi?.mainInstance

  readonly property bool hasDevice: pluginMain?.hasDevice || false
  readonly property bool deviceReachable: pluginMain?.deviceReachable || false
  readonly property int batteryLevel: pluginMain?.batteryLevel ?? -1
  readonly property bool isCharging: pluginMain?.isCharging || false
  readonly property string deviceName: pluginMain?.deviceName || ""
  readonly property bool lowBattery: pluginMain?.lowBattery || false
  readonly property var devices: pluginMain?.devices || []

  Component.onCompleted: {
    pluginMain?.refreshDevices();
  }

  readonly property string batteryIcon: {
    // Use device-mobile icon with variants
    if (batteryLevel < 0) return "device-mobile-off";
    return "device-mobile";
  }

  readonly property color batteryColor: {
    if (lowBattery) return Color.mError;
    if (isCharging) return Color.mPrimary;
    return Color.mOnSurface;
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
          icon: "bt-device-phone"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: pluginApi?.tr("title") || "KDE Connect"
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
          }

          NText {
            visible: hasDevice
            text: deviceReachable 
              ? (pluginApi?.tr("status.connected") || "Connected")
              : (pluginApi?.tr("status.unreachable") || "Unreachable")
            pointSize: Style.fontSizeS
            color: deviceReachable ? Color.mPrimary : Color.mOnSurfaceVariant
          }
        }

        Rectangle {
          width: Style.fontSizeM
          height: Style.fontSizeM
          radius: width / 2
          color: hasDevice && deviceReachable ? Color.mPrimary : Color.mError
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

    // Device info card
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: deviceColumn.implicitHeight + (Style.marginL * 2)
      visible: hasDevice

      ColumnLayout {
        id: deviceColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        // Device name
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NIcon {
            icon: "device-mobile"
            pointSize: Style.fontSizeXL
            color: Color.mOnSurfaceVariant
          }

          NText {
            Layout.fillWidth: true
            text: deviceName
            font.weight: Style.fontWeightMedium
            pointSize: Style.fontSizeM
            color: Color.mOnSurface
            elide: Text.ElideRight
          }
        }

        // Battery display
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: batteryLevel >= 0

          NIcon {
            icon: batteryIcon
            pointSize: Style.fontSizeXXL
            color: batteryColor
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            NText {
              text: batteryLevel + "%"
              font.weight: Style.fontWeightBold
              pointSize: Style.fontSizeXL
              color: batteryColor
            }

            NText {
              text: isCharging 
                ? (pluginApi?.tr("status.charging") || "Charging")
                : (pluginApi?.tr("status.battery") || "Battery")
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }
        }

        // Battery progress bar
        Rectangle {
          Layout.fillWidth: true
          height: 8
          radius: 4
          color: Color.mSurfaceVariant
          visible: batteryLevel >= 0

          Rectangle {
            width: parent.width * (batteryLevel / 100)
            height: parent.height
            radius: 4
            color: batteryColor

            Behavior on width {
              NumberAnimation { duration: Style.animationNormal }
            }
          }
        }
      }
    }

    // Quick actions
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: actionsColumn.implicitHeight + (Style.marginM * 2)
      visible: hasDevice && deviceReachable

      ColumnLayout {
        id: actionsColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("panel.actions") || "Quick Actions"
          font.weight: Style.fontWeightMedium
          pointSize: Style.fontSizeM
          color: Color.mOnSurface
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NButton {
            Layout.fillWidth: true
            text: pluginApi?.tr("actions.ping") || "Ping"
            icon: "bell"
            enabled: deviceReachable
            onClicked: pluginMain?.pingDevice()
          }

          NButton {
            Layout.fillWidth: true
            text: pluginApi?.tr("actions.ring") || "Find Phone"
            icon: "phone-ringing"
            enabled: deviceReachable
            onClicked: pluginMain?.ringDevice()
          }
        }
      }
    }

    // Device list (if multiple devices)
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: deviceListColumn.implicitHeight + (Style.marginM * 2)
      visible: devices.length > 1

      ColumnLayout {
        id: deviceListColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NText {
          text: pluginApi?.tr("panel.devices") || "Devices"
          font.weight: Style.fontWeightMedium
          pointSize: Style.fontSizeM
          color: Color.mOnSurface
        }

        Repeater {
          model: devices

          delegate: Rectangle {
            Layout.fillWidth: true
            height: deviceRow.implicitHeight + Style.marginS * 2
            radius: Style.radiusS
            color: modelData === pluginMain?.currentDevice ? Color.mPrimary : Color.mSurface

            RowLayout {
              id: deviceRow
              anchors.fill: parent
              anchors.margins: Style.marginS
              spacing: Style.marginS

              NIcon {
                icon: "device-mobile"
                pointSize: Style.fontSizeL
                color: modelData === pluginMain?.currentDevice ? Color.mOnPrimary : Color.mOnSurfaceVariant
              }

              NText {
                Layout.fillWidth: true
                text: modelData
                pointSize: Style.fontSizeS
                color: modelData === pluginMain?.currentDevice ? Color.mOnPrimary : Color.mOnSurface
                elide: Text.ElideMiddle
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                pluginApi.pluginSettings.preferredDevice = modelData;
                pluginApi.saveSettings();
                pluginMain?.refreshDevices();
              }
            }
          }
        }
      }
    }

    // No device hint
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: hintColumn.implicitHeight + (Style.marginM * 2)
      visible: !hasDevice

      ColumnLayout {
        id: hintColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          Layout.alignment: Qt.AlignHCenter
          icon: "device-mobile-off"
          pointSize: Style.fontSizeXXXL
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.no-device") || "No phone connected"
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.no-device-hint") || "Make sure KDE Connect is running and your phone is paired"
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          pointSize: Style.fontSizeS
          horizontalAlignment: Text.AlignHCenter
        }

        NButton {
          Layout.alignment: Qt.AlignHCenter
          text: pluginApi?.tr("actions.refresh") || "Refresh"
          icon: "refresh"
          onClicked: pluginMain?.refreshDevices()
        }
      }
    }

    // Spacer
    Item {
      Layout.fillHeight: true
    }
  }
}
