import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  // State
  property var devices: []
  property var currentDevice: null
  property int batteryLevel: -1
  property bool isCharging: false
  property bool deviceReachable: false
  property string deviceName: ""
  property string errorMessage: ""

  // Settings
  readonly property int pollInterval: pluginApi?.pluginSettings?.pollIntervalMs || 30000
  readonly property string preferredDevice: pluginApi?.pluginSettings?.preferredDevice || ""
  readonly property int lowBatteryWarning: pluginApi?.pluginSettings?.lowBatteryWarning || 20

  // Computed
  readonly property bool hasDevice: currentDevice !== null && deviceReachable
  readonly property bool lowBattery: batteryLevel > 0 && batteryLevel <= lowBatteryWarning

  Component.onCompleted: {
    Logger.i("KDEConnect", "Plugin loaded");
    refreshDevices();
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: root.refreshBattery()
  }

  function refreshDevices() {
    devicesProcess.running = true;
  }

  function refreshBattery() {
    if (currentDevice) {
      batteryProcess.running = true;
    }
  }

  function pingDevice() {
    if (currentDevice) {
      pingProcess.running = true;
    }
  }

  function ringDevice() {
    if (currentDevice) {
      ringProcess.running = true;
    }
  }

  // List devices
  Process {
    id: devicesProcess
    command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect", "org.kde.kdeconnect.daemon.devices"]
    
    stdout: SplitParser {
      onRead: data => {
        const deviceIds = data.trim().split("\n").filter(id => id.length > 0);
        root.devices = deviceIds;
        
        if (deviceIds.length > 0) {
          // Use preferred device or first one
          const deviceId = root.preferredDevice && deviceIds.includes(root.preferredDevice) 
            ? root.preferredDevice 
            : deviceIds[0];
          root.currentDevice = deviceId;
          root.refreshDeviceInfo();
        } else {
          root.currentDevice = null;
          root.deviceName = "";
          root.batteryLevel = -1;
        }
      }
    }
  }

  function refreshDeviceInfo() {
    if (currentDevice) {
      nameProcess.running = true;
      reachableProcess.running = true;
      batteryProcess.running = true;
      chargingProcess.running = true;
    }
  }

  // Get device name
  Process {
    id: nameProcess
    command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + (root.currentDevice || ""), "org.kde.kdeconnect.device.name"]
    
    stdout: SplitParser {
      onRead: data => {
        root.deviceName = data.trim();
      }
    }
  }

  // Check reachable
  Process {
    id: reachableProcess
    command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + (root.currentDevice || ""), "org.kde.kdeconnect.device.isReachable"]
    
    stdout: SplitParser {
      onRead: data => {
        root.deviceReachable = data.trim() === "true";
      }
    }
  }

  // Get battery level
  Process {
    id: batteryProcess
    command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + (root.currentDevice || "") + "/battery", "org.kde.kdeconnect.device.battery.charge"]
    
    stdout: SplitParser {
      onRead: data => {
        const level = parseInt(data.trim());
        if (!isNaN(level)) {
          root.batteryLevel = level;
        }
      }
    }
  }

  // Get charging state
  Process {
    id: chargingProcess
    command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + (root.currentDevice || "") + "/battery", "org.kde.kdeconnect.device.battery.isCharging"]
    
    stdout: SplitParser {
      onRead: data => {
        root.isCharging = data.trim() === "true";
      }
    }
  }

  // Ping device
  Process {
    id: pingProcess
    command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + (root.currentDevice || "") + "/ping", "org.kde.kdeconnect.device.ping.sendPing"]
  }

  // Ring device
  Process {
    id: ringProcess
    command: ["qdbus", "org.kde.kdeconnect", "/modules/kdeconnect/devices/" + (root.currentDevice || "") + "/findmyphone", "org.kde.kdeconnect.device.findmyphone.ring"]
  }
}
