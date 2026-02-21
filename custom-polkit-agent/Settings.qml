import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
    id: root
    spacing: Style.marginL

    property var pluginApi: null

    property int editAnimationDuration:
        pluginApi?.pluginSettings?.animationDuration
        ?? pluginApi?.manifest?.metadata?.defaultSettings?.animationDuration
        ?? 200

    function saveSettings() {
        if (!pluginApi) {
            Logger.e("PolkitAgent", "Cannot save: pluginApi is null")
            return
        }

        pluginApi.pluginSettings.animationDuration = root.editAnimationDuration
        pluginApi.saveSettings()
        Logger.i("PolkitAgent", "Settings saved")
    }

    NSlider {
        label: pluginApi?.tr("settings.animation-duration") || "Animation Duration"
        description: pluginApi?.tr("settings.animation-duration-desc")
            || "Duration of dialog entrance and exit animations (ms)"
        from: 50
        to: 1000
        stepSize: 50
        value: root.editAnimationDuration
        onMoved: value => {
            root.editAnimationDuration = value
            root.saveSettings()
        }
        defaultValue: pluginApi?.manifest?.metadata?.defaultSettings?.animationDuration ?? 200
    }

    Item {
        Layout.fillHeight: true
    }
}
