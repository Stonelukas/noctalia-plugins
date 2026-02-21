import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Services.Compositor

Item {
  id: root

  property var pluginApi: null

  // ═══════════════════════════════════════════════════════════════
  // HYPRLAND STATE - Direct access for ScreencopyView
  // ═══════════════════════════════════════════════════════════════

  // Active toplevel (HyprlandToplevel object)
  // This provides .wayland property needed for ScreencopyView.captureSource
  readonly property var activeToplevel: {
    if (!CompositorService.isHyprland) return null;
    const toplevel = Hyprland.activeToplevel;
    // Only return if it has an activated wayland surface
    return (toplevel?.wayland?.activated) ? toplevel : null;
  }

  // Convenience: is there an active window?
  readonly property bool hasActiveWindow: activeToplevel !== null

  // ═══════════════════════════════════════════════════════════════
  // WINDOW DATA - Extracted from lastIpcObject
  // ═══════════════════════════════════════════════════════════════

  readonly property var windowData: {
    if (!activeToplevel) return createEmptyWindowData();

    const ipc = activeToplevel.lastIpcObject || {};
    const ws = activeToplevel.workspace;
    const mon = activeToplevel.monitor;

    return {
      // Identity
      address: activeToplevel.address || "",
      title: activeToplevel.title || "",
      appId: getAppId(activeToplevel),

      // From IPC object
      initialTitle: ipc.initialTitle || "",
      initialClass: ipc.initialClass || "",
      pid: ipc.pid || -1,

      // Position & Size
      x: Array.isArray(ipc.at) ? ipc.at[0] : 0,
      y: Array.isArray(ipc.at) ? ipc.at[1] : 0,
      width: Array.isArray(ipc.size) ? ipc.size[0] : 0,
      height: Array.isArray(ipc.size) ? ipc.size[1] : 0,

      // Workspace
      workspaceId: ws?.id ?? -1,
      workspaceName: ws?.name || "",

      // Monitor
      monitorId: mon?.id ?? -1,
      monitorName: mon?.name || "",
      monitorX: mon?.x ?? 0,
      monitorY: mon?.y ?? 0,

      // Flags
      floating: ipc.floating === true,
      pinned: ipc.pinned === true,
      fullscreen: ipc.fullscreen || 0,
      xwayland: ipc.xwayland === true,

      // Tags
      tags: ipc.tags || [],
      grouped: ipc.grouped || []
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // WORKSPACES - Direct from Hyprland API
  // ═══════════════════════════════════════════════════════════════

  // All workspaces from Hyprland
  readonly property var allWorkspaces: Hyprland.workspaces.values

  // Special workspaces (negative IDs, names start with "special:")
  readonly property var specialWorkspaces: {
    if (!allWorkspaces) return [];
    return allWorkspaces.filter(ws => ws.id < 0 || (ws.name && ws.name.startsWith("special:")));
  }

  // Regular workspaces (positive IDs)
  readonly property var regularWorkspaces: {
    if (!allWorkspaces) return [];
    return allWorkspaces.filter(ws => ws.id > 0 && (!ws.name || !ws.name.startsWith("special:")));
  }

  // ═══════════════════════════════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════════════════════════════

  readonly property bool showIcon: pluginApi?.pluginSettings?.showIcon ?? true
  readonly property int maxWidth: pluginApi?.pluginSettings?.maxWidth ?? 200
  readonly property string scrollingMode: pluginApi?.pluginSettings?.scrollingMode ?? "hover"
  readonly property bool hideWhenNoWindow: pluginApi?.pluginSettings?.hideWhenNoWindow ?? true
  readonly property bool showPreview: pluginApi?.pluginSettings?.showPreview ?? true
  readonly property bool showActions: pluginApi?.pluginSettings?.showActions ?? true
  readonly property int previewHeight: pluginApi?.pluginSettings?.previewHeight ?? 280

  // ═══════════════════════════════════════════════════════════════
  // ACTIONS - Hyprland dispatch commands
  // ═══════════════════════════════════════════════════════════════

  function moveToWorkspace(workspace) {
    if (!activeToplevel?.address) return;
    // workspace can be a number (1-10) or a string (special:name)
    Hyprland.dispatch(`movetoworkspace ${workspace},address:0x${activeToplevel.address}`);
    Logger.i("WindowInspector", `Moved window to workspace ${workspace}`);
  }

  function moveToSpecialWorkspace(name) {
    if (!activeToplevel?.address) return;
    // name should be the full "special:name" format
    Hyprland.dispatch(`movetoworkspace ${name},address:0x${activeToplevel.address}`);
    Logger.i("WindowInspector", `Moved window to special workspace ${name}`);
  }

  function toggleFloating() {
    if (!activeToplevel?.address) return;
    Hyprland.dispatch(`togglefloating address:0x${activeToplevel.address}`);
    Logger.i("WindowInspector", "Toggled floating");
  }

  function togglePin() {
    if (!activeToplevel?.address) return;
    Hyprland.dispatch(`pin address:0x${activeToplevel.address}`);
    Logger.i("WindowInspector", "Toggled pin");
  }

  function killWindow() {
    if (!activeToplevel?.address) return;
    Hyprland.dispatch(`killwindow address:0x${activeToplevel.address}`);
    Logger.i("WindowInspector", "Killed window");
  }

  function copyWindowInfo() {
    if (!windowData.address) return;

    const info = [
      `Title: ${windowData.title || ""}`,
      `Class: ${windowData.appId || ""}`,
      `Address: 0x${windowData.address}`,
      `Position: ${windowData.x}, ${windowData.y}`,
      `Size: ${windowData.width} x ${windowData.height}`,
      `Workspace: ${windowData.workspaceName} (${windowData.workspaceId})`,
      `Monitor: ${windowData.monitorName}`,
      `PID: ${windowData.pid}`,
      `Initial Title: ${windowData.initialTitle || ""}`,
      `Initial Class: ${windowData.initialClass || ""}`,
      `Floating: ${windowData.floating ? "yes" : "no"}`,
      `Pinned: ${windowData.pinned ? "yes" : "no"}`,
      `Fullscreen: ${getFullscreenText(windowData.fullscreen)}`,
      `XWayland: ${windowData.xwayland ? "yes" : "no"}`
    ].join("\n");

    copyProcess.textToCopy = info;
    copyProcess.running = true;
    Logger.i("WindowInspector", "Copied window info to clipboard");
  }

  Process {
    id: copyProcess
    property string textToCopy: ""
    command: ["wl-copy", "--", textToCopy]
  }

  function refreshData() {
    Hyprland.refreshToplevels();
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  function createEmptyWindowData() {
    return {
      address: "", title: "", appId: "",
      initialTitle: "", initialClass: "", pid: -1,
      x: 0, y: 0, width: 0, height: 0,
      workspaceId: -1, workspaceName: "",
      monitorId: -1, monitorName: "", monitorX: 0, monitorY: 0,
      floating: false, pinned: false, fullscreen: 0, xwayland: false,
      tags: [], grouped: []
    };
  }

  function getAppId(toplevel) {
    if (!toplevel) return "";

    // Try wayland appId first
    try {
      if (toplevel.wayland?.appId) return toplevel.wayland.appId;
    } catch (e) {}

    // Try lastIpcObject
    const ipc = toplevel.lastIpcObject;
    if (ipc) {
      return ipc.class || ipc.initialClass || "";
    }

    return "";
  }

  function getFullscreenText(state) {
    switch (state) {
      case 0: return "off";
      case 1: return "maximized";
      case 2: return "fullscreen";
      default: return "unknown";
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════

  Component.onCompleted: {
    if (!CompositorService.isHyprland) {
      Logger.w("WindowInspector", "This plugin only works with Hyprland");
      return;
    }
    Logger.i("WindowInspector", "Plugin loaded");
  }

  // Monitor for active window changes
  Connections {
    target: Hyprland
    enabled: CompositorService.isHyprland

    function onRawEvent(event) {
      // Refresh on relevant events
      if (["activewindow", "activewindowv2", "openwindow", "closewindow",
           "movewindow", "changefloatingmode", "fullscreen", "pin"].includes(event.name)) {
        Qt.callLater(refreshData);
      }
    }
  }
}
