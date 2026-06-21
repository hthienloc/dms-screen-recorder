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
    pluginId: "screenRecorderLH"

    readonly property var daemon: PluginService.getGlobalVar("screenRecorderLH", "instance")

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

        SettingsDivider {}

        SelectionSettingPlus {
            settingKey: "videoCodec"
            label: I18n.tr("Video Codec")
            description: I18n.tr("Hardware video codec to use.")
            options: [
                { label: I18n.tr("Auto Detect"), value: "auto" },
                { label: "H.264", value: "h264" },
                { label: "HEVC (H.265)", value: "hevc" },
                { label: "AV1", value: "av1" }
            ]
            defaultValue: "auto"
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Recording Settings")
            icon: "videocam"
        }

        SelectionSettingPlus {
            settingKey: "recordingMode"
            label: I18n.tr("Recording Source")
            description: I18n.tr("Select the source area to record (Full Screen, Custom Region, or specific Window).")
            options: [
                { label: I18n.tr("Full Screen"), value: "screen" },
                { label: I18n.tr("Custom Region"), value: "region" },
                { label: I18n.tr("Active Window (Wayland)"), value: "window" }
            ]
            defaultValue: "screen"
        }

        SettingsDivider {
            visible: rootSettings.daemon && rootSettings.daemon.recordingMode === "region"
        }

        StringSettingPlus {
            settingKey: "regionGeometry"
            label: I18n.tr("Region Geometry")
            description: I18n.tr("Define recording region size and position in WxH+X+Y format (e.g. 1024x768+100+100).")
            defaultValue: "1024x768+100+100"
            placeholder: "1024x768+100+100"
            visible: rootSettings.daemon && rootSettings.daemon.recordingMode === "region"
        }

        SettingsDivider {
            visible: rootSettings.daemon && rootSettings.daemon.recordingMode === "screen"
        }

        SelectionSettingPlus {
            settingKey: "targetMonitor"
            label: I18n.tr("Target Monitor")
            description: I18n.tr("Select which monitor to record by default.")
            options: rootSettings.daemon ? rootSettings.daemon.monitorsList : [{ label: I18n.tr("First Monitor Found"), value: "all" }]
            defaultValue: "all"
            visible: rootSettings.daemon && rootSettings.daemon.recordingMode === "screen"
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "recordAudio"
            label: I18n.tr("Record Audio")
            description: I18n.tr("Record system audio playback along with the screen.")
            defaultValue: false
        }

        SettingsDivider {}

        SelectionSettingPlus {
            settingKey: "audioCodec"
            label: I18n.tr("Audio Codec")
            description: I18n.tr("Select the audio compression format.")
            options: [
                { label: "Opus", value: "opus" },
                { label: "AAC", value: "aac" },
                { label: "FLAC (Lossless)", value: "flac" }
            ]
            defaultValue: "opus"
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "showCursor"
            label: I18n.tr("Show Cursor")
            description: I18n.tr("Show mouse cursor in the recorded video.")
            defaultValue: true
        }

        SettingsDivider {}

        SliderSettingPlus {
            settingKey: "framerate"
            label: I18n.tr("Framerate")
            description: I18n.tr("Number of frames per second to record.")
            defaultValue: 60
            minimum: 15
            maximum: 144
            unit: " FPS"
        }

        SettingsDivider {}

        SelectionSettingPlus {
            settingKey: "videoQuality"
            label: I18n.tr("Video Quality")
            description: I18n.tr("Select the video recording quality.")
            options: [
                { label: I18n.tr("Medium"), value: "medium" },
                { label: I18n.tr("High"), value: "high" },
                { label: I18n.tr("Very High"), value: "very_high" },
                { label: I18n.tr("Ultra"), value: "ultra" }
            ]
            defaultValue: "very_high"
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Advanced Settings")
            icon: "tune"
        }

        ToggleSettingPlus {
            settingKey: "forceCfr"
            label: I18n.tr("Constant Frame Rate (CFR)")
            description: I18n.tr("Force video editing compatibility by avoiding variable frame rates.")
            defaultValue: false
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "lowPower"
            label: I18n.tr("Low Power Mode")
            description: I18n.tr("Run encoder in low power mode (helps AMD graphics cards).")
            defaultValue: false
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "overclock"
            label: I18n.tr("GPU Overclock")
            description: I18n.tr("Avoid GPU downclocking while recording to prevent stutter.")
            defaultValue: false
        }

        SettingsDivider {}

        SelectionSettingPlus {
            settingKey: "encoderTune"
            label: I18n.tr("Encoder Tuning")
            description: I18n.tr("Prioritize either recording performance or image quality.")
            options: [
                { label: I18n.tr("Performance"), value: "performance" },
                { label: I18n.tr("Quality"), value: "quality" }
            ]
            defaultValue: "performance"
        }

        SettingsDivider {}

        SelectionSettingPlus {
            settingKey: "colorRange"
            label: I18n.tr("Color Range")
            description: I18n.tr("Select recording color range (Full is recommended for PC playback).")
            options: [
                { label: I18n.tr("Full"), value: "full" },
                { label: I18n.tr("Limited"), value: "limited" }
            ]
            defaultValue: "full"
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Widget Customization")
            icon: "palette"
        }

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
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Notifications")
            icon: "notifications"
        }

        ButtonGroupSettingPlus {
            settingKey: "postNotification"
            label: I18n.tr("Post-Recording Notification")
            description: I18n.tr("Select which types of notifications to show after a recording is saved.")
            defaultValue: "notification"
            options: [
                { label: I18n.tr("Notification"), value: "notification" },
                { label: I18n.tr("Toast"), value: "toast" },
                { label: I18n.tr("Both"), value: "both" },
                { label: I18n.tr("None"), value: "none" }
            ]
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-screen-recorder"
    }
}
