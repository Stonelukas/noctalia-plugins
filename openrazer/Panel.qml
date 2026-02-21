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

  readonly property bool hasDevice: pluginMain?.hasDevice || false
  readonly property bool hasBattery: pluginMain?.hasBattery || false
  readonly property int batteryPercent: pluginMain?.batteryPercent ?? -1
  readonly property bool isCharging: pluginMain?.isCharging || false
  readonly property string deviceName: pluginMain?.deviceName || ""
  readonly property string deviceType: pluginMain?.deviceType || ""
  readonly property double brightness: pluginMain?.brightness ?? 0
  readonly property bool lowBattery: pluginMain?.lowBattery || false
  readonly property int maxDpi: pluginMain?.maxDpi || 0

  Component.onCompleted: {
    pluginMain?.refreshDevices();
  }

  readonly property string deviceIcon: {
    if (deviceType === "keyboard") return "keyboard";
    if (deviceType === "headset") return "headphones";
    return "mouse";
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
          icon: deviceIcon
          pointSize: Style.fontSizeXXL
          color: "#00ff00" // Razer green
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: pluginApi?.tr("title") || "OpenRazer"
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
          }

          NText {
            visible: hasDevice
            text: deviceName
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }

        Rectangle {
          width: Style.fontSizeM
          height: Style.fontSizeM
          radius: width / 2
          color: hasDevice ? "#00ff00" : Color.mError
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

    // Battery card
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: batteryColumn.implicitHeight + (Style.marginL * 2)
      visible: hasDevice && hasBattery

      ColumnLayout {
        id: batteryColumn
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NIcon {
            icon: isCharging ? "battery-charging" : "battery"
            pointSize: Style.fontSizeXXL
            color: batteryColor
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            NText {
              text: batteryPercent + "%"
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

          Rectangle {
            width: parent.width * (batteryPercent / 100)
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

    // Brightness control
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: brightnessColumn.implicitHeight + (Style.marginM * 2)
      visible: hasDevice

      ColumnLayout {
        id: brightnessColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("panel.brightness") || "Brightness"
          font.weight: Style.fontWeightMedium
          pointSize: Style.fontSizeM
          color: Color.mOnSurface
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NIcon {
            icon: "sun-low"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
          }

          NSlider {
            id: brightnessSlider
            Layout.fillWidth: true
            from: 0
            to: 100
            value: brightness
            
            onPressedChanged: {
              if (!pressed) {
                pluginMain?.setBrightness(value);
              }
            }
          }

          NIcon {
            icon: "sun"
            pointSize: Style.fontSizeL
            color: Color.mOnSurfaceVariant
          }

          NText {
            text: Math.round(brightnessSlider.value) + "%"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
            Layout.preferredWidth: 40
          }
        }
      }
    }

    // Device info
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: infoColumn.implicitHeight + (Style.marginM * 2)
      visible: hasDevice

      ColumnLayout {
        id: infoColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginS

        NText {
          text: pluginApi?.tr("panel.info") || "Device Info"
          font.weight: Style.fontWeightMedium
          pointSize: Style.fontSizeM
          color: Color.mOnSurface
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM

          NText {
            text: pluginApi?.tr("panel.type") || "Type:"
            color: Color.mOnSurfaceVariant
          }

          NText {
            text: deviceType.charAt(0).toUpperCase() + deviceType.slice(1)
            color: Color.mOnSurface
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginM
          visible: maxDpi > 0

          NText {
            text: pluginApi?.tr("panel.max-dpi") || "Max DPI:"
            color: Color.mOnSurfaceVariant
          }

          NText {
            text: maxDpi.toString()
            color: Color.mOnSurface
          }
        }
      }
    }

    // Not connected hint
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
          icon: "mouse-off"
          pointSize: Style.fontSizeXXXL
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.no-device") || "No Razer device found"
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.no-device-hint") || "Make sure OpenRazer is installed and your device is connected"
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

  }
}
