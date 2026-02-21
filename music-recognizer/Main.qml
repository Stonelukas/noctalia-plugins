import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  // State: "idle" | "listening" | "processing" | "success" | "error"
  property string state: "idle"
  property string errorMessage: ""
  property string errorCode: ""

  // Last recognized song (for brief display in bar)
  property var lastSong: null

  // History stored in memory, synced to file
  property var history: []

  // Settings with defaults (bounds checked)
  readonly property int recordDuration: Math.max(1, Math.min(pluginApi?.pluginSettings?.recordDurationSecs ?? 5, 60))
  readonly property int historyLimit: pluginApi?.pluginSettings?.historyLimit ?? 50
  readonly property bool showNotifications: pluginApi?.pluginSettings?.showNotifications ?? true
  readonly property int resetDelay: (pluginApi?.pluginSettings?.resetDelaySecs ?? 5) * 1000

  // Paths
  readonly property string scriptPath: pluginApi?.pluginDir
    ? pluginApi.pluginDir + "/scripts/recognize.py"
    : ""
  readonly property string venvPython: Quickshell.env("HOME") + "/.local/share/noctalia/plugins/music-recognizer/venv/bin/python"
  readonly property string historyDir: Settings.configDir + "/plugins/music-recognizer"
  readonly property string historyPath: historyDir + "/history.json"

  Component.onCompleted: {
    // Initialize settings if pluginApi is available
    if (pluginApi) {
      var needsSave = false;
      if (pluginApi.pluginSettings.recordDurationSecs === undefined) {
        pluginApi.pluginSettings.recordDurationSecs = 5;
        needsSave = true;
      }
      if (pluginApi.pluginSettings.historyLimit === undefined) {
        pluginApi.pluginSettings.historyLimit = 50;
        needsSave = true;
      }
      if (pluginApi.pluginSettings.showNotifications === undefined) {
        pluginApi.pluginSettings.showNotifications = true;
        needsSave = true;
      }
      if (pluginApi.pluginSettings.resetDelaySecs === undefined) {
        pluginApi.pluginSettings.resetDelaySecs = 5;
        needsSave = true;
      }
      if (needsSave) {
        pluginApi.saveSettings();
      }
    }

    // Always load history (FileView preload handles initial, this is fallback)
    loadHistoryFromFile();
    Logger.i("MusicRecognizer", "Plugin loaded, history path: " + root.historyPath);
  }

  Component.onDestruction: {
    resetTimer.stop();
    listeningTimer.stop();
    if (recognizeProcess.running) {
      recognizeProcess.kill();
    }
  }

  // History file I/O
  function loadHistoryFromFile() {
    historyFileReader.reload();
  }

  function saveHistoryToFile() {
    writeHistoryFile(JSON.stringify(root.history, null, 2));
  }

  FileView {
    id: historyFileReader
    path: Qt.resolvedUrl("file://" + root.historyPath)
    preload: true

    onLoaded: {
      Logger.i("MusicRecognizer", "History loaded from: " + root.historyPath);
      var content = historyFileReader.text();
      if (content && content.trim() !== "") {
        try {
          root.history = JSON.parse(content);
        } catch (e) {
          Logger.e("MusicRecognizer", "Failed to parse history: " + e);
          root.history = [];
        }
      } else {
        root.history = [];
      }
    }
  }

  // Write history via Process (FileView is read-only)
  Process {
    id: historyFileWriter
    running: false
  }

  function writeHistoryFile(content) {
    // Escape single quotes for shell
    var escaped = content.replace(/'/g, "'\\''");
    historyFileWriter.command = ["sh", "-c", "mkdir -p '" + root.historyDir + "' && printf '%s' '" + escaped + "' > '" + root.historyPath + "'"];
    historyFileWriter.running = true;
  }


  // IPC for external control (e.g., keybind)
  IpcHandler {
    target: "plugin:music-recognizer"

    function recognize() {
      root.startRecognition();
    }

    function toggle() {
      if (pluginApi) {
        pluginApi.withCurrentScreen(screen => {
          pluginApi.togglePanel(screen);
        });
      }
    }
  }

  // Recognition process
  Process {
    id: recognizeProcess
    running: false

    command: ["sh", "-c", "'" + root.venvPython + "' '" + root.scriptPath + "' --duration " + root.recordDuration + " && echo"]

    stdout: SplitParser {
      onRead: data => {
        if (!data || data.trim() === "") return;

        try {
          var result = JSON.parse(data);
          root.handleResult(result);
        } catch (e) {
          Logger.e("MusicRecognizer", "Failed to parse output: " + e + " | data: " + data);
          root.handleError("parse_error", "Invalid response from recognition script");
        }
      }
    }

    onExited: (exitCode, exitStatus) => {
      // Only handle if recognition still in progress
      if (root.state === "listening" || root.state === "processing") {
        if (exitCode !== 0 || exitStatus === 1) { // 1 = CrashExit
          var statusMsg = exitStatus === 1 ? "crashed" : "exit " + exitCode;
          root.handleError("process_error", "Recognition process " + statusMsg);
        }
      }
    }
  }

  // Auto-reset timer (success/error -> idle)
  Timer {
    id: resetTimer
    interval: root.resetDelay
    repeat: false
    onTriggered: {
      if (root.state === "success" || root.state === "error") {
        root.state = "idle";
      }
    }
  }

  // Transition: listening -> processing (after record duration)
  Timer {
    id: listeningTimer
    interval: root.recordDuration * 1000
    repeat: false
    onTriggered: {
      if (root.state === "listening") {
        root.state = "processing";
      }
    }
  }

  // Public API
  function startRecognition() {
    if (root.state !== "idle") {
      Logger.w("MusicRecognizer", "Already in state: " + root.state);
      return;
    }

    if (!root.scriptPath) {
      handleError("config_error", "Plugin directory not found");
      return;
    }

    root.state = "listening";
    root.errorMessage = "";
    root.errorCode = "";
    listeningTimer.start();
    recognizeProcess.running = true;

    Logger.i("MusicRecognizer", "Started recognition (" + root.recordDuration + "s)");
  }

  function cancelRecognition() {
    if (recognizeProcess.running) {
      recognizeProcess.kill();
    }
    listeningTimer.stop();
    resetTimer.stop();
    root.state = "idle";
  }

  function handleResult(result) {
    listeningTimer.stop();

    if (result.status === "success") {
      root.lastSong = {
        title: result.title || "Unknown",
        artist: result.artist || "Unknown Artist",
        coverUrl: result.coverUrl || "",
        shazamUrl: result.shazamUrl || "",
        key: result.key || "",
        timestamp: new Date().toISOString()
      };

      root.addToHistory(root.lastSong);
      root.state = "success";

      if (root.showNotifications) {
        ToastService.showNotice(
          result.title,
          "by " + result.artist,
          "music"
        );
      }

      Logger.i("MusicRecognizer", "Recognized: " + result.title + " - " + result.artist);
      resetTimer.start();

    } else if (result.status === "no_match") {
      root.state = "idle";
      if (root.showNotifications) {
        ToastService.showNotice(
          pluginApi?.tr("toast.no_match.title") || "No Match",
          pluginApi?.tr("toast.no_match.message") || "Song not recognized",
          "music-off"
        );
      }
      Logger.i("MusicRecognizer", "No match found");

    } else if (result.status === "error") {
      handleError(result.error || "unknown", result.message || "Unknown error");
    }
  }

  function handleError(code, message) {
    listeningTimer.stop();
    root.state = "error";
    root.errorCode = code;
    root.errorMessage = message;

    if (root.showNotifications) {
      ToastService.showError(
        pluginApi?.tr("toast.error.title") || "Recognition Failed",
        message,
        "alert-circle"
      );
    }

    Logger.e("MusicRecognizer", "Error [" + code + "]: " + message);
    resetTimer.start();
  }

  function addToHistory(song) {
    // Check for duplicate (same title + artist within last 5 entries)
    var isDuplicate = root.history.slice(0, 5).some(function(s) {
      return s.title === song.title && s.artist === song.artist;
    });

    if (!isDuplicate) {
      root.history.unshift(song);

      // Trim to limit
      if (root.history.length > root.historyLimit) {
        root.history = root.history.slice(0, root.historyLimit);
      }

      saveHistoryToFile();
    }
  }

  function clearHistory() {
    root.history = [];
    saveHistoryToFile();
  }

  function removeFromHistory(index) {
    if (index >= 0 && index < root.history.length) {
      root.history.splice(index, 1);
      root.history = root.history.slice(); // Trigger binding update
      saveHistoryToFile();
    }
  }
}
