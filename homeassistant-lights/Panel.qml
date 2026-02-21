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
  readonly property int contentPreferredWidth: Math.round(360 * Style.uiScaleRatio)
  readonly property int contentPreferredHeight: Math.round(600 * Style.uiScaleRatio)

  // Drag state for reordering
  property int dragFromIndex: -1
  property int dragToIndex: -1

  function moveLight(fromIndex, toIndex) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return;
    const currentOrder = pluginApi?.pluginSettings?.selectedLights || [];
    if (currentOrder.length === 0) return;
    
    const newOrder = currentOrder.slice();
    const item = newOrder.splice(fromIndex, 1)[0];
    newOrder.splice(toIndex, 0, item);
    
    pluginApi.pluginSettings.selectedLights = newOrder;
    pluginApi.saveSettings();
  }

  readonly property var pluginMain: pluginApi?.mainInstance

  readonly property bool isConnected: pluginMain?.connected || false
  readonly property bool isConnecting: pluginMain?.connecting || false
  readonly property string connectionError: pluginMain?.connectionError || ""

  readonly property var lights: pluginMain?.lights || []
  readonly property var currentState: pluginMain?.currentState || ({})
  readonly property int lightsOnCount: pluginMain?.lightsOnCount || 0

  Component.onCompleted: {
    pluginMain?.refresh();
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
          icon: "bulb"
          pointSize: Style.fontSizeXXL
          color: Color.mPrimary
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 2

          NText {
            text: pluginApi?.tr("title") || "Lights"
            font.weight: Style.fontWeightBold
            pointSize: Style.fontSizeL
            color: Color.mOnSurface
          }

          NText {
            visible: isConnected
            text: pluginApi?.tr("status.lights-summary", { on: lightsOnCount, total: lights.length }) 
              || lightsOnCount + " of " + lights.length + " on"
            pointSize: Style.fontSizeS
            color: Color.mOnSurfaceVariant
          }
        }

        Rectangle {
          width: Style.fontSizeM
          height: Style.fontSizeM
          radius: width / 2
          color: isConnected ? Color.mPrimary : (isConnecting ? Color.mSecondary : Color.mError)
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

    // Quick actions
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: quickActionsRow.implicitHeight + (Style.marginM * 2)
      visible: isConnected && lights.length > 0

      RowLayout {
        id: quickActionsRow
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NButton {
          Layout.fillWidth: true
          text: pluginApi?.tr("actions.all-on") || "All On"
          icon: "bulb"
          enabled: isConnected
          onClicked: pluginMain?.turnAllOn()
        }

        NButton {
          Layout.fillWidth: true
          text: pluginApi?.tr("actions.all-off") || "All Off"
          icon: "bulb-off"
          enabled: isConnected
          onClicked: pluginMain?.turnAllOff()
        }
      }
    }

    // Lights list
    NBox {
      id: lightsBox
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: 300 * Style.uiScaleRatio
      visible: isConnected

      ScrollView {
        anchors.fill: parent
        anchors.margins: Style.marginS
        clip: true

        ListView {
          id: lightsListView
          model: lights
          spacing: Style.marginS
          boundsBehavior: Flickable.StopAtBounds

          // Drop indicator line
          Rectangle {
            id: dropIndicator
            width: parent.width - Style.marginM * 2
            height: 3
            color: Color.mPrimary
            radius: 1.5
            visible: false
            z: 100
          }

          delegate: Item {
            id: lightDelegate
            required property int index
            required property var modelData

            width: lightsListView.width
            height: delegateContent.height
            z: dragArea.drag.active ? 100 : 1

            readonly property var lightState: currentState[modelData.entity_id] || {}
            readonly property bool isOn: lightState.state === "on"
            readonly property int brightness: lightState.attributes?.brightness || 0
            readonly property real brightnessPercent: Math.round((brightness / 255) * 100)
            readonly property bool supportsBrightness: {
              const modes = lightState.attributes?.supported_color_modes || [];
              return modes.includes("brightness") || modes.includes("color_temp") || 
                     modes.includes("hs") || modes.includes("rgb") || 
                     modes.includes("rgbw") || modes.includes("rgbww") || modes.includes("xy");
            }

            Rectangle {
              id: delegateContent
              width: parent.width
              height: lightContent.implicitHeight + (Style.marginM * 2)
              radius: Style.radiusM
              color: dragArea.drag.active ? Color.mPrimaryContainer : (delegateMouseArea.containsMouse ? Color.mHover : Color.mSurface)
              border.width: dragArea.drag.active ? 2 : 0
              border.color: Color.mPrimary

              Drag.active: dragArea.drag.active
              Drag.source: lightDelegate
              Drag.hotSpot.x: width / 2
              Drag.hotSpot.y: height / 2

              states: State {
                when: dragArea.drag.active
                ParentChange { target: delegateContent; parent: lightsListView }
                AnchorChanges {
                  target: delegateContent
                  anchors.horizontalCenter: undefined
                  anchors.verticalCenter: undefined
                }
              }

              Behavior on color {
                ColorAnimation { duration: Style.animationFast }
              }

              MouseArea {
                id: delegateMouseArea
                anchors.left: parent.left
                anchors.right: dragHandle.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                onClicked: pluginMain?.toggle(modelData.entity_id)
              }

              ColumnLayout {
                id: lightContent
                anchors.left: parent.left
                anchors.right: dragHandle.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: Style.marginM
                spacing: Style.marginS

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginM

                  NIcon {
                    icon: lightDelegate.isOn ? "bulb" : "bulb-off"
                    pointSize: Style.fontSizeXL
                    color: lightDelegate.isOn ? Color.mPrimary : Color.mOnSurfaceVariant
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    NText {
                      Layout.fillWidth: true
                      text: modelData.friendly_name || modelData.entity_id
                      font.weight: Style.fontWeightMedium
                      pointSize: Style.fontSizeM
                      color: Color.mOnSurface
                      elide: Text.ElideRight
                    }

                    NText {
                      visible: lightDelegate.isOn && lightDelegate.supportsBrightness
                      text: lightDelegate.brightnessPercent + "%"
                      pointSize: Style.fontSizeS
                      color: Color.mOnSurfaceVariant
                    }
                  }

                  NToggle {
                    checked: lightDelegate.isOn
                    onToggled: checked => {
                      if (checked) {
                        pluginMain?.turnOn(modelData.entity_id);
                      } else {
                        pluginMain?.turnOff(modelData.entity_id);
                      }
                    }
                  }
                }

                // Brightness slider
                RowLayout {
                  Layout.fillWidth: true
                  visible: lightDelegate.isOn && lightDelegate.supportsBrightness
                  spacing: Style.marginS

                  NIcon {
                    icon: "sun-low"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                  }

                  NSlider {
                    id: brightnessSlider
                    Layout.fillWidth: true
                    from: 1
                    to: 100
                    value: lightDelegate.brightnessPercent
                    enabled: lightDelegate.isOn

                    onPressedChanged: {
                      if (!pressed) {
                        pluginMain?.setBrightness(modelData.entity_id, value);
                      }
                    }
                  }

                  NIcon {
                    icon: "sun"
                    pointSize: Style.fontSizeM
                    color: Color.mOnSurfaceVariant
                  }
                }
              }

              // Drag handle
              Rectangle {
                id: dragHandle
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: Style.fontSizeXL * 2
                color: "transparent"

                NIcon {
                  anchors.centerIn: parent
                  icon: "grip-vertical"
                  pointSize: Style.fontSizeL
                  color: dragArea.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
                }

                MouseArea {
                  id: dragArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.SizeAllCursor
                  drag.target: delegateContent
                  drag.axis: Drag.YAxis

                  onPressed: {
                    root.dragFromIndex = lightDelegate.index;
                  }

                  onReleased: {
                    delegateContent.Drag.drop();
                    if (root.dragFromIndex >= 0 && root.dragToIndex >= 0 && root.dragFromIndex !== root.dragToIndex) {
                      root.moveLight(root.dragFromIndex, root.dragToIndex);
                    }
                    root.dragFromIndex = -1;
                    root.dragToIndex = -1;
                    dropIndicator.visible = false;
                  }
                }
              }

              DropArea {
                anchors.fill: parent

                onEntered: drag => {
                  const sourceDelegate = drag.source;
                  if (sourceDelegate && sourceDelegate !== lightDelegate) {
                    root.dragToIndex = lightDelegate.index;
                    dropIndicator.visible = true;
                    dropIndicator.y = lightDelegate.y;
                  }
                }

                onPositionChanged: drag => {
                  const sourceDelegate = drag.source;
                  if (sourceDelegate && sourceDelegate !== lightDelegate) {
                    const dropAtTop = drag.y < delegateContent.height / 2;
                    if (dropAtTop) {
                      root.dragToIndex = lightDelegate.index;
                      dropIndicator.y = lightDelegate.y;
                    } else {
                      root.dragToIndex = Math.min(lightDelegate.index + 1, lights.length - 1);
                      dropIndicator.y = lightDelegate.y + delegateContent.height + Style.marginS;
                    }
                  }
                }

                onExited: {
                  dropIndicator.visible = false;
                }
              }
            }
          }
        }
      }
    }

    // Connection status hint
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: hintColumn.implicitHeight + (Style.marginM * 2)
      visible: !isConnected

      ColumnLayout {
        id: hintColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          Layout.alignment: Qt.AlignHCenter
          icon: "bulb-off"
          pointSize: Style.fontSizeXXXL
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: isConnecting 
            ? (pluginApi?.tr("status.connecting") || "Connecting...") 
            : (connectionError || pluginApi?.tr("panel.not-connected") || "Not connected to Home Assistant")
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          visible: !isConnecting
          text: pluginApi?.tr("panel.settings-hint") || "Configure connection in Settings > Plugins > Home Assistant Lights"
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          pointSize: Style.fontSizeS
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }

    // Empty state
    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: emptyColumn.implicitHeight + (Style.marginM * 2)
      visible: isConnected && lights.length === 0

      ColumnLayout {
        id: emptyColumn
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        NIcon {
          Layout.alignment: Qt.AlignHCenter
          icon: "bulb-off"
          pointSize: Style.fontSizeXXXL
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.no-lights") || "No lights found"
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: Color.mOnSurfaceVariant
        }

        NText {
          Layout.fillWidth: true
          text: pluginApi?.tr("panel.no-lights-hint") || "Make sure you have light entities in Home Assistant"
          color: Color.mOnSurfaceVariant
          wrapMode: Text.WordWrap
          pointSize: Style.fontSizeS
          horizontalAlignment: Text.AlignHCenter
        }
      }
    }
  }
}
