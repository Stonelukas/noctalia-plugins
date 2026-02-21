import QtQuick
import Quickshell
import Quickshell.Services.Polkit
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null

    // State exposed to PolkitDialog
    property alias active: polkitAgent.isActive
    property alias flow: polkitAgent.flow
    property bool interactionAvailable: false
    property string errorMessage: ""

    // Animation duration from settings
    readonly property int animationDuration:
        pluginApi?.pluginSettings?.animationDuration
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.animationDuration
        ?? 200

    // Clean message (strip trailing dot from polkit message)
    readonly property string cleanMessage: {
        if (!root.flow) return ""
        var msg = root.flow.message || ""
        return msg.endsWith(".") ? msg.slice(0, -1) : msg
    }

    // Input prompt from flow
    readonly property string inputPrompt: root.flow?.inputPrompt || ""

    // Whether to mask password chars
    readonly property bool usePasswordChars: !(root.flow?.responseVisible ?? false)

    function cancel() {
        if (root.flow) {
            root.flow.cancelAuthenticationRequest()
        }
    }

    function submit(text) {
        if (root.flow && text.length > 0) {
            root.errorMessage = ""
            root.flow.submit(text)
            root.interactionAvailable = false
            submitTimeout.restart()
        }
    }

    // Timeout watchdog: re-enable interaction if polkit backend hangs
    Timer {
        id: submitTimeout
        interval: 5000
        running: false
        onTriggered: {
            if (!root.interactionAvailable && root.active) {
                root.interactionAvailable = true
                root.errorMessage = pluginApi?.tr("error.timeout")
                    || "Request timed out. Please try again."
            }
        }
    }

    // Track auth flow signals
    Connections {
        target: root.flow || null
        enabled: !!root.flow

        function onAuthenticationFailed() {
            submitTimeout.stop()
            root.interactionAvailable = true
            root.errorMessage = pluginApi?.tr("error.auth-failed")
                || "Authentication failed. Please try again."
        }
    }

    // Polkit agent service
    PolkitAgent {
        id: polkitAgent

        onAuthenticationRequestStarted: {
            root.interactionAvailable = true
            root.errorMessage = ""
        }
    }

    // Fullscreen overlay windows (one per screen)
    Loader {
        active: root.active

        sourceComponent: Variants {
            model: Quickshell.screens

            delegate: PanelWindow {
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "noctalia:polkit"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                PolkitDialog {
                    anchors.fill: parent
                    polkitMain: root
                }
            }
        }
    }

    Component.onDestruction: {
        root.interactionAvailable = false
        root.errorMessage = ""
    }
}
