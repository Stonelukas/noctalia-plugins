import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  // State
  property var devices: []
  property string currentDevicePath: ""
  property string deviceName: ""
  property string deviceType: ""
  property double batteryLevel: -1
  property bool isCharging: false
  property double brightness: 0
  property int dpiX: 0
  property int dpiY: 0
  property int maxDpi: 0
  property string errorMessage: ""

  // Settings
  readonly property int pollInterval: pluginApi?.pluginSettings?.pollIntervalMs || 60000
  readonly property bool showBatteryPercent: pluginApi?.pluginSettings?.showBatteryPercent ?? true
  readonly property int lowBatteryWarning: pluginApi?.pluginSettings?.lowBatteryWarning || 20

  // Computed
  readonly property bool hasDevice: devices.length > 0
  readonly property bool hasBattery: batteryLevel >= 0
  readonly property bool lowBattery: hasBattery && batteryLevel <= lowBatteryWarning
  readonly property int batteryPercent: hasBattery ? Math.round(batteryLevel) : -1

  Component.onCompleted: {
    Logger.i("OpenRazer", "Plugin loaded");
    refreshDevices();
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: root.refreshStatus()
  }

  function refreshDevices() {
    devicesProcess.running = true;
  }

  function refreshStatus() {
    if (currentDevicePath) {
      batteryProcess.running = true;
      chargingProcess.running = true;
      brightnessProcess.running = true;
    }
  }

  function setBrightness(value) {
    setBrightnessProcess.command = ["qdbus", "org.razer", currentDevicePath, "razer.device.lighting.brightness.setBrightness", value.toString()];
    setBrightnessProcess.running = true;
  }

  // List devices
  Process {
    id: devicesProcess
    command: ["qdbus", "org.razer"]
    
    stdout: SplitParser {
      onRead: data => {
        const lines = data.trim().split("\n");
        const devicePaths = lines.filter(line => line.startsWith("/org/razer/device/"));
        root.devices = devicePaths;
        
        if (devicePaths.length > 0) {
          root.currentDevicePath = devicePaths[0];
          root.refreshDeviceInfo();
        } else {
          root.currentDevicePath = "";
          root.deviceName = "";
          root.deviceType = "";
          root.batteryLevel = -1;
        }
      }
    }
  }

  function refreshDeviceInfo() {
    if (currentDevicePath) {
      nameProcess.running = true;
      typeProcess.running = true;
      batteryProcess.running = true;
      chargingProcess.running = true;
      brightnessProcess.running = true;
      maxDpiProcess.running = true;
    }
  }

  // Get device name
  Process {
    id: nameProcess
    command: ["qdbus", "org.razer", root.currentDevicePath, "razer.device.misc.getDeviceName"]
    
    stdout: SplitParser {
      onRead: data => {
        root.deviceName = data.trim();
      }
    }
  }

  // Get device type
  Process {
    id: typeProcess
    command: ["qdbus", "org.razer", root.currentDevicePath, "razer.device.misc.getDeviceType"]
    
    stdout: SplitParser {
      onRead: data => {
        root.deviceType = data.trim();
      }
    }
  }

  // Get battery level
  Process {
    id: batteryProcess
    command: ["qdbus", "org.razer", root.currentDevicePath, "razer.device.power.getBattery"]
    
    stdout: SplitParser {
      onRead: data => {
        const level = parseFloat(data.trim());
        if (!isNaN(level)) {
          root.batteryLevel = level;
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        // Device might not have battery
        root.batteryLevel = -1;
      }
    }
  }

  // Get charging state
  Process {
    id: chargingProcess
    command: ["qdbus", "org.razer", root.currentDevicePath, "razer.device.power.isCharging"]
    
    stdout: SplitParser {
      onRead: data => {
        root.isCharging = data.trim() === "true";
      }
    }
  }

  // Get brightness
  Process {
    id: brightnessProcess
    command: ["qdbus", "org.razer", root.currentDevicePath, "razer.device.lighting.brightness.getBrightness"]
    
    stdout: SplitParser {
      onRead: data => {
        const val = parseFloat(data.trim());
        if (!isNaN(val)) {
          root.brightness = val;
        }
      }
    }
  }

  // Get max DPI
  Process {
    id: maxDpiProcess
    command: ["qdbus", "org.razer", root.currentDevicePath, "razer.device.dpi.maxDPI"]
    
    stdout: SplitParser {
      onRead: data => {
        const val = parseInt(data.trim());
        if (!isNaN(val)) {
          root.maxDpi = val;
        }
      }
    }
  }

  // Set brightness
  Process {
    id: setBrightnessProcess
    onExited: (exitCode, exitStatus) => {
      if (exitCode === 0) {
        root.refreshStatus();
      }
    }
  }

}
