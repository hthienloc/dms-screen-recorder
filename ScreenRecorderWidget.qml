pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
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

    readonly property string currentMicLabel: {
        if (!daemon) return "";
        const list = daemon.audioInputsList;
        const val = daemon.micDevice;
        for (let i = 0; i < list.length; i++) {
            if (list[i].value === val) return list[i].label;
        }
        return val;
    }

    property bool micTesting: false
    property bool _micRecording: false
    property string _micTestFile: ""

    property int micGainValue: daemon ? Math.round(daemon.micBoost * 10) : 20

    function startMicTest() {
        if (root.micTesting || !daemon) return;
        root.micTesting = true;
        root._micRecording = true;

        var micDev = daemon.micDevice || "default_input";
        root._micTestFile = "/tmp/dms_mic_test_" + Date.now() + "_" + Math.floor(Math.random() * 1e9) + ".wav";

        micTestRecord.command = ["pw-record", "--target=" + micDev, "--rate=44100", "--channels=1", root._micTestFile];
        micTestRecord.running = true;
    }

    function stopMicTest() {
        if (!root._micRecording) return;
        root._micRecording = false;
        micTestRecord.running = false;
    }

    Process {
        id: micTestRecord
        running: false
        onExited: exitCode => {
            if (root._micRecording) {
                root._micRecording = false;
                root.micTesting = false;
            } else {
                micTestPlay.command = ["pw-play", root._micTestFile];
                micTestPlay.running = true;
            }
        }
    }

    Process {
        id: micTestPlay
        running: false
        onExited: exitCode => {
            Proc.runCommand("screenRecorderLH.cleanupMicTest", ["rm", "-f", root._micTestFile]);
            root._micTestFile = "";
            root.micTesting = false;
        }
    }

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

                        NumberAnimation on rotation {
                            id: hSpinAnim
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: hIconWrapper.spinning
                        }

                        Behavior on rotation {
                            enabled: !hIconWrapper.spinning
                            NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                        }

                        onRotationChanged: {
                            if (!hIconWrapper.spinning && rotation !== 0)
                                rotation = 0
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

                        NumberAnimation on rotation {
                            id: vSpinAnim
                            from: 0; to: 360
                            duration: 1000
                            loops: Animation.Infinite
                            running: vIconWrapper.spinning
                        }

                        Behavior on rotation {
                            enabled: !vIconWrapper.spinning
                            NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                        }

                        onRotationChanged: {
                            if (!vIconWrapper.spinning && rotation !== 0)
                                rotation = 0
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
        if (daemon && daemon.recordingState !== "idle") return 270;
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

                Rectangle {
                    visible: daemon ? (daemon.recordingState !== "idle") : false
                    width: parent.width
                    height: 140
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.3)
                    border.width: 1
                    border.color: Theme.withAlpha(Theme.primary, 0.15)

                    Grid {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        columns: 2
                        columnSpacing: Theme.spacingM
                        rowSpacing: Theme.spacingS

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: 2
                            Row {
                                spacing: Theme.spacingXS
                                DankIcon { name: "videocam"; size: 14; color: Theme.primary; opacity: 0.8 }
                                StyledText { text: I18n.tr("Video Source"); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 1 }
                            }
                            StyledText {
                                text: {
                                    if (!daemon) return "";
                                    let modeText = "";
                                    if (daemon.recordingMode === "region") modeText = I18n.tr("Region");
                                    else if (daemon.recordingMode === "portal") modeText = I18n.tr("Window");
                                    else modeText = I18n.tr("Fullscreen");
                                    return modeText + " (" + daemon.videoFormat.toUpperCase() + ")";
                                }
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: 2
                            Row {
                                spacing: Theme.spacingXS
                                DankIcon {
                                    name: daemon && daemon.recordAudio ? "volume_up" : "volume_off"
                                    size: 14
                                    color: daemon && daemon.recordAudio ? Theme.primary : Theme.surfaceVariantText
                                    opacity: 0.8
                                }
                                StyledText { text: I18n.tr("System Audio"); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 1 }
                            }
                            StyledText {
                                text: daemon && daemon.recordAudio ? I18n.tr("Recorded") : I18n.tr("Muted")
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: 2
                            Row {
                                spacing: Theme.spacingXS
                                DankIcon {
                                    name: daemon && daemon.showCursor ? "mouse" : "block"
                                    size: 14
                                    color: daemon && daemon.showCursor ? Theme.primary : Theme.surfaceVariantText
                                    opacity: 0.8
                                }
                                StyledText { text: I18n.tr("Show Cursor"); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 1 }
                            }
                            StyledText {
                                text: daemon && daemon.showCursor ? I18n.tr("Yes") : I18n.tr("No")
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: 2
                            Row {
                                spacing: Theme.spacingXS
                                DankIcon {
                                    name: daemon && daemon.recordMic ? "mic" : "mic_off"
                                    size: 14
                                    color: daemon && daemon.recordMic ? Theme.primary : Theme.surfaceVariantText
                                    opacity: 0.8
                                }
                                StyledText { text: I18n.tr("Microphone"); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 1 }
                            }
                            StyledText {
                                text: daemon && daemon.recordMic ? I18n.tr("Recorded") : I18n.tr("Muted")
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
                            }
                        }

                        Column {
                            width: (parent.width - Theme.spacingM) / 2
                            spacing: 2
                            Row {
                                spacing: Theme.spacingXS
                                DankIcon {
                                    name: daemon && daemon.hideWidgets ? "visibility_off" : "visibility"
                                    size: 14
                                    color: daemon && daemon.hideWidgets ? Theme.primary : Theme.surfaceVariantText
                                    opacity: 0.8
                                }
                                StyledText { text: I18n.tr("Desktop Widgets"); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall - 1 }
                            }
                            StyledText {
                                text: daemon && daemon.hideWidgets ? I18n.tr("Hidden") : I18n.tr("Visible")
                                color: Theme.surfaceText
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.DemiBold
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
                            if (daemon) {
                                daemon.recordAudio = checked;
                                pluginService.savePluginData(pluginId, "recordAudio", checked);
                            }
                        }
                    }

                    SettingsDivider {}

                    Column {
                        width: parent.width
                        spacing: Theme.spacingXS

                        DankToggle {
                            width: parent.width
                            text: I18n.tr("Record Microphone")
                            checked: daemon ? daemon.recordMic : false
                            onToggled: {
                                if (daemon) {
                                    daemon.recordMic = checked;
                                    pluginService.savePluginData(pluginId, "recordMic", checked);
                                }
                            }
                        }

                        DankDropdown {
                            width: parent.width
                            compactMode: true
                            visible: daemon ? daemon.recordMic : false
                            currentValue: root.currentMicLabel
                            options: daemon ? daemon.audioInputsList.map(function(item) { return item.label; }) : []
                            onValueChanged: {
                                if (!daemon) return;
                                for (let i = 0; i < daemon.audioInputsList.length; i++) {
                                    if (daemon.audioInputsList[i].label === value) {
                                        daemon.micDevice = daemon.audioInputsList[i].value;
                                        pluginService.savePluginData(pluginId, "micDevice", daemon.audioInputsList[i].value);
                                        break;
                                    }
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: daemon && daemon.recordMic ? testContent.implicitHeight : 0
                            clip: true
                            visible: daemon && daemon.recordMic

                            Column {
                                id: testContent
                                width: parent.width
                                spacing: Theme.spacingS
                                topPadding: Theme.spacingS

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS

                                    DankIcon {
                                        name: AudioService.source && AudioService.source.audio && AudioService.source.audio.muted ? "mic_off" : "mic"
                                        size: 20
                                        color: AudioService.source && AudioService.source.audio && !AudioService.source.audio.muted ? Theme.primary : Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - 28
                                        spacing: 1
                                        StyledText {
                                            text: root.currentMicLabel || I18n.tr("Microphone")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                        StyledText {
                                            text: AudioService.source && AudioService.source.audio && AudioService.source.audio.muted
                                                  ? I18n.tr("Muted in system")
                                                  : I18n.tr("Volume: %1%").arg(Math.round((AudioService.source?.audio?.volume ?? 0) * 100))
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                Item {
                                    width: parent.width
                                    height: 28

                                    StyledText {
                                        id: micGainLabel
                                        text: I18n.tr("Mic Gain")
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceText
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                    }

                                    StyledText {
                                        id: micGainValueText
                                        text: (root.micGainValue / 10).toFixed(1) + "x"
                                        font.pixelSize: Theme.fontSizeSmall
                                        font.weight: Font.DemiBold
                                        color: Theme.primary
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: parent.right
                                    }

                                    DankSliderPlus {
                                        id: micGainSlider
                                        anchors.left: micGainLabel.right
                                        anchors.leftMargin: Theme.spacingS
                                        anchors.right: micGainValueText.left
                                        anchors.rightMargin: Theme.spacingS
                                        anchors.verticalCenter: parent.verticalCenter
                                        height: 24
                                        value: root.micGainValue
                                        minimum: 10
                                        maximum: 50
                                        unit: ""
                                        showValue: false
                                        wheelEnabled: false
                                        thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
                                        onSliderValueChanged: {
                                            if (daemon) {
                                                var gain = Math.round(newValue);
                                                daemon.micBoost = gain / 10;
                                                pluginService.savePluginData(pluginId, "micBoost", gain);
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 36
                                    radius: Theme.cornerRadius
                                    color: root._micRecording ? Theme.primary : (testMicArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer)

                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: Theme.spacingXS
                                        DankIcon {
                                            name: root._micRecording ? "mic" : "mic"
                                            size: 16
                                            color: root._micRecording ? Theme.onPrimary : Theme.primary
                                        }
                                        StyledText {
                                            text: root._micRecording ? I18n.tr("Recording... release to hear") : I18n.tr("Hold to test microphone")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: root._micRecording ? Theme.onPrimary : Theme.primary
                                        }
                                    }

                                    MouseArea {
                                        id: testMicArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPressed: root.startMicTest()
                                        onReleased: root.stopMicTest()
                                        onCanceled: root.stopMicTest()
                                    }
                                }
                            }
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

                    DankToggle {
                        width: parent.width
                        text: I18n.tr("Hide Desktop Widgets")
                        checked: daemon ? daemon.hideWidgets : false
                        onToggled: {
                            if (daemon) {
                                pluginService.savePluginData(pluginId, "hideWidgetsDuringRecording", checked);
                                if (daemon.isRecording) {
                                    if (checked) daemon.hideDesktopWidgets();
                                    else daemon.restoreDesktopWidgets();
                                }
                            }
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
                            backgroundColor: Theme.primary
                            textColor: Theme.onPrimary
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

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.spacingM
                        visible: daemon ? (daemon.recordingState === "paused" && daemon.outputPath !== "") : false

                        DankButton {
                            text: I18n.tr("Preview")
                            iconName: "play_circle"
                            backgroundColor: Theme.surfaceContainerHigh
                            textColor: Theme.primary
                            buttonHeight: 40
                            onClicked: {
                                Quickshell.execDetached(["xdg-open", daemon.outputPath]);
                            }
                        }
                    }
                }
            }
        }
    }
}
