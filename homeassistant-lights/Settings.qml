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

  // Local state - track changes before saving
  property string valueHaUrl: pluginApi?.pluginSettings?.haUrl || pluginApi?.manifest?.metadata?.defaultSettings?.haUrl || ""
  property string valueHaToken: pluginApi?.pluginSettings?.haToken || pluginApi?.manifest?.metadata?.defaultSettings?.haToken || ""
  property string valueFavoriteLight: pluginApi?.pluginSettings?.favoriteLight || pluginApi?.manifest?.metadata?.defaultSettings?.favoriteLight || ""
  property var valueSelectedLights: pluginApi?.pluginSettings?.selectedLights || []
  property bool testingConnection: false
  property string testResult: ""
  property bool testSuccess: true

  // Drag state for reordering
  property int dragFromIndex: -1
  property int dragToIndex: -1

  function isLightSelected(entityId) {
    return valueSelectedLights.includes(entityId);
  }

  function getSelectionOrder(entityId) {
    return valueSelectedLights.indexOf(entityId) + 1;
  }

  function toggleLightSelection(entityId) {
    const newSelection = valueSelectedLights.slice();
    const index = newSelection.indexOf(entityId);
    if (index >= 0) {
      newSelection.splice(index, 1);
    } else {
      newSelection.push(entityId);
    }
    valueSelectedLights = newSelection;
  }

  function moveLight(fromIndex, toIndex) {
    if (fromIndex === toIndex || fromIndex < 0 || toIndex < 0) return;
    const newOrder = valueSelectedLights.slice();
    if (newOrder.length === 0) return;
    
    const item = newOrder.splice(fromIndex, 1)[0];
    newOrder.splice(toIndex, 0, item);
    valueSelectedLights = newOrder;
  }

  // Ordered list: selected lights first (in order), then unselected
  readonly property var orderedLights: {
    const all = pluginMain?.allLights || [];
    const selected = valueSelectedLights || [];
    const selectedLights = [];
    const unselectedLights = [];
    
    // Add selected lights in order
    for (const id of selected) {
      const light = all.find(l => l.entity_id === id);
      if (light) selectedLights.push(light);
    }
    
    // Add unselected lights
    for (const light of all) {
      if (!selected.includes(light.entity_id)) {
        unselectedLights.push(light);
      }
    }
    
    return selectedLights.concat(unselectedLights);
  }

  function selectAllLights() {
    const allIds = (pluginMain?.allLights || []).map(l => l.entity_id);
    valueSelectedLights = allIds;
  }

  function deselectAllLights() {
    valueSelectedLights = [];
  }

  readonly property var pluginMain: pluginApi?.mainInstance

  Component.onCompleted: {
    Logger.i("HomeAssistantLights", "Settings UI loaded");
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("HomeAssistantLights", "Cannot save settings: pluginApi is null");
      return;
    }

    pluginApi.pluginSettings.haUrl = root.valueHaUrl.trim().replace(/\/+$/, "");
    pluginApi.pluginSettings.haToken = root.valueHaToken.trim();
    pluginApi.pluginSettings.favoriteLight = root.valueFavoriteLight;
    pluginApi.pluginSettings.selectedLights = root.valueSelectedLights;

    pluginApi.saveSettings();

    if (pluginMain) {
      pluginMain.reconnect();
    }

    Logger.i("HomeAssistantLights", "Settings saved successfully");
  }

  function testConnection() {
    if (!valueHaUrl || !valueHaToken) {
      testResult = pluginApi?.tr("errors.no-url") || "Please configure URL and token";
      testSuccess = false;
      return;
    }

    testingConnection = true;
    testResult = "";
    testSuccess = true;

    var xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        testingConnection = false;
        if (xhr.status === 200) {
          testResult = pluginApi?.tr("settings.connection-success") || "Connected successfully";
          testSuccess = true;
        } else if (xhr.status === 401) {
          testResult = pluginApi?.tr("errors.auth-invalid") || "Invalid access token";
          testSuccess = false;
        } else {
          testResult = pluginApi?.tr("settings.connection-failed") || "Connection failed";
          testSuccess = false;
        }
      }
    };

    xhr.onerror = function () {
      testingConnection = false;
      testResult = pluginApi?.tr("settings.connection-failed") || "Connection failed";
      testSuccess = false;
    };

    const testUrl = valueHaUrl.trim().replace(/\/+$/, "") + "/api/";
    xhr.open("GET", testUrl);
    xhr.setRequestHeader("Authorization", "Bearer " + valueHaToken.trim());
    xhr.timeout = 10000;
    xhr.send();
  }

  NText {
    text: pluginApi?.tr("settings.description") || "Connect to your Home Assistant instance to control lights."
    wrapMode: Text.WordWrap
    color: Color.mOnSurface
  }

  NText {
    text: pluginApi?.tr("settings.token-hint") || "Create a Long-Lived Access Token at Profile > Security in Home Assistant."
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeS
  }

  NTextInput {
    label: pluginApi?.tr("settings.url") || "Home Assistant URL"
    placeholderText: pluginApi?.tr("settings.url-placeholder") || "http://homeassistant.local:8123"
    text: root.valueHaUrl
    onTextChanged: root.valueHaUrl = text
  }

  NTextInput {
    label: pluginApi?.tr("settings.token") || "Access Token"
    placeholderText: "eyJ0eXAiOiJKV1..."
    text: root.valueHaToken
    inputItem.echoMode: TextInput.Password
    onTextChanged: root.valueHaToken = text
  }

  RowLayout {
    spacing: Style.marginM

    NButton {
      text: testingConnection ? (pluginApi?.tr("status.connecting") || "Connecting...") : (pluginApi?.tr("settings.test-connection") || "Test Connection")
      enabled: !testingConnection && valueHaUrl !== "" && valueHaToken !== ""
      onClicked: testConnection()
    }

    NText {
      visible: testResult !== ""
      text: testResult
      color: testSuccess ? Color.mPrimary : Color.mError
      pointSize: Style.fontSizeS
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.favorite-light") || "Favorite Light"
    description: pluginApi?.tr("settings.favorite-light-hint") || "Select the light to control by default."
    enabled: pluginMain?.allLights?.length > 0

    model: {
      const lights = pluginMain?.allLights || [];
      if (lights.length === 0) {
        return [{ key: "", name: pluginApi?.tr("settings.no-lights") || "No lights found" }];
      }
      const options = [{ key: "", name: pluginApi?.tr("settings.none") || "(None)" }];
      for (const light of lights) {
        options.push({ key: light.entity_id, name: light.friendly_name || light.entity_id });
      }
      return options;
    }

    currentKey: root.valueFavoriteLight || ""
    onSelected: key => root.valueFavoriteLight = key
  }

  NDivider {
    Layout.fillWidth: true
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.marginS

    NText {
      text: pluginApi?.tr("settings.visible-lights") || "Visible Lights"
      pointSize: Style.fontSizeM
      font.weight: Style.fontWeightMedium
      color: Color.mOnSurface
    }

    NText {
      Layout.fillWidth: true
      text: pluginApi?.tr("settings.visible-lights-hint") || "Select which lights to show. Reorder in the panel by dragging."
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NButton {
        text: pluginApi?.tr("settings.select-all") || "Select All"
        enabled: (pluginMain?.allLights?.length || 0) > 0
        onClicked: selectAllLights()
      }

      NButton {
        text: pluginApi?.tr("settings.deselect-all") || "Deselect All"
        enabled: valueSelectedLights.length > 0
        onClicked: deselectAllLights()
      }

      Item { Layout.fillWidth: true }

      NText {
        text: valueSelectedLights.length + " / " + (pluginMain?.allLights?.length || 0) + " selected"
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
      }
    }

    NBox {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.min(lightsListView.contentHeight + Style.marginM * 2, 200 * Style.uiScaleRatio)
      visible: (pluginMain?.allLights?.length || 0) > 0

      ScrollView {
        anchors.fill: parent
        anchors.margins: Style.marginS
        clip: true

        ListView {
          id: lightsListView
          model: root.orderedLights
          spacing: Style.marginXS
          boundsBehavior: Flickable.StopAtBounds

          // Drop indicator line
          Rectangle {
            id: dropIndicator
            width: parent.width - Style.marginM * 2
            height: 2
            color: Color.mPrimary
            radius: 1
            visible: false
            z: 100
          }

          delegate: Item {
            id: lightCheckDelegate
            required property int index
            required property var modelData

            width: lightsListView.width
            height: delegateContent.height
            z: dragArea.drag.active ? 100 : 1

            readonly property bool isSelected: root.isLightSelected(modelData.entity_id)
            readonly property int selectionOrder: root.getSelectionOrder(modelData.entity_id)

            Rectangle {
              id: delegateContent
              width: parent.width
              height: checkRow.implicitHeight + Style.marginS * 2
              radius: Style.radiusS
              color: dragArea.drag.active ? Color.mPrimaryContainer : (checkMouseArea.containsMouse ? Color.mHover : Color.transparent)
              border.width: dragArea.drag.active ? 2 : 0
              border.color: Color.mPrimary

              Drag.active: dragArea.drag.active
              Drag.source: lightCheckDelegate
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
                id: checkMouseArea
                anchors.left: parent.left
                anchors.right: dragHandle.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                hoverEnabled: true
                onClicked: root.toggleLightSelection(modelData.entity_id)
              }

              RowLayout {
                id: checkRow
                anchors.left: parent.left
                anchors.right: dragHandle.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.marginS
                spacing: Style.marginM

                CheckBox {
                  checked: lightCheckDelegate.isSelected
                  onClicked: root.toggleLightSelection(modelData.entity_id)
                }

                // Order number badge
                Rectangle {
                  width: Style.fontSizeL
                  height: Style.fontSizeL
                  radius: Style.fontSizeL / 2
                  color: Color.mPrimary
                  visible: lightCheckDelegate.isSelected

                  NText {
                    anchors.centerIn: parent
                    text: lightCheckDelegate.selectionOrder
                    pointSize: Style.fontSizeXS
                    color: Color.mOnPrimary
                    font.weight: Style.fontWeightBold
                  }
                }

                NIcon {
                  icon: "bulb"
                  pointSize: Style.fontSizeL
                  color: lightCheckDelegate.isSelected ? Color.mPrimary : Color.mOnSurfaceVariant
                  visible: !lightCheckDelegate.isSelected
                }

                NText {
                  Layout.fillWidth: true
                  text: modelData.friendly_name || modelData.entity_id
                  color: lightCheckDelegate.isSelected ? Color.mOnSurface : Color.mOnSurfaceVariant
                  elide: Text.ElideRight
                }
              }

              // Drag handle (only for selected items)
              Rectangle {
                id: dragHandle
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: lightCheckDelegate.isSelected ? Style.fontSizeXL * 1.5 : 0
                visible: lightCheckDelegate.isSelected
                color: "transparent"

                NIcon {
                  anchors.centerIn: parent
                  icon: "grip-vertical"
                  pointSize: Style.fontSizeM
                  color: dragArea.containsMouse ? Color.mPrimary : Color.mOnSurfaceVariant
                }

                MouseArea {
                  id: dragArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.SizeAllCursor
                  enabled: lightCheckDelegate.isSelected
                  drag.target: lightCheckDelegate.isSelected ? delegateContent : null
                  drag.axis: Drag.YAxis

                  onPressed: {
                    if (lightCheckDelegate.isSelected) {
                      root.dragFromIndex = lightCheckDelegate.selectionOrder - 1;
                    }
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
                enabled: lightCheckDelegate.isSelected

                onEntered: drag => {
                  const sourceDelegate = drag.source;
                  if (sourceDelegate && sourceDelegate !== lightCheckDelegate && lightCheckDelegate.isSelected) {
                    root.dragToIndex = lightCheckDelegate.selectionOrder - 1;
                    dropIndicator.visible = true;
                    dropIndicator.y = lightCheckDelegate.y;
                  }
                }

                onPositionChanged: drag => {
                  const sourceDelegate = drag.source;
                  if (sourceDelegate && sourceDelegate !== lightCheckDelegate && lightCheckDelegate.isSelected) {
                    const dropAtTop = drag.y < delegateContent.height / 2;
                    const selectedCount = root.valueSelectedLights.length;
                    if (dropAtTop) {
                      root.dragToIndex = lightCheckDelegate.selectionOrder - 1;
                      dropIndicator.y = lightCheckDelegate.y;
                    } else {
                      root.dragToIndex = Math.min(lightCheckDelegate.selectionOrder, selectedCount - 1);
                      dropIndicator.y = lightCheckDelegate.y + delegateContent.height + Style.marginXS;
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

    NText {
      visible: (pluginMain?.allLights?.length || 0) === 0
      text: pluginApi?.tr("settings.no-lights-connect") || "Connect to Home Assistant to see available lights."
      color: Color.mOnSurfaceVariant
      pointSize: Style.fontSizeS
    }
  }
}
