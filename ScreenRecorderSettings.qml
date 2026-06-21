pragma ComponentBehavior: Bound

import "./dms-common"
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginSettings {
    id: rootSettings
    pluginId: "screenRecorder"

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Output Configuration")
            icon: "folder"
        }

        StringSettingPlus {
            settingKey: "outputDirectory"
            label: I18n.tr("Output Directory")
            description: I18n.tr("Where recorded videos will be saved.")
            defaultValue: "~/Videos/Recordings"
            placeholder: "~/Videos/Recordings"
            isDirectory: true
        }

        SettingsDivider {}

        SelectionSettingPlus {
            settingKey: "videoFormat"
            label: I18n.tr("Video Format")
            description: I18n.tr("Container format for the video file.")
            options: [
                { label: "MP4 (.mp4)", value: "mp4" },
                { label: "Matroska (.mkv)", value: "mkv" },
                { label: "WebM (.webm)", value: "webm" }
            ]
            defaultValue: "mp4"
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Recording Settings")
            icon: "videocam"
        }

        ToggleSettingPlus {
            settingKey: "recordAudio"
            label: I18n.tr("Record Audio")
            description: I18n.tr("Record system audio playback along with the screen.")
            defaultValue: false
        }

        SettingsDivider {}

        SelectionSettingPlus {
            settingKey: "framerate"
            label: I18n.tr("Framerate")
            description: I18n.tr("Number of frames per second to record.")
            options: [
                { label: "30 FPS", value: "30" },
                { label: "60 FPS", value: "60" }
            ]
            defaultValue: "60"
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "showPillBorder"
            label: I18n.tr("Show Pill Border")
            description: I18n.tr("Show border and background for the recording pill in the bar.")
            defaultValue: false
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "showRecordingDot"
            label: I18n.tr("Show Recording Dot")
            description: I18n.tr("Show the red recording status dot in the bar widget.")
            defaultValue: true
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "blinkRecordDot"
            label: I18n.tr("Blink Recording Dot")
            description: I18n.tr("Blink the red recording status dot in the bar widget.")
            defaultValue: false
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "showFinishedNotification"
            label: I18n.tr("Show Finished Notification")
            description: I18n.tr("Show a notification when the recording is saved successfully or fails.")
            defaultValue: true
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-screen-recorder"
    }
}
