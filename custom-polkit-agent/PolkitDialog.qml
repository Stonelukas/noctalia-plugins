import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

Item {
    id: root

    required property var polkitMain
    property bool showPassword: false

    readonly property int animDuration: polkitMain?.animationDuration ?? 200

    // Focus management
    function focusPassword() {
        passwordField.forceActiveFocus()
        passwordField.selectAll()
    }

    // Scrim background
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Color.mShadow, 0.6)
        opacity: polkitMain?.active ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: polkitMain?.cancel()
        }
    }

    // Dialog card
    Rectangle {
        id: dialog
        anchors.centerIn: parent
        width: Math.min(450 * Style.uiScaleRatio, parent.width - 40)
        height: contentColumn.implicitHeight + Style.marginXL * 2
        radius: Style.radiusL
        color: Color.mSurface
        border.color: Qt.alpha(Color.mOutline, 0.3)
        border.width: 1

        // Entrance animation
        scale: polkitMain?.active ? 1.0 : 0.9
        opacity: polkitMain?.active ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: root.animDuration
                easing.type: Easing.OutCubic
            }
        }

        // Shake animation on failure
        SequentialAnimation {
            id: shakeAnimation
            property int shakeDuration: 50
            property int shakeDistance: 10

            NumberAnimation {
                target: dialog; property: "anchors.horizontalCenterOffset"
                to: shakeAnimation.shakeDistance
                duration: shakeAnimation.shakeDuration
            }
            NumberAnimation {
                target: dialog; property: "anchors.horizontalCenterOffset"
                to: -shakeAnimation.shakeDistance * 2
                duration: shakeAnimation.shakeDuration
            }
            NumberAnimation {
                target: dialog; property: "anchors.horizontalCenterOffset"
                to: shakeAnimation.shakeDistance * 2
                duration: shakeAnimation.shakeDuration
            }
            NumberAnimation {
                target: dialog; property: "anchors.horizontalCenterOffset"
                to: -shakeAnimation.shakeDistance
                duration: shakeAnimation.shakeDuration
            }
            NumberAnimation {
                target: dialog; property: "anchors.horizontalCenterOffset"
                to: 0
                duration: shakeAnimation.shakeDuration
            }
        }

        // Keyboard handling
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                polkitMain?.cancel()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (polkitMain?.interactionAvailable && passwordField.text.length > 0) {
                    polkitMain?.submit(passwordField.text)
                    passwordField.text = ""
                }
                event.accepted = true
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: Style.marginXL
            }
            spacing: Style.marginL

            // Icon
            NIcon {
                Layout.alignment: Qt.AlignHCenter
                icon: "shield-lock"
                pointSize: Style.fontSizeXL * 2
                color: Color.mPrimary
            }

            // Title
            NText {
                Layout.alignment: Qt.AlignHCenter
                text: polkitMain?.pluginApi?.tr("dialog.title")
                    || "Authentication Required"
                pointSize: Style.fontSizeL
                font.bold: true
                color: Color.mOnSurface
            }

            // Message
            NText {
                Layout.fillWidth: true
                text: polkitMain?.cleanMessage || ""
                pointSize: Style.fontSizeM
                color: Color.mOnSurfaceVariant
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
            }

            // Password input row
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                TextField {
                    id: passwordField
                    Layout.fillWidth: true
                    placeholderText: polkitMain?.inputPrompt
                        || polkitMain?.pluginApi?.tr("dialog.password-placeholder")
                        || "Password"
                    echoMode: root.showPassword || !(polkitMain?.usePasswordChars ?? true)
                        ? TextInput.Normal : TextInput.Password
                    enabled: polkitMain?.interactionAvailable ?? false
                    font.pointSize: Style.fontSizeM

                    background: Rectangle {
                        radius: Style.radiusM
                        color: Color.mSurfaceVariant
                        border.color: passwordField.activeFocus
                            ? Color.mPrimary
                            : Qt.alpha(Color.mOutline, 0.5)
                        border.width: passwordField.activeFocus ? 2 : 1
                    }

                    color: Color.mOnSurface
                    placeholderTextColor: Color.mOnSurfaceVariant

                    Keys.onReturnPressed: {
                        if (polkitMain?.interactionAvailable && text.length > 0) {
                            polkitMain?.submit(text)
                            passwordField.text = ""
                        }
                    }
                }

                NIconButton {
                    icon: root.showPassword ? "eye-off" : "eye"
                    onClicked: root.showPassword = !root.showPassword
                }
            }

            // Error message
            NText {
                Layout.fillWidth: true
                text: polkitMain?.errorMessage || ""
                pointSize: Style.fontSizeS
                color: Color.mError
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                visible: text.length > 0
            }

            // Action buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginM

                Item { Layout.fillWidth: true }

                NButton {
                    text: polkitMain?.pluginApi?.tr("dialog.cancel") || "Cancel"
                    onClicked: polkitMain?.cancel()
                }

                NButton {
                    text: polkitMain?.pluginApi?.tr("dialog.authenticate") || "Authenticate"
                    backgroundColor: Color.mPrimary
                    textColor: Color.mOnPrimary
                    enabled: polkitMain?.interactionAvailable
                        && passwordField.text.length > 0
                    onClicked: {
                        polkitMain?.submit(passwordField.text)
                        passwordField.text = ""
                    }
                }
            }
        }

        // React to state changes
        Connections {
            target: polkitMain

            function onInteractionAvailableChanged() {
                if (polkitMain.interactionAvailable) {
                    root.focusPassword()
                }
            }

            function onErrorMessageChanged() {
                if (polkitMain.errorMessage.length > 0) {
                    shakeAnimation.start()
                }
            }
        }
    }

    // Auto-focus when dialog becomes visible
    Connections {
        target: polkitMain

        function onActiveChanged() {
            if (polkitMain.active) {
                root.showPassword = false
                dialog.anchors.horizontalCenterOffset = 0
                Qt.callLater(root.focusPassword)
            }
        }
    }
}
