import QtQuick
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  // Connection settings (from pluginSettings)
  readonly property string haUrl: pluginApi?.pluginSettings?.haUrl || ""
  readonly property string haToken: pluginApi?.pluginSettings?.haToken || ""
  readonly property string favoriteLight: pluginApi?.pluginSettings?.favoriteLight || ""
  readonly property var selectedLightsConfig: pluginApi?.pluginSettings?.selectedLights || []
  readonly property bool showOnlyOn: pluginApi?.pluginSettings?.showOnlyOn || false

  // Connection state
  property bool connected: false
  property bool connecting: false
  property string connectionError: ""

  // HTTP request tracking
  property int requestId: 0
  property var pendingRequests: ({})

  // Entity state
  property var allLights: []  // All discovered lights from HA
  property var lights: []     // Filtered lights to show in UI
  property string selectedLight: favoriteLight
  property var currentState: ({})
  property bool cacheHydrated: false
  property bool settingsReady: false

  // Filter lights based on selectedLightsConfig, preserving order
  readonly property var visibleLights: {
    if (!allLights || allLights.length === 0) return [];
    // If no lights are selected, show all lights
    if (!selectedLightsConfig || selectedLightsConfig.length === 0) return allLights;
    // Return selected lights in the saved order
    const result = [];
    for (const entityId of selectedLightsConfig) {
      const light = allLights.find(l => l.entity_id === entityId);
      if (light) result.push(light);
    }
    return result;
  }

  onVisibleLightsChanged: {
    lights = visibleLights;
  }

  // Computed properties for current light
  readonly property var selectedLightState: {
    if (!selectedLight || !currentState)
      return null;
    return currentState[selectedLight] || null;
  }

  readonly property string lightState: selectedLightState?.state || "unavailable"
  readonly property bool isOn: lightState === "on"
  readonly property bool isOff: lightState === "off"
  readonly property bool isUnavailable: lightState === "unavailable"

  readonly property string friendlyName: selectedLightState?.attributes?.friendly_name || selectedLight
  readonly property int brightness: selectedLightState?.attributes?.brightness || 0
  readonly property real brightnessPercent: Math.round((brightness / 255) * 100)
  readonly property var rgbColor: selectedLightState?.attributes?.rgb_color || null
  readonly property int colorTemp: selectedLightState?.attributes?.color_temp || 0
  readonly property int minMireds: selectedLightState?.attributes?.min_mireds || 153
  readonly property int maxMireds: selectedLightState?.attributes?.max_mireds || 500
  readonly property var supportedColorModes: selectedLightState?.attributes?.supported_color_modes || []
  readonly property string colorMode: selectedLightState?.attributes?.color_mode || "onoff"

  readonly property bool supportsBrightness: {
    const modes = supportedColorModes;
    return modes.includes("brightness") || modes.includes("color_temp") || 
           modes.includes("hs") || modes.includes("rgb") || 
           modes.includes("rgbw") || modes.includes("rgbww") || modes.includes("xy");
  }

  readonly property bool supportsColorTemp: {
    const modes = supportedColorModes;
    return modes.includes("color_temp");
  }

  readonly property bool supportsColor: {
    const modes = supportedColorModes;
    return modes.includes("hs") || modes.includes("rgb") || 
           modes.includes("rgbw") || modes.includes("rgbww") || modes.includes("xy");
  }

  // Count how many visible lights are on
  readonly property int lightsOnCount: {
    let count = 0;
    for (const light of visibleLights) {
      if (currentState[light.entity_id]?.state === "on") {
        count++;
      }
    }
    return count;
  }

  readonly property int totalLightsCount: visibleLights.length

  // Polling timer for state updates
  Timer {
    id: pollTimer
    interval: 10000  // Poll every 10 seconds (lights change less frequently)
    repeat: true
    running: connected
    onTriggered: fetchStates()
  }

  // Connection test timer
  Timer {
    id: reconnectTimer
    interval: 5000
    repeat: false
    onTriggered: {
      if (!connected && haUrl && haToken) {
        Logger.d("HomeAssistantLights", "Attempting reconnection...");
        testConnection();
      }
    }
  }

  function testConnection() {
    if (!haUrl || !haToken) {
      connected = false;
      connecting = false;
      connectionError = "No URL or token configured";
      return;
    }

    connecting = true;
    connectionError = "";

    const xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        connecting = false;
        if (xhr.status === 200) {
          connected = true;
          connectionError = "";
          Logger.d("HomeAssistantLights", "Connection test successful");
          fetchStates();
        } else if (xhr.status === 401) {
          connected = false;
          connectionError = pluginApi?.tr("errors.auth-invalid") || "Invalid access token";
          Logger.e("HomeAssistantLights", "Authentication failed");
        } else {
          connected = false;
          connectionError = "Connection failed: " + xhr.status;
          Logger.e("HomeAssistantLights", "Connection test failed:", xhr.status);
          reconnectTimer.start();
        }
      }
    };

    xhr.onerror = function () {
      connecting = false;
      connected = false;
      connectionError = "Connection error";
      Logger.e("HomeAssistantLights", "Connection test error");
      reconnectTimer.start();
    };

    xhr.open("GET", haUrl + "/api/");
    xhr.setRequestHeader("Authorization", "Bearer " + haToken);
    xhr.timeout = 10000;
    xhr.send();
  }

  function sendHttpRequest(method, endpoint, data, callback) {
    if (!connected) {
      Logger.w("HomeAssistantLights", "Cannot send request, not connected");
      return -1;
    }

    requestId++;
    const xhr = new XMLHttpRequest();
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        try {
          const response = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
          if (callback)
            callback(xhr.status, response);
        } catch (e) {
          Logger.e("HomeAssistantLights", "Failed to parse response:", e);
          if (callback)
            callback(xhr.status, null);
        }
      }
    };

    xhr.onerror = function () {
      Logger.e("HomeAssistantLights", "HTTP request error for", endpoint);
      if (callback)
        callback(0, null);
    };

    const url = haUrl + endpoint;
    xhr.open(method, url);
    xhr.setRequestHeader("Authorization", "Bearer " + haToken);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.timeout = 10000;

    if (data) {
      xhr.send(JSON.stringify(data));
    } else {
      xhr.send();
    }

    return requestId;
  }

  function fetchStates() {
    Logger.d("HomeAssistantLights", "Fetching states...");
    sendHttpRequest("GET", "/api/states", null, function (status, response) {
      if (status === 200 && response) {
        Logger.d("HomeAssistantLights", "States fetched successfully, processing", response.length, "entities");
        processStates(response);
      } else {
        Logger.w("HomeAssistantLights", "Failed to fetch states:", status);
      }
    });
  }

  function processStates(states) {
    const newState = {};
    const lightsList = [];

    for (const entity of states) {
      if (entity.entity_id.startsWith("light.")) {
        newState[entity.entity_id] = entity;
        lightsList.push({
          entity_id: entity.entity_id,
          friendly_name: entity.attributes?.friendly_name || entity.entity_id,
          state: entity.state,
          brightness: entity.attributes?.brightness || 0
        });
      }
    }

    currentState = newState;
    allLights = lightsList;
    lights = visibleLights;

    Logger.d("HomeAssistantLights", "Processed", lightsList.length, "lights,", visibleLights.length, "visible,", lightsOnCount, "are on");

    // Auto-select first visible light if none selected
    if (!selectedLight && visibleLights.length > 0) {
      selectedLight = favoriteLight || visibleLights[0].entity_id;
    }

    saveCachedState();
  }

  function callService(domain, service, entityId, serviceData) {
    const data = Object.assign({
      entity_id: entityId
    }, serviceData || {});
    const endpoint = `/api/services/${domain}/${service}`;

    sendHttpRequest("POST", endpoint, data, function (status, response) {
      if (status !== 200) {
        Logger.e("HomeAssistantLights", "Service call failed:", domain, service, status);
        ToastService.show(pluginApi?.tr("errors.service-failed") || "Service call failed", "error");
      } else {
        Logger.d("HomeAssistantLights", "Service call successful:", domain, service);
        // Refresh states after service call
        Qt.callLater(fetchStates);
      }
    });
  }

  // Light control functions
  function turnOn(entityId) {
    const target = entityId || selectedLight;
    if (!target) return;
    callService("light", "turn_on", target);
    updateLightState(target, "on");
  }

  function turnOff(entityId) {
    const target = entityId || selectedLight;
    if (!target) return;
    callService("light", "turn_off", target);
    updateLightState(target, "off");
  }

  function toggle(entityId) {
    const target = entityId || selectedLight;
    if (!target) return;
    callService("light", "toggle", target);
    const current = currentState[target];
    updateLightState(target, current?.state === "on" ? "off" : "on");
  }

  function setBrightness(entityId, brightnessValue) {
    const target = entityId || selectedLight;
    if (!target) return;
    // Convert percentage (0-100) to HA brightness (0-255)
    const haBrightness = Math.round((brightnessValue / 100) * 255);
    callService("light", "turn_on", target, { brightness: haBrightness });
    updateLightAttribute(target, "brightness", haBrightness);
  }

  function setColorTemp(entityId, mireds) {
    const target = entityId || selectedLight;
    if (!target) return;
    callService("light", "turn_on", target, { color_temp: mireds });
    updateLightAttribute(target, "color_temp", mireds);
  }

  function setRgbColor(entityId, r, g, b) {
    const target = entityId || selectedLight;
    if (!target) return;
    callService("light", "turn_on", target, { rgb_color: [r, g, b] });
    updateLightAttribute(target, "rgb_color", [r, g, b]);
  }

  function turnAllOn() {
    for (const light of visibleLights) {
      if (currentState[light.entity_id]?.state !== "on") {
        turnOn(light.entity_id);
      }
    }
  }

  function turnAllOff() {
    for (const light of visibleLights) {
      if (currentState[light.entity_id]?.state === "on") {
        turnOff(light.entity_id);
      }
    }
  }

  function updateLightState(entityId, newState) {
    if (!entityId || !currentState) return;
    const lightState = currentState[entityId];
    if (!lightState) return;

    const updated = Object.assign({}, currentState);
    updated[entityId] = Object.assign({}, lightState, { state: newState });
    currentState = updated;
    saveCachedState();
  }

  function updateLightAttribute(entityId, attrName, value) {
    if (!entityId || !currentState) return;
    const lightState = currentState[entityId];
    if (!lightState) return;

    const updated = Object.assign({}, currentState);
    const updatedLight = Object.assign({}, lightState);
    updatedLight.attributes = Object.assign({}, lightState.attributes || {});
    updatedLight.attributes[attrName] = value;
    updated[entityId] = updatedLight;
    currentState = updated;
    saveCachedState();
  }

  function selectLight(entityId) {
    selectedLight = entityId;
    saveCachedState();
  }

  function disconnect() {
    connected = false;
    connecting = false;
    pollTimer.stop();
  }

  function reconnect() {
    disconnect();
    Qt.callLater(() => {
      testConnection();
    });
  }

  function refresh() {
    if (connected) {
      fetchStates();
    } else {
      reconnect();
    }
  }

  function loadCachedStateIfAvailable() {
    if (cacheHydrated) return;
    if (!pluginApi || !pluginApi.pluginSettings) return;
    settingsReady = true;
    const cache = pluginApi.pluginSettings.stateCache;
    if (cache) {
      if (cache.currentState) currentState = cache.currentState;
      if (cache.allLights) allLights = cache.allLights;
      if (cache.selectedLight) selectedLight = cache.selectedLight;
      lights = visibleLights;
      Logger.d("HomeAssistantLights", "Loaded cached light state from settings");
    }
    cacheHydrated = true;
  }

  function saveCachedState() {
    if (!settingsReady || !pluginApi) return;
    if (!pluginApi.pluginSettings) {
      pluginApi.pluginSettings = {};
    }
    pluginApi.pluginSettings.stateCache = {
      currentState: currentState,
      allLights: allLights,
      selectedLight: selectedLight,
      timestamp: Date.now()
    };
    pluginApi.saveSettings();
  }

  // Auto-connect when URL/token are configured
  onHaUrlChanged: {
    if (haUrl && haToken) {
      testConnection();
    } else {
      disconnect();
    }
  }

  onHaTokenChanged: {
    if (haUrl && haToken) {
      testConnection();
    } else {
      disconnect();
    }
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      loadCachedStateIfAvailable();
    }
  }

  Component.onCompleted: {
    loadCachedStateIfAvailable();
    if (haUrl && haToken) {
      testConnection();
    }
  }
}
