import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  // Bar positioning
  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool barIsVertical: barPosition === "left" || barPosition === "right"

  // Main instance state
  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property string currentState: mainInstance?.state ?? "idle"
  readonly property var lastSong: mainInstance?.lastSong

  // Sizing
  readonly property real contentWidth: barIsVertical ? Style.capsuleHeight : capsuleContent.implicitWidth + Style.marginM * 2
  readonly property real contentHeight: Style.capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  // State-dependent properties
  readonly property string iconName: {
    switch (currentState) {
      case "listening": return "disc";
      case "processing": return "loader";
      case "error": return "music-off";
      default: return "music";
    }
  }

  readonly property color iconColor: {
    if (mouseArea.containsMouse) return Color.mOnHover;
    switch (currentState) {
      case "listening":
      case "processing":
      case "success":
        return Color.mPrimary;
      case "error":
        return Color.mError;
      default:
        return Color.mOnSurface;
    }
  }

  readonly property color bgColor: {
    if (mouseArea.containsMouse) return Color.mHover;
    return Style.capsuleColor;
  }

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    color: root.bgColor
    radius: Style.radiusL
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color {
      ColorAnimation { duration: 150 }
    }

    RowLayout {
      id: capsuleContent
      anchors.centerIn: parent
      spacing: Style.marginS

      Item {
        width: Style.iconSize
        height: Style.iconSize

        NIcon {
          id: statusIcon
          anchors.centerIn: parent
          icon: root.iconName
          color: root.iconColor
          applyUiScale: false

          rotation: 0

          RotationAnimation on rotation {
            running: root.currentState === "listening"
            from: 0
            to: 360
            duration: 2000
            loops: Animation.Infinite
          }

          RotationAnimation on rotation {
            running: root.currentState === "processing"
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
          }
        }
      }

      NText {
        id: songLabel
        visible: !root.barIsVertical && root.currentState === "success" && root.lastSong
        text: root.lastSong?.title ?? ""
        color: Color.mPrimary
        font.pointSize: Style.barFontSize
        font.weight: Font.Medium
        elide: Text.ElideRight
        Layout.maximumWidth: 150 * Style.uiScaleRatio
      }
    }
  }

  Rectangle {
    id: pulseRing
    anchors.centerIn: visualCapsule
    width: visualCapsule.width
    height: visualCapsule.height
    radius: Style.radiusL
    color: "transparent"
    border.color: Color.mPrimary
    border.width: 2
    opacity: 0
    scale: 1

    SequentialAnimation {
      id: pulseAnimation
      running: false

      ParallelAnimation {
        NumberAnimation {
          target: pulseRing
          property: "opacity"
          from: 0.8
          to: 0
          duration: 600
          easing.type: Easing.OutQuad
        }
        NumberAnimation {
          target: pulseRing
          property: "scale"
          from: 1
          to: 1.5
          duration: 600
          easing.type: Easing.OutQuad
        }
      }

      ScriptAction {
        script: {
          pulseRing.scale = 1;
          pulseRing.opacity = 0;
        }
      }
    }
  }

  onCurrentStateChanged: {
    if (currentState === "success") {
      pulseAnimation.start();
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("context.history") || "History",
        "action": "history",
        "icon": "list"
      },
      {
        "label": pluginApi?.tr("context.recognize") || "Recognize Song",
        "action": "recognize",
        "icon": "music",
        "enabled": root.currentState === "idle" || root.currentState === "error"
      },
      {
        "label": pluginApi?.tr("context.settings") || "Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: action => {
      contextMenu.close();
      PanelService.closeContextMenu(screen);

      if (action === "history") {
        pluginApi.openPanel(root.screen);
      } else if (action === "recognize") {
        mainInstance?.startRecognition();
      } else if (action === "settings") {
        BarService.openPluginSettings(screen, pluginApi.manifest);
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: mouse => {
      if (!pluginApi) return;

      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
        return;
      }

      // Left-click depends on state
      switch (root.currentState) {
        case "idle":
        case "error":
          mainInstance?.startRecognition();
          break;
        case "listening":
        case "processing":
          mainInstance?.cancelRecognition();
          break;
        case "success":
          pluginApi.openPanel(root.screen);
          break;
      }
    }

    onEntered: {
      var tooltip = buildTooltip();
      if (tooltip) {
        TooltipService.show(root, tooltip, BarService.getTooltipDirection());
      }
    }

    onExited: TooltipService.hide()
  }

  function buildTooltip() {
    switch (root.currentState) {
      case "listening":
        return pluginApi?.tr("bar.tooltip.listening") || "Listening...";
      case "processing":
        return pluginApi?.tr("bar.tooltip.processing") || "Recognizing...";
      case "success":
        if (root.lastSong) {
          return root.lastSong.title + "\n" + root.lastSong.artist;
        }
        return pluginApi?.tr("bar.tooltip.success") || "Song recognized";
      case "error":
        return mainInstance?.errorMessage || (pluginApi?.tr("bar.tooltip.error") || "Recognition failed");
      default:
        return pluginApi?.tr("bar.tooltip.idle") || "Click to identify song";
    }
  }
}
