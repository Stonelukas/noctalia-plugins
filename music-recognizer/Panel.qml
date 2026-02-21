import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 420 * Style.uiScaleRatio
  property real contentPreferredHeight: 550 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var history: mainInstance?.history ?? []

  ListModel { id: historyModel }

  Component.onCompleted: loadHistory()
  onHistoryChanged: loadHistory()

  function loadHistory() {
    historyModel.clear();
    for (var i = 0; i < history.length; i++) {
      historyModel.append(history[i]);
    }
  }

  function openUrl(url) {
    if (url) Quickshell.execDetached(["xdg-open", url]);
  }

  function buildSpotifyUrl(title, artist) {
    return "https://open.spotify.com/search/" + encodeURIComponent(title + " " + artist);
  }

  function buildYouTubeUrl(title, artist) {
    return "https://www.youtube.com/results?search_query=" + encodeURIComponent(title + " " + artist);
  }

  function buildGeniusUrl(title, artist) {
    return "https://genius.com/search?q=" + encodeURIComponent(title + " " + artist);
  }

  function formatTimestamp(isoString) {
    if (!isoString) return "";
    var date = new Date(isoString);
    var diffMs = new Date() - date;
    var diffMins = Math.floor(diffMs / 60000);
    var diffHours = Math.floor(diffMs / 3600000);
    var diffDays = Math.floor(diffMs / 86400000);
    if (diffMins < 1) return pluginApi?.tr("panel.time.now") || "Just now";
    if (diffMins < 60) return diffMins + (pluginApi?.tr("panel.time.mins_ago") || "m ago");
    if (diffHours < 24) return diffHours + (pluginApi?.tr("panel.time.hours_ago") || "h ago");
    if (diffDays < 7) return diffDays + (pluginApi?.tr("panel.time.days_ago") || "d ago");
    return date.toLocaleDateString();
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NIcon { icon: "music"; pointSize: Style.fontSizeL; color: Color.mPrimary }
        NText {
          text: pluginApi?.tr("panel.header.title") || "Music History"
          font.pointSize: Style.fontSizeL
          font.weight: Font.Medium
          color: Color.mOnSurface
        }
        Item { Layout.fillWidth: true }
        NText {
          visible: historyModel.count > 0
          text: historyModel.count + " " + (pluginApi?.tr("panel.header.songs") || "songs")
          font.pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }
        NIconButton {
          visible: historyModel.count > 0
          icon: "trash-2"
          tooltipText: pluginApi?.tr("panel.header.clear") || "Clear history"
          color: Color.mError
          onClicked: mainInstance?.clearHistory()
        }
      }

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        Item {
          anchors.fill: parent
          visible: historyModel.count === 0

          ColumnLayout {
            anchors.centerIn: parent
            spacing: Style.marginM
            NIcon {
              Layout.alignment: Qt.AlignHCenter
              icon: "music-off"
              pointSize: Style.fontSizeXL * 2
              color: Color.mOnSurfaceVariant
              opacity: 0.5
            }
            NText {
              Layout.alignment: Qt.AlignHCenter
              text: pluginApi?.tr("panel.empty.title") || "No songs recognized yet"
              font.pointSize: Style.fontSizeM
              color: Color.mOnSurfaceVariant
            }
            NText {
              Layout.alignment: Qt.AlignHCenter
              text: pluginApi?.tr("panel.empty.hint") || "Click the bar widget to identify a song"
              font.pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
              opacity: 0.7
            }
          }
        }

        ScrollView {
          anchors.fill: parent
          anchors.margins: Style.marginS
          visible: historyModel.count > 0
          clip: true

          ListView {
            id: historyList
            model: historyModel
            spacing: Style.marginS
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
              width: ListView.view.width
              height: cardContent.implicitHeight + Style.marginM * 2
              color: cardHover.containsMouse ? Color.mHover : Color.mSurface
              radius: Style.radiusM

              MouseArea {
                id: cardHover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
              }

              RowLayout {
                id: cardContent
                anchors.fill: parent
                anchors.margins: Style.marginM
                spacing: Style.marginM

                Rectangle {
                  Layout.preferredWidth: 56 * Style.uiScaleRatio
                  Layout.preferredHeight: 56 * Style.uiScaleRatio
                  radius: Style.radiusS
                  color: Color.mSurfaceVariant

                  Image {
                    anchors.fill: parent
                    source: model.coverUrl || ""
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                  }

                  NIcon {
                    anchors.centerIn: parent
                    icon: "music"
                    color: Color.mOnSurfaceVariant
                    visible: !model.coverUrl
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginXS

                  NText {
                    text: model.title || "Unknown"
                    font.pointSize: Style.fontSizeM
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                  NText {
                    text: model.artist || "Unknown Artist"
                    font.pointSize: Style.fontSizeS
                    color: Color.mOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                  NText {
                    text: formatTimestamp(model.timestamp)
                    font.pointSize: Style.fontSizeXS
                    color: Color.mOnSurfaceVariant
                    opacity: 0.7
                  }
                }

                RowLayout {
                  spacing: Style.marginXS

                  NIconButton {
                    icon: "brand-spotify"
                    tooltipText: "Spotify"
                    implicitWidth: Style.baseWidgetSize * 0.8
                    implicitHeight: Style.baseWidgetSize * 0.8
                    color: "#1DB954"
                    onClicked: openUrl(buildSpotifyUrl(model.title, model.artist))
                  }
                  NIconButton {
                    icon: "brand-youtube"
                    tooltipText: "YouTube"
                    implicitWidth: Style.baseWidgetSize * 0.8
                    implicitHeight: Style.baseWidgetSize * 0.8
                    color: "#FF0000"
                    onClicked: openUrl(buildYouTubeUrl(model.title, model.artist))
                  }
                  NIconButton {
                    icon: "file-text"
                    tooltipText: pluginApi?.tr("panel.action.lyrics") || "Lyrics"
                    implicitWidth: Style.baseWidgetSize * 0.8
                    implicitHeight: Style.baseWidgetSize * 0.8
                    color: "#FFFF64"
                    onClicked: openUrl(buildGeniusUrl(model.title, model.artist))
                  }
                  NIconButton {
                    visible: model.shazamUrl && model.shazamUrl !== ""
                    icon: "external-link"
                    tooltipText: "Shazam"
                    implicitWidth: Style.baseWidgetSize * 0.8
                    implicitHeight: Style.baseWidgetSize * 0.8
                    color: "#0088FF"
                    onClicked: openUrl(model.shazamUrl)
                  }
                  NIconButton {
                    icon: "x"
                    tooltipText: pluginApi?.tr("panel.action.delete") || "Remove"
                    implicitWidth: Style.baseWidgetSize * 0.8
                    implicitHeight: Style.baseWidgetSize * 0.8
                    color: Color.mError
                    opacity: cardHover.containsMouse ? 1.0 : 0.5
                    onClicked: mainInstance?.removeFromHistory(index)
                  }
                }
              }
            }
          }
        }
      }

      NButton {
        Layout.fillWidth: true
        text: {
          var state = mainInstance?.state ?? "idle";
          if (state === "listening") return pluginApi?.tr("panel.button.listening") || "Listening...";
          if (state === "processing") return pluginApi?.tr("panel.button.processing") || "Recognizing...";
          return pluginApi?.tr("panel.button.recognize") || "Recognize Song";
        }
        icon: mainInstance?.state === "idle" || mainInstance?.state === "error" ? "music" : "loader"
        enabled: mainInstance?.state === "idle" || mainInstance?.state === "error"
        onClicked: mainInstance?.startRecognition()
      }
    }
  }
}
