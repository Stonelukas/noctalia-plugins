import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var pluginApi: null

  // State
  property bool headsetConnected: false
  property string headsetName: "Arctis Nova Pro"
  property string deviceId: "1038:12e5"
  property var micSettings: ({})
  property string errorMessage: ""
  property double batteryLevel: -1
  property bool isCharging: false

  // ChatMix state (read from arctis-manager via pactl, controlled by physical dial)
  property int gameVolume: 100
  property int chatVolume: 100
  property bool gameMuted: false
  property bool chatMuted: false

  // Mic state
  property bool micMuted: false
  property int micVolume: 100

  // Settings
  readonly property int pollInterval: pluginApi?.pluginSettings?.pollIntervalMs || 30000
  readonly property bool showInBar: pluginApi?.pluginSettings?.showInBar ?? true
  readonly property bool showBatteryPercent: pluginApi?.pluginSettings?.showBatteryPercent ?? true
  readonly property int lowBatteryWarning: pluginApi?.pluginSettings?.lowBatteryWarning || 20

  // Computed
  readonly property bool hasHeadset: headsetConnected
  readonly property bool hasBattery: batteryLevel >= 0
  readonly property bool lowBattery: hasBattery && batteryLevel <= lowBatteryWarning
  readonly property int batteryPercent: hasBattery ? Math.round(batteryLevel) : -1

  Component.onCompleted: {
    Logger.i("Arctis", "Plugin loaded");
    loadMicSettings();
    loadAudioState();
    volumeMonitor.running = true;
  }

  Timer {
    id: pollTimer
    interval: root.pollInterval
    running: true
    repeat: true
    onTriggered: {
      root.loadMicSettings();
    }
  }

  // Debounce timer for volume updates
  Timer {
    id: volumeDebounce
    interval: 50
    onTriggered: root.loadAudioState()
  }

  // Real-time volume monitoring via pactl subscribe
  Process {
    id: volumeMonitor
    command: ["pactl", "subscribe"]
    
    stdout: SplitParser {
      onRead: data => {
        // Filter for sink events
        if (data.includes("sink") && data.includes("change")) {
          volumeDebounce.restart();
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      // Restart if it exits unexpectedly
      if (root.headsetConnected) {
        Logger.w("Arctis", "Volume monitor exited, restarting...");
        volumeMonitor.running = true;
      }
    }
  }

  function loadMicSettings() {
    micSettingsProcess.running = true;
  }

  function loadAudioState() {
    gameVolumeProcess.running = true;
    chatVolumeProcess.running = true;
    micStateProcess.running = true;
  }

  function checkHeadset() {
    loadMicSettings();
    loadAudioState();
  }

  function openSettings() {
    openSettingsProcess.running = true;
  }

  // Mute controls (volume is controlled by physical dial via arctis-manager)
  function setGameMuted(muted) {
    root.gameMuted = muted;
    gameMuteProcess.command = ["pactl", "set-sink-mute", "Arctis_Game", muted ? "1" : "0"];
    gameMuteProcess.running = true;
  }

  function setChatMuted(muted) {
    root.chatMuted = muted;
    chatMuteProcess.command = ["pactl", "set-sink-mute", "Arctis_Chat", muted ? "1" : "0"];
    chatMuteProcess.running = true;
  }

  function setMicMuted(muted) {
    root.micMuted = muted;
    micMuteProcess.command = ["pactl", "set-source-mute", "@DEFAULT_SOURCE@", muted ? "1" : "0"];
    micMuteProcess.running = true;
  }

  function toggleMicMute() {
    setMicMuted(!root.micMuted);
  }

  // Load mic settings from config - this also confirms headset exists
  // Note: Must use "sh -c" with echo to add trailing newline - SplitParser waits for newline
  Process {
    id: micSettingsProcess
    command: ["sh", "-c", "cat \"$HOME/.config/arctis_manager/device_1038_12e5.json\" && echo"]
    
    stdout: SplitParser {
      onRead: data => {
        try {
          const parsed = JSON.parse(data);
          root.micSettings = parsed;
          root.headsetConnected = true;
          Logger.i("Arctis", "Headset detected, mic settings loaded");
        } catch (e) {
          Logger.w("Arctis", "Failed to parse mic settings");
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        root.headsetConnected = false;
        root.micSettings = {};
      }
    }
  }

  // Open arctis-manager settings
  Process {
    id: openSettingsProcess
    command: ["qdbus", "name.giacomofurlan.ArctisManager", "/name/giacomofurlan/ArctisManager", "name.giacomofurlan.ArctisManager.ShowSettings"]
  }

  // Get Game sink volume
  Process {
    id: gameVolumeProcess
    command: ["sh", "-c", "pactl get-sink-volume Arctis_Game 2>/dev/null | grep -oP '\\d+(?=%)' | head -1 && echo"]
    
    stdout: SplitParser {
      onRead: data => {
        const vol = parseInt(data.trim());
        if (!isNaN(vol)) {
          root.gameVolume = vol;
        }
      }
    }
  }

  // Get Chat sink volume
  Process {
    id: chatVolumeProcess
    command: ["sh", "-c", "pactl get-sink-volume Arctis_Chat 2>/dev/null | grep -oP '\\d+(?=%)' | head -1 && echo"]
    
    stdout: SplitParser {
      onRead: data => {
        const vol = parseInt(data.trim());
        if (!isNaN(vol)) {
          root.chatVolume = vol;
        }
      }
    }
  }

  // Get mic mute state
  Process {
    id: micStateProcess
    command: ["sh", "-c", "pactl get-source-mute @DEFAULT_SOURCE@ 2>/dev/null && echo"]
    
    stdout: SplitParser {
      onRead: data => {
        root.micMuted = data.toLowerCase().includes("yes");
      }
    }
  }

  // Mute processes
  Process {
    id: gameMuteProcess
    command: []
  }

  Process {
    id: chatMuteProcess
    command: []
  }

  Process {
    id: micMuteProcess
    command: []
  }
}
