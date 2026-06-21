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
            defaultValue: "~/Videos/Recordings"
            placeholder: "~/Videos/Recordings"
            isDirectory: true
        }

        SettingsDivider {}

        ButtonGroupSettingPlus {
            settingKey: "videoFormat"
            label: I18n.tr("Video Format")
            options: [
                { label: "MP4 (.mp4)", value: "mp4" },
                { label: "Matroska (.mkv)", value: "mkv" },
                { label: "WebM (.webm)", value: "webm" }
            ]
            defaultValue: "mp4"
        }

        SettingsDivider {}

        ButtonGroupSettingPlus {
            settingKey: "videoCodec"
            label: I18n.tr("Video Codec")
            options: [
                { label: I18n.tr("Auto Detect"), value: "auto" },
                { label: "H.264", value: "h264" },
                { label: "HEVC (H.265)", value: "hevc" },
                { label: "AV1", value: "av1" }
            ]
            defaultValue: "auto"
        }

        SettingsDivider {}

        ButtonGroupSettingPlus {
            settingKey: "audioCodec"
            label: I18n.tr("Audio Codec")
            options: [
                { label: "Opus", value: "opus" },
                { label: "AAC", value: "aac" },
                { label: "FLAC (Lossless)", value: "flac" }
            ]
            defaultValue: "opus"
        }

        SettingsDivider {}

        ButtonGroupSettingPlus {
            settingKey: "videoQuality"
            label: I18n.tr("Video Quality")
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
            text: I18n.tr("Recording Settings")
            icon: "videocam"
        }

        ButtonGroupSettingPlus {
            settingKey: "recordingMode"
            label: I18n.tr("Recording Source")
            options: [
                { label: I18n.tr("Full Screen"), value: "screen" },
                { label: I18n.tr("Custom Region"), value: "region" }
                // { label: I18n.tr("Active Window"), value: "window" }
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
            options: rootSettings.daemon ? rootSettings.daemon.monitorsList : [{ label: I18n.tr("First Monitor Found"), value: "all" }]
            defaultValue: "all"
            visible: rootSettings.daemon && rootSettings.daemon.recordingMode === "screen"
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "recordAudio"
            label: I18n.tr("Record Audio")
            defaultValue: false
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "showCursor"
            label: I18n.tr("Show Cursor")
            defaultValue: true
        }

        SettingsDivider {}

        SliderSettingPlus {
            settingKey: "framerate"
            label: I18n.tr("Framerate")
            defaultValue: 60
            minimum: 15
            maximum: 144
            unit: " FPS"
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

        ButtonGroupSettingPlus {
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

        ButtonGroupSettingPlus {
            settingKey: "colorRange"
            label: I18n.tr("Color Range")
            description: I18n.tr("Select recording color range (Full is recommended for PC playback).")
            options: [
                { label: I18n.tr("Full"), value: "full" },
                { label: I18n.tr("Limited"), value: "limited" }
            ]
            defaultValue: "full"
        }

        SettingsDivider {}

        StringSettingPlus {
            settingKey: "postRecordCommand"
            label: I18n.tr("Post-Recording Command")
            description: I18n.tr("Command to run after recording finishes. Use $1 to reference the file path.")
            defaultValue: ""
            placeholder: "e.g. handbrake-cli -i $1 ..."
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
            defaultValue: false
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "showRecordingDot"
            label: I18n.tr("Show Recording Dot")
            defaultValue: true
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "blinkRecordDot"
            label: I18n.tr("Blink Recording Dot")
            defaultValue: false
        }

        SettingsDivider {}

        ToggleSettingPlus {
            settingKey: "minimalPopout"
            label: I18n.tr("Minimal Popout Menu")
            defaultValue: true
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
            defaultValue: "notification"
            options: [
                { label: I18n.tr("Notification"), value: "notification" },
                { label: I18n.tr("Toast"), value: "toast" },
                { label: I18n.tr("Both"), value: "both" },
                { label: I18n.tr("None"), value: "none" }
            ]
        }
    }

    SettingsCard {
        SectionTitle {
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book"
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: usageTitle.isExpanded

            UsageGuide {
                expanded: usageTitle.isExpanded
                items: [
                    I18n.tr("Left-click the widget when idle to open the recording control popout."),
                    I18n.tr("Right-click the widget when idle to quickly start custom region recording."),
                    I18n.tr("Middle-click the widget when idle to quickly start full screen recording."),
                    I18n.tr("Interactive region selection requires <b>slurp</b> to be installed on your system."),
                    I18n.tr("To hide the cursor in full screen mode, direct KMS capture may require running the setcap command below:")
                ]
            }

            CopyBox {
                label: I18n.tr("Grant KMS capture capabilities")
                text: "sudo setcap cap_sys_admin+ep /usr/bin/gpu-screen-recorder"
            }
        }
    }

    SettingsCard {
        id: ipcSection
        SectionTitle {
            id: ipcTitle
            text: I18n.tr("IPC Commands")
            icon: "terminal"
            collapsible: true
            settingKey: "ipcCommandsExpanded"
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: ipcTitle.isExpanded

            CopyBox {
                label: I18n.tr("Toggle Full Screen Recording")
                text: "dms ipc screenRecorderLH toggleScreen"
            }

            CopyBox {
                label: I18n.tr("Toggle Custom Region Selection")
                text: "dms ipc screenRecorderLH toggleRegion"
            }

            CopyBox {
                label: I18n.tr("Toggle Saved Region Recording")
                text: "dms ipc screenRecorderLH toggleSavedRegion"
            }

            CopyBox {
                label: I18n.tr("Toggle Active Window Selection (Portal)")
                text: "dms ipc screenRecorderLH toggleWindow"
            }

            CopyBox {
                label: I18n.tr("Toggle Portal Selection")
                text: "dms ipc screenRecorderLH togglePortal"
            }

            CopyBox {
                label: I18n.tr("Stop Recording")
                text: "dms ipc screenRecorderLH stop"
            }

            CopyBox {
                label: I18n.tr("Cancel Recording (Delete File)")
                text: "dms ipc screenRecorderLH cancel"
            }

            CopyBox {
                label: I18n.tr("Pause / Resume Recording")
                text: "dms ipc screenRecorderLH pause"
            }

            CopyBox {
                label: I18n.tr("Get Recording Status (JSON)")
                text: "dms ipc screenRecorderLH status"
            }
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-screen-recorder"
    }
}

