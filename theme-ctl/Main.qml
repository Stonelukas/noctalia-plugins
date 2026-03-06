import QtQuick
import Quickshell
import Quickshell.Io
import "ColorsConvert.js" as ColorsConvert
import "ThemePipeline.js" as ThemePipeline
import "SchemeCache.js" as SchemeCache
import qs.Commons
import qs.Services.Theming
import qs.Services.UI

Item {
  id: root

  visible: false

  property var pluginApi: null

  property bool available: false
  property bool applying: false
  property string themeName: ""
  property var availableThemes: []
  property bool suppressSettingsSignal: false
  property var pendingColors: null

  readonly property var defaultSettings: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string schemeDisplayName: pluginApi?.manifest?.metadata?.schemeName || "ThemeCtl"
  readonly property string schemeFolder: {
    const baseDir = ColorSchemeService.downloadedSchemesDirectory || (Settings.configDir + "colorschemes");
    const normalizedBase = baseDir.endsWith("/") ? baseDir.slice(0, -1) : baseDir;
    const pluginId = pluginApi?.pluginId || "theme-ctl";
    return normalizedBase + "/" + pluginId;
  }
  readonly property string schemeOutputPath: schemeFolder + "/" + schemeDisplayName + ".json"
  readonly property string schemeOutputDir: schemeFolder
  readonly property string previousWallpaperKey: "_prevUseWallpaperColors"
  readonly property string previousSchemeKey: "_prevPredefinedScheme"

  // ── theme-ctl cache paths ─────────────────────────────────────────────────
  readonly property string cacheDir: {
    const home = Quickshell.env("HOME") || "~";
    return home + "/.cache/theme-ctl/";
  }
  readonly property string colorsTomlPath: cacheDir + "colors.toml"
  readonly property string themeNamePath: cacheDir + "current-theme"

  // ── helpers ───────────────────────────────────────────────────────────────
  function mutatePluginSettings(mutator) {
    if (!pluginApi)
      return null;
    var settings = pluginApi.pluginSettings || {};
    mutator(settings);
    suppressSettingsSignal = true;
    pluginApi.pluginSettings = settings;
    suppressSettingsSignal = false;
    return settings;
  }

  function rememberColorPreferences() {
    if (!pluginApi)
      return false;
    var settings = pluginApi.pluginSettings || {};
    if (settings[previousWallpaperKey] !== undefined)
      return false;
    mutatePluginSettings(s => {
      s[previousWallpaperKey] = Settings.data.colorSchemes.useWallpaperColors;
      s[previousSchemeKey] = Settings.data.colorSchemes.predefinedScheme || "";
    });
    return true;
  }

  function restoreColorPreferences() {
    if (!pluginApi)
      return false;
    var settings = pluginApi.pluginSettings || {};
    if (settings[previousWallpaperKey] === undefined)
      return false;
    var prevWallpaper = settings[previousWallpaperKey];
    var prevScheme = settings[previousSchemeKey] || "";
    mutatePluginSettings(s => {
      delete s[previousWallpaperKey];
      delete s[previousSchemeKey];
    });
    Settings.data.colorSchemes.useWallpaperColors = prevWallpaper;
    Settings.data.colorSchemes.predefinedScheme = prevScheme || Settings.data.colorSchemes.predefinedScheme;
    if (prevWallpaper) {
      AppThemeService.generate();
    } else if (Settings.data.colorSchemes.predefinedScheme) {
      ColorSchemeService.applyScheme(Settings.data.colorSchemes.predefinedScheme);
    }
    return true;
  }

  // ── public API ────────────────────────────────────────────────────────────
  function refresh() {
    checkAvailability();
    refreshThemeName();
    scanThemes();
  }

  function scanThemes() {
    // Strip section headers (── ... ──), blank lines, and the "current:" footer
    themesProcess.command = ["sh", "-c", "theme-ctl list 2>/dev/null | grep -v '^[[:space:]]*$' | grep -v '^──' | grep -v '^[[:space:]]*current:' | sort"];
    themesProcess.running = true;
  }

  function setTheme(name) {
    if (!name) return;
    themeSetProcess.command = ["sh", "-c", "theme-ctl set '" + name.replace(/'/g, "'\\''") + "'"];
    themeSetProcess.running = true;
  }

  function checkAvailability() {
    const p = colorsTomlPath.replace(/'/g, "'\\''");
    availabilityProcess.command = ["sh", "-c", "[ -f '" + p + "' ] && echo ok || exit 1"];
    availabilityProcess.running = true;
  }

  function refreshThemeName() {
    const p = themeNamePath.replace(/'/g, "'\\''");
    themeNameProcess.command = ["sh", "-c", "cat '" + p + "' 2>/dev/null | tr -d '\\n' || true"];
    themeNameProcess.running = true;
  }

  function activate() {
    if (!pluginApi)
      return false;
    rememberColorPreferences();
    mutatePluginSettings(s => s.active = true);
    pluginApi.saveSettings();
    return applyCurrentTheme();
  }

  function deactivate() {
    if (!pluginApi)
      return;
    mutatePluginSettings(s => s.active = false);
    restoreColorPreferences();
    pluginApi.saveSettings();
  }

  function applyCurrentTheme() {
    if (!available) {
      ToastService.showError(
        pluginApi?.tr("title") || "Theme-ctl",
        "theme-ctl cache not found — run 'theme-ctl set <name>' first"
      );
      return false;
    }

    if (rememberColorPreferences()) {
      pluginApi.saveSettings();
    }
    Settings.data.colorSchemes.useWallpaperColors = false;
    applying = true;

    // Fast path: pre-computed scheme cache
    const cacheCompatible = SchemeCache.isCompatible(ThemePipeline.PIPELINE_VERSION);
    if (themeName && cacheCompatible) {
      const cached = SchemeCache.getScheme(themeName);
      if (cached?.palette && cached?.mode) {
        Logger.i("ThemeCtl", "Cache hit for:", themeName);
        const isDarkMode = cached.mode === "dark";
        if (Settings.data.colorSchemes.darkMode !== isDarkMode) {
          Settings.data.colorSchemes.darkMode = isDarkMode;
        }
        writeSchemeFile(cached);
        return true;
      }
    }

    // Slow path: read colors.toml and generate live
    Logger.i("ThemeCtl", "Cache miss for:", themeName, "— live conversion");
    colorsReadProcess.command = ["cat", colorsTomlPath];
    colorsReadProcess.running = true;
    return true;
  }

  // ── color parsing ─────────────────────────────────────────────────────────
  function parseColorsToml(content) {
    function extractColor(line) {
      const m = line.match(/=\s*["'](?:#|0x)?([a-fA-F0-9]{6,8})["']/);
      if (m) return "#" + m[1].toLowerCase().slice(-6);
      return null;
    }
    const colors = {};
    for (const line of content.split("\n")) {
      const t = line.trim();
      if (!t || t.startsWith("#") || t.startsWith("[")) continue;
      const color = extractColor(t);
      if (color) {
        const km = t.match(/^([a-zA-Z0-9_]+)\s*=/);
        if (km) colors[km[1]] = color;
      }
    }
    if (!colors.background || !colors.foreground) return null;
    return colors;
  }

  // ── scheme output ─────────────────────────────────────────────────────────
  function writeSchemeFile(result) {
    const mode = result?.mode;
    const scheme = result?.palette;
    if (!scheme || !mode) {
      Logger.e("ThemeCtl", "writeSchemeFile: missing scheme/mode");
      applying = false;
      return;
    }
    const wrapped = { "dark": scheme, "light": scheme };
    const json = JSON.stringify(wrapped, null, 2);
    const dirEsc = schemeOutputDir.replace(/'/g, "'\\''");
    const outEsc = schemeOutputPath.replace(/'/g, "'\\''");
    const cmd = "mkdir -p '" + dirEsc + "' && printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + outEsc + "'";
    schemeWriteProcess.command = ["sh", "-c", cmd];
    schemeWriteProcess.running = true;
  }

  // ── processes ─────────────────────────────────────────────────────────────
  Process {
    id: availabilityProcess
    running: false
    onExited: code => { available = (code === 0); }
  }

  Process {
    id: themeNameProcess
    running: false
    stdout: StdioCollector {}
    onExited: function() {
      const name = (stdout.text || "").trim();
      themeName = name;
    }
  }

  Process {
    id: colorsReadProcess
    running: false
    stdout: StdioCollector {}
    onExited: function(code) {
      if (code !== 0) {
        applying = false;
        ToastService.showError(pluginApi?.tr("title") || "Theme-ctl", "Failed to read colors.toml");
        return;
      }
      const parsed = parseColorsToml(stdout.text || "");
      if (!parsed) {
        applying = false;
        ToastService.showError(pluginApi?.tr("title") || "Theme-ctl", "Failed to parse colors.toml");
        return;
      }
      const schemeResult = ThemePipeline.generateScheme(parsed, ColorsConvert);
      const isDarkMode = schemeResult.mode === "dark";
      if (Settings.data.colorSchemes.darkMode !== isDarkMode) {
        Settings.data.colorSchemes.darkMode = isDarkMode;
      }
      writeSchemeFile(schemeResult);
    }
  }

  Process {
    id: schemeWriteProcess
    running: false
    onExited: function(code) {
      applying = false;
      if (code !== 0) {
        Logger.e("ThemeCtl", "Failed to write scheme file");
        ToastService.showError(pluginApi?.tr("title") || "Theme-ctl", "Failed to apply scheme");
        return;
      }
      Logger.i("ThemeCtl", "Scheme written to:", schemeOutputPath);
      applyDelayTimer.start();
    }
  }

  Process {
    id: themesProcess
    running: false
    stdout: StdioCollector {}
    onExited: function(code) {
      if (code !== 0) { availableThemes = []; return; }
      const names = (stdout.text || "").trim().split("\n").filter(n => n.trim());
      availableThemes = names.map(n => ({ "name": n, "colors": [] }));
    }
  }

  Process {
    id: themeSetProcess
    running: false
    onExited: function(code) {
      if (code !== 0) {
        ToastService.showError(pluginApi?.tr("title") || "Theme-ctl", "Failed to switch theme");
        return;
      }
      refreshThemeName();
      if (pluginApi?.pluginSettings?.active) Qt.callLater(applyCurrentTheme);
    }
  }

  // ── file watcher: auto-apply when theme-ctl writes new colors.toml ────────
  FileView {
    id: colorsWatcher
    path: root.colorsTomlPath
    // Reload whenever the file changes on disk
    onPathChanged: root.available = false
  }

  // Poll the file every 500ms to detect changes (FileView doesn't have onChange)
  Timer {
    id: watchTimer
    interval: 500
    repeat: true
    running: pluginApi?.pluginSettings?.active || false
    property string lastMtime: ""
    onTriggered: {
      mtimeProcess.command = ["sh", "-c", "stat -c %Y '" + root.colorsTomlPath.replace(/'/g, "'\\''") + "' 2>/dev/null || echo 0"];
      mtimeProcess.running = true;
    }
  }

  Process {
    id: mtimeProcess
    running: false
    stdout: StdioCollector {}
    onExited: function() {
      const mtime = (stdout.text || "").trim();
      if (mtime && mtime !== watchTimer.lastMtime && watchTimer.lastMtime !== "") {
        Logger.i("ThemeCtl", "colors.toml changed, re-applying");
        watchTimer.lastMtime = mtime;
        root.refreshThemeName();
        if (pluginApi?.pluginSettings?.active) {
          Qt.callLater(root.applyCurrentTheme);
        }
      } else if (watchTimer.lastMtime === "") {
        watchTimer.lastMtime = mtime;
      }
    }
  }

  Timer {
    id: applyDelayTimer
    interval: 100
    repeat: false
    onTriggered: {
      ColorSchemeService.loadColorSchemes();
      ColorSchemeService.applyScheme(schemeOutputPath);
      Settings.data.colorSchemes.useWallpaperColors = false;
      if (Settings.data.colorSchemes.predefinedScheme !== schemeDisplayName) {
        Settings.data.colorSchemes.predefinedScheme = schemeDisplayName;
      }
    }
  }

  // ── IPC ───────────────────────────────────────────────────────────────────
  IpcHandler {
    target: "theme-ctl"

    function reload() {
      root.refresh();
      if (pluginApi?.pluginSettings?.active) {
        Qt.callLater(root.applyCurrentTheme);
      }
    }

    function toggle() {
      if (pluginApi?.pluginSettings?.active) {
        root.deactivate();
      } else {
        root.activate();
      }
    }
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────
  Component.onCompleted: {
    refresh();
    if (pluginApi?.pluginSettings?.active) {
      Qt.callLater(applyCurrentTheme);
    }
  }

  Connections {
    target: pluginApi
    function onPluginSettingsChanged() {
      if (root.suppressSettingsSignal) return;
      if (pluginApi?.pluginSettings?.active) {
        Qt.callLater(applyCurrentTheme);
      }
    }
  }
}
