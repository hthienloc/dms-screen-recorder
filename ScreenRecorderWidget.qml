pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services
import "./dms-common"

PluginComponent {
    id: root

    pluginId: "screenRecorderLH"
    pluginService: PluginService

    readonly property var daemon: PluginService.getGlobalVar(pluginId, "instance")
    readonly property bool blinkRecordDot: pluginData.blinkRecordDot ?? false
    readonly property bool showRecordingDot: pluginData.showRecordingDot ?? false
    readonly property bool showPillBorder: pluginData.showPillBorder ?? false
    readonly property bool minimalPopout: pluginData.minimalPopout ?? true
    readonly property int recordingIconSize: showPillBorder ? 12 : Theme.iconSizeSmall

    // Blinking Timer for recording dot
    Timer {
        id: blinkTimer
        interval: 1000
        repeat: true
        running: daemon ? (daemon.isRecording && !daemon.isPaused) : false
        property bool blinkOn: true
        onTriggered: blinkOn = !blinkOn
    }



    // CC integration
    ccWidgetIcon: "videocam"
    ccWidgetPrimaryText: I18n.tr("Screen Recorder")
    ccWidgetSecondaryText: {
        const master = daemon;
        if (!master) return I18n.tr("Idle");
        if (master.isRecording) {
            return (master.isPaused ? I18n.tr("Paused: ") : I18n.tr("Recording: ")) + master.formatDuration(master.recordingSeconds);
        }
        return I18n.tr("Idle");
    }
    ccWidgetIsActive: daemon ? daemon.isRecording : false
    onCcWidgetToggled: {
        const master = daemon;
        if (master) {
            if (master.isRecording) {
                master.stopRecording();
            } else {
                master.startRecording();
            }
        }
    }

    // DankBar widget
    horizontalBarPill: Component {
        Item {
            implicitWidth: daemon && daemon.isRecording ? (recordRow.implicitWidth + (showPillBorder ? Theme.spacingM * 2 : 0)) : Theme.iconSizeSmall
            implicitHeight: Theme.iconSize
            anchors.verticalCenter: parent.verticalCenter

            Behavior on implicitWidth {
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }

            StyledRect {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: daemon && daemon.isRecording && showPillBorder ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1) : "transparent"
                border.color: daemon && daemon.isRecording && showPillBorder ? Theme.error : "transparent"
                border.width: daemon && daemon.isRecording && showPillBorder ? 1 : 0
            }

            Row {
                id: recordRow
                anchors.centerIn: parent
                spacing: daemon && daemon.isRecording ? Theme.spacingS : 0

                Item {
                    id: hIconWrapper
                    readonly property bool spinning: daemon ? daemon.isProcessing : false
                    width: daemon && daemon.isRecording ? root.recordingIconSize : Theme.iconSizeSmall
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    visible: daemon ? (daemon.isRecording ? root.showRecordingDot : true) : true

                    DankIcon {
                        anchors.centerIn: parent
                        name: hIconWrapper.spinning ? "sync" : (daemon && daemon.isRecording ? "fiber_manual_record" : "videocam")
                        size: parent.width
                        color: hIconWrapper.spinning ? Theme.primary : (daemon && daemon.isRecording ? Theme.error : Theme.surfaceText)
                        opacity: (!hIconWrapper.spinning && daemon && daemon.isRecording) ? (blinkRecordDot ? (blinkTimer.blinkOn ? 1.0 : 0.3) : 1.0) : 1.0

                        RotationAnimation on rotation {
                            id: hSpinAnim
                            running: hIconWrapper.spinning
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) rotation = 0
                        }
                    }
                }

                StyledText {
                    visible: daemon ? daemon.isRecording : false
                    text: daemon ? daemon.formatDuration(daemon.recordingSeconds) : "00:00"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Pause button
                Rectangle {
                    visible: daemon ? daemon.isRecording : false
                    width: daemon && daemon.isRecording ? 24 : 0
                    height: 24
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: pauseMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)

                    Behavior on color {
                        ColorAnimation {
                            duration: 90
                            easing.type: Theme.standardEasing
                        }
                    }

                    DankIcon {
                        name: daemon && daemon.isPaused ? "play_arrow" : "pause"
                        size: 14
                        color: Theme.primary
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: pauseMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (daemon) daemon.pauseRecording();
                        }
                    }
                }

                // Stop button
                Rectangle {
                    visible: daemon ? daemon.isRecording : false
                    width: daemon && daemon.isRecording ? 24 : 0
                    height: 24
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: stopMouseArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)

                    Behavior on color {
                        ColorAnimation {
                            duration: 90
                            easing.type: Theme.standardEasing
                        }
                    }

                    DankIcon {
                        name: "stop"
                        size: 14
                        color: Theme.error
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: stopMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (daemon) daemon.stopRecording();
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                visible: daemon ? !daemon.isRecording : true
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        root.triggerPopout();
                    } else if (mouse.button === Qt.RightButton) {
                        if (daemon) daemon.startRecording("region");
                    } else if (mouse.button === Qt.MiddleButton) {
                        if (daemon) daemon.startRecording("screen");
                    }
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: Math.max(Theme.iconSizeSmall, vColumn.implicitWidth)
            implicitHeight: vColumn.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                id: vColumn
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Item {
                    id: vIconWrapper
                    readonly property bool spinning: daemon ? daemon.isProcessing : false
                    width: daemon && daemon.isRecording ? root.recordingIconSize : Theme.iconSizeSmall
                    height: width
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: daemon ? (daemon.isRecording ? root.showRecordingDot : true) : true

                    DankIcon {
                        anchors.centerIn: parent
                        name: vIconWrapper.spinning ? "sync" : (daemon && daemon.isRecording ? "fiber_manual_record" : "videocam")
                        size: parent.width
                        color: vIconWrapper.spinning ? Theme.primary : (daemon && daemon.isRecording ? Theme.error : Theme.surfaceText)
                        opacity: (!vIconWrapper.spinning && daemon && daemon.isRecording) ? (blinkRecordDot ? (blinkTimer.blinkOn ? 1.0 : 0.3) : 1.0) : 1.0

                        RotationAnimation on rotation {
                            id: vSpinAnim
                            running: vIconWrapper.spinning
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            onRunningChanged: if (!running) rotation = 0
                        }
                    }
                }

                // Stop button
                Rectangle {
                    visible: daemon ? daemon.isRecording : false
                    width: daemon && daemon.isRecording ? 24 : 0
                    height: 24
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: vStopMouseArea.containsMouse ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.2) : Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1)

                    Behavior on color {
                        ColorAnimation {
                            duration: 90
                            easing.type: Theme.standardEasing
                        }
                    }

                    DankIcon {
                        name: "stop"
                        size: 14
                        color: Theme.error
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: vStopMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (daemon) daemon.stopRecording();
                        }
                    }
                }

                // Pause button
                Rectangle {
                    visible: daemon ? daemon.isRecording : false
                    width: daemon && daemon.isRecording ? 24 : 0
                    height: 24
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: vPauseMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1)

                    Behavior on color {
                        ColorAnimation {
                            duration: 90
                            easing.type: Theme.standardEasing
                        }
                    }

                    DankIcon {
                        name: daemon && daemon.isPaused ? "play_arrow" : "pause"
                        size: 14
                        color: Theme.primary
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: vPauseMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (daemon) daemon.pauseRecording();
                        }
                    }
                }

                StyledText {
                    visible: daemon ? daemon.isRecording : false
                    text: daemon ? daemon.formatDuration(daemon.recordingSeconds).split(':').join('\n') : "00\n00"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                visible: daemon ? !daemon.isRecording : true
                onClicked: (mouse) => {
                    if (mouse.button === Qt.LeftButton) {
                        root.triggerPopout();
                    } else if (mouse.button === Qt.RightButton) {
                        if (daemon) daemon.startRecording("region");
                    } else if (mouse.button === Qt.MiddleButton) {
                        if (daemon) daemon.startRecording("screen");
                    }
                }
            }
        }
    }

    popoutWidth: 380
    popoutHeight: {
        if (daemon && daemon.recordingState !== "idle") return 230;
        if (minimalPopout) {
            let h = 330;
            if (daemon && daemon.recordingMode === "screen" && daemon.monitorsList.length > 2) {
                h += 40;
            }
            return h;
        }
        return daemon && daemon.monitorsList.length > 2 ? 540 : 500;
    }

    popoutContent: Component {
        PopoutComponent {
            id: popoutComp
            headerText: I18n.tr("Screen Recorder")
            detailsText: daemon ? (daemon.recordingState === "starting" ? I18n.tr("Confirm region in portal...") : (daemon.isRecording ? I18n.tr("Recording active") : I18n.tr("Ready to record"))) : ""

            headerActions: Component {
                Rectangle {
                    width: 32
                    height: 32
                    radius: 16
                    color: folderArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "folder_open"
                        size: Theme.iconSize - 4
                        color: folderArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: folderArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (daemon) daemon.openOutputFolder();
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    visible: daemon ? daemon.isRecording : false
                    text: daemon && daemon.isRecording ? 
                          ((daemon.isPaused ? I18n.tr("Paused: ") : I18n.tr("Duration: ")) + daemon.formatDuration(daemon.recordingSeconds)) :
                          ""
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Column {
                    visible: daemon ? (daemon.recordingState !== "idle") : false
                    width: parent.width
                    spacing: Theme.spacingXS
                    anchors.horizontalCenter: parent.horizontalCenter

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingL

                        Row {
                            spacing: Theme.spacingXS
                            DankIcon {
                                name: {
                                    if (!daemon) return "desktop_windows";
                                    if (daemon.recordingMode === "region") return "aspect_ratio";
                                    if (daemon.recordingMode === "portal") return "web_asset";
                                    return "desktop_windows";
                                }
                                size: 16
                                color: Theme.primary
                            }
                            StyledText {
                                text: {
                                    if (!daemon) return "";
                                    if (daemon.recordingMode === "region") return I18n.tr("Region");
                                    if (daemon.recordingMode === "portal") return I18n.tr("Window");
                                    return I18n.tr("Fullscreen");
                                }
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS
                            DankIcon {
                                name: "video_file"
                                size: 16
                                color: Theme.primary
                            }
                            StyledText {
                                text: daemon ? (daemon.videoFormat.toUpperCase() + " (" + daemon.videoCodec.toUpperCase() + ")") : ""
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceText
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingL

                        Row {
                            spacing: Theme.spacingXS
                            DankIcon {
                                name: daemon && daemon.recordAudio ? "volume_up" : "volume_off"
                                size: 16
                                color: daemon && daemon.recordAudio ? Theme.primary : Theme.surfaceVariantText
                                opacity: daemon && daemon.recordAudio ? 1.0 : 0.5
                            }
                            StyledText {
                                text: daemon && daemon.recordAudio ? I18n.tr("System Audio") : I18n.tr("Muted")
                                font.pixelSize: Theme.fontSizeSmall
                                color: daemon && daemon.recordAudio ? Theme.surfaceText : Theme.surfaceVariantText
                            }
                        }

                        Row {
                            spacing: Theme.spacingXS
                            DankIcon {
                                name: daemon && daemon.recordMic ? "mic" : "mic_off"
                                size: 16
                                color: daemon && daemon.recordMic ? Theme.primary : Theme.surfaceVariantText
                                opacity: daemon && daemon.recordMic ? 1.0 : 0.5
                            }
                            StyledText {
                                text: daemon && daemon.recordMic ? I18n.tr("Microphone") : I18n.tr("Muted")
                                font.pixelSize: Theme.fontSizeSmall
                                color: daemon && daemon.recordMic ? Theme.surfaceText : Theme.surfaceVariantText
                            }
                        }
                    }
                }

                // Options Section (Only visible when idle)
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: daemon ? (daemon.recordingState === "idle") : true

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Record System Audio")
                        checked: daemon ? daemon.recordAudio : false
                        onToggled: {
                            if (daemon) daemon.recordAudio = checked;
                        }
                    }

                    SettingsDivider {}

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Record Microphone")
                        checked: daemon ? daemon.recordMic : false
                        onToggled: {
                            if (daemon) daemon.recordMic = checked;
                        }
                    }

                    SettingsDivider {}

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Show Cursor")
                        checked: daemon ? daemon.showCursor : true
                        onToggled: {
                            if (daemon) daemon.showCursor = checked;
                        }
                    }

                    SettingsDivider {
                        visible: !root.minimalPopout
                    }

                    DankToggle {
                        visible: !root.minimalPopout
                        width: parent.width
                        text: I18n.tr("Constant Frame Rate (CFR)")
                        checked: daemon ? daemon.forceCfr : false
                        onToggled: {
                            if (daemon) daemon.forceCfr = checked;
                        }
                    }

                    SettingsDivider {
                        visible: !root.minimalPopout
                    }

                    DankToggle {
                        visible: !root.minimalPopout
                        width: parent.width
                        text: I18n.tr("Low Power Mode")
                        checked: daemon ? daemon.lowPower : false
                        onToggled: {
                            if (daemon) daemon.lowPower = checked;
                        }
                    }

                    SettingsDivider {
                        visible: !root.minimalPopout
                    }

                    DankToggle {
                        visible: !root.minimalPopout
                        width: parent.width
                        text: I18n.tr("GPU Overclock")
                        checked: daemon ? daemon.overclock : false
                        onToggled: {
                            if (daemon) daemon.overclock = checked;
                        }
                    }

                    SettingsDivider {}

                    // Recording Source Mode Selector (Segmented buttons)
                    Item {
                        width: parent.width
                        height: 32

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Source")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            DankButton {
                                text: I18n.tr("Screen")
                                backgroundColor: (daemon && daemon.recordingMode === "screen") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.recordingMode === "screen") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.recordingMode = "screen";
                                }
                            }

                            DankButton {
                                text: I18n.tr("Region")
                                backgroundColor: (daemon && daemon.recordingMode === "region") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.recordingMode === "region") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.recordingMode = "region";
                                }
                            }

                            DankButton {
                                text: I18n.tr("Window")
                                backgroundColor: (daemon && daemon.recordingMode === "portal") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.recordingMode === "portal") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.recordingMode = "portal";
                                }
                            }
                        }
                    }



                    // Monitor Selector (Only visible if multi-monitor detected)
                    Item {
                        width: parent.width
                        height: 32
                        visible: daemon ? (daemon.recordingMode === "screen" && daemon.monitorsList.length > 2) : false

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Monitor")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            Repeater {
                                model: daemon ? daemon.monitorsList : []
                                delegate: Item {
                                    width: btn.width
                                    height: btn.height
                                    required property var modelData

                                    DankButton {
                                        id: btn
                                        text: modelData.value === "all" ? I18n.tr("Auto") : modelData.value
                                        backgroundColor: (daemon && daemon.targetMonitor === modelData.value) ? Theme.primary : Theme.surfaceContainerHigh
                                        textColor: (daemon && daemon.targetMonitor === modelData.value) ? Theme.onPrimary : Theme.surfaceText
                                        buttonHeight: 28
                                        onClicked: {
                                            if (daemon) daemon.targetMonitor = modelData.value;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    SettingsDivider {
                        visible: daemon ? (daemon.recordingMode === "screen" && daemon.monitorsList.length > 2) : false
                    }

                    // Format Selector (Segmented buttons)
                    Item {
                        visible: !root.minimalPopout
                        width: parent.width
                        height: 32

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Format")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            DankButton {
                                text: "MP4"
                                backgroundColor: (daemon && daemon.videoFormat === "mp4") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoFormat === "mp4") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoFormat = "mp4";
                                }
                            }

                            DankButton {
                                text: "MKV"
                                backgroundColor: (daemon && daemon.videoFormat === "mkv") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoFormat === "mkv") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoFormat = "mkv";
                                }
                            }

                            DankButton {
                                text: "WebM"
                                backgroundColor: (daemon && daemon.videoFormat === "webm") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoFormat === "webm") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoFormat = "webm";
                                }
                            }
                        }
                    }

                    SettingsDivider {
                        visible: !root.minimalPopout
                    }

                    // Codec Selector (Segmented buttons)
                    Item {
                        visible: !root.minimalPopout
                        width: parent.width
                        height: 32

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Codec")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            DankButton {
                                text: I18n.tr("Auto")
                                backgroundColor: (daemon && daemon.videoCodec === "auto") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoCodec === "auto") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoCodec = "auto";
                                }
                            }

                            DankButton {
                                text: "H.264"
                                backgroundColor: (daemon && daemon.videoCodec === "h264") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoCodec === "h264") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoCodec = "h264";
                                }
                            }

                            DankButton {
                                text: "HEVC"
                                backgroundColor: (daemon && daemon.videoCodec === "hevc") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoCodec === "hevc") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoCodec = "hevc";
                                }
                            }

                            DankButton {
                                text: "AV1"
                                backgroundColor: (daemon && daemon.videoCodec === "av1") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoCodec === "av1") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoCodec = "av1";
                                }
                            }
                        }
                    }

                    SettingsDivider {}

                    // Quality Selector (Segmented buttons)
                    Item {
                        width: parent.width
                        height: 32

                        StyledText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Quality")
                            color: Theme.surfaceText
                            font.pixelSize: Theme.fontSizeSmall
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingXS

                            DankButton {
                                text: I18n.tr("Med")
                                backgroundColor: (daemon && daemon.videoQuality === "medium") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoQuality === "medium") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoQuality = "medium";
                                }
                            }

                            DankButton {
                                text: I18n.tr("High")
                                backgroundColor: (daemon && daemon.videoQuality === "high") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoQuality === "high") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoQuality = "high";
                                }
                            }

                            DankButton {
                                text: I18n.tr("V.High")
                                backgroundColor: (daemon && daemon.videoQuality === "very_high") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoQuality === "very_high") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoQuality = "very_high";
                                }
                            }

                            DankButton {
                                text: I18n.tr("Ultra")
                                backgroundColor: (daemon && daemon.videoQuality === "ultra") ? Theme.primary : Theme.surfaceContainerHigh
                                textColor: (daemon && daemon.videoQuality === "ultra") ? Theme.onPrimary : Theme.surfaceText
                                buttonHeight: 28
                                onClicked: {
                                    if (daemon) daemon.videoQuality = "ultra";
                                }
                            }
                        }
                    }

                    SettingsDivider {
                        visible: !root.minimalPopout
                    }

                    // Size Estimation Section
                    Item {
                        visible: !root.minimalPopout
                        width: parent.width
                        height: 20

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: {
                                if (!daemon) return "";
                                var w = 1920;
                                var h = 1080;
                                if (daemon.recordingMode === "region" && daemon.regionGeometry) {
                                    var match = daemon.regionGeometry.match(/^(\d+)x(\d+)/);
                                    if (match) {
                                        w = parseInt(match[1]) || 1920;
                                        h = parseInt(match[2]) || 1080;
                                    }
                                } else {
                                    var selectedMonitorObj = null;
                                    for (var i = 0; i < daemon.monitorsList.length; i++) {
                                        if (daemon.monitorsList[i].value === daemon.targetMonitor) {
                                            selectedMonitorObj = daemon.monitorsList[i];
                                            break;
                                        }
                                    }
                                    w = selectedMonitorObj ? selectedMonitorObj.width : (Screen.width || 1920);
                                    h = selectedMonitorObj ? selectedMonitorObj.height : (Screen.height || 1080);
                                }
                                var fps = daemon.framerate || 60;
                                var quality = daemon.videoQuality || "very_high";
                                var codec = daemon.videoCodec || "auto";
                                
                                var pixelRate = w * h * fps;
                                var bppFactor = 0.037;
                                if (quality === "medium") bppFactor = 0.012;
                                else if (quality === "high") bppFactor = 0.020;
                                else if (quality === "very_high") bppFactor = 0.037;
                                else if (quality === "ultra") bppFactor = 0.10;
                                
                                var codecFactor = 1.0;
                                if (codec === "hevc") codecFactor = 0.75;
                                else if (codec === "av1") codecFactor = 0.65;
                                else if (codec === "auto") codecFactor = 0.85;
                                
                                var bitrateBps = pixelRate * bppFactor * codecFactor + 128000;
                                var mbPerMin = (bitrateBps * 60) / 8 / (1024 * 1024);
                                
                                var sizeText = mbPerMin >= 1024 ? 
                                    (mbPerMin / 1024).toFixed(1) + " GB" : 
                                    Math.round(mbPerMin) + " MB";
                                
                                return I18n.tr("Estimated size: ~") + sizeText + I18n.tr(" / minute");
                            }
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall
                        }
                    }

                    SettingsDivider {}
                }

                // --- IDLE STATE BUTTONS ---
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: daemon ? (daemon.recordingState === "idle") : true

                    DankButton {
                        text: I18n.tr("Start Recording")
                        iconName: "videocam"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        buttonHeight: 40
                        anchors.horizontalCenter: parent.horizontalCenter
                        onClicked: {
                            console.log("[ScreenRecorderWidget] Start Recording clicked, calling daemon.startRecording...");
                            if (daemon) daemon.startRecording();
                            popoutComp.closePopout();
                        }
                    }

                    DankButton {
                        visible: daemon ? (daemon.outputPath !== "") : false
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("Preview Last Recording")
                        iconName: "play_circle"
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.primary
                        buttonHeight: 40
                        onClicked: {
                            Quickshell.execDetached(["xdg-open", daemon.outputPath]);
                        }
                    }
                }

                // --- RECORDING STATE BUTTONS ---
                Column {
                    width: parent.width
                    spacing: Theme.spacingS
                    visible: daemon ? (daemon.recordingState !== "idle") : false

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM

                        DankButton {
                            visible: daemon ? (daemon.recordingState === "recording" || daemon.recordingState === "paused") : false
                            text: daemon && daemon.isPaused ? I18n.tr("Resume") : I18n.tr("Pause")
                            iconName: daemon && daemon.isPaused ? "play_arrow" : "pause"
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.surfaceText
                            buttonHeight: 40
                            onClicked: {
                                if (daemon) daemon.pauseRecording();
                            }
                        }

                        DankButton {
                            visible: daemon ? (daemon.recordingState === "recording" || daemon.recordingState === "paused") : false
                            text: I18n.tr("Stop")
                            iconName: "stop"
                            backgroundColor: Theme.error
                            textColor: Theme.surfaceText
                            buttonHeight: 40
                            onClicked: {
                                if (daemon) daemon.stopRecording();
                                popoutComp.closePopout();
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM

                        DankButton {
                            visible: daemon ? (daemon.recordingState === "paused" && daemon.outputPath !== "") : false
                            text: I18n.tr("Preview")
                            iconName: "play_circle"
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.primary
                            buttonHeight: 40
                            onClicked: {
                                Quickshell.execDetached(["xdg-open", daemon.outputPath]);
                            }
                        }

                        DankButton {
                            visible: daemon ? (daemon.recordingState === "starting" || daemon.recordingState === "recording" || daemon.recordingState === "paused") : false
                            text: I18n.tr("Cancel")
                            iconName: "delete"
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.error
                            buttonHeight: 40
                            onClicked: {
                                if (daemon) daemon.cancelRecording();
                                popoutComp.closePopout();
                            }
                        }
                    }
                }
            }
        }
    }
}
