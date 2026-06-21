pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    pluginId: "screenRecorder"
    pluginService: PluginService

    readonly property var daemon: PluginService.getGlobalVar(pluginId, "instance")
    readonly property bool blinkRecordDot: pluginData.blinkRecordDot ?? false
    readonly property bool showRecordingDot: pluginData.showRecordingDot ?? true

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
            implicitWidth: daemon && daemon.isRecording ? (recordRow.implicitWidth + Theme.spacingM * 2) : Theme.iconSizeSmall
            implicitHeight: Theme.iconSize
            anchors.verticalCenter: parent.verticalCenter

            Behavior on implicitWidth {
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }

            StyledRect {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: daemon && daemon.isRecording ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1) : "transparent"
                border.color: daemon && daemon.isRecording ? Theme.error : "transparent"
                border.width: daemon && daemon.isRecording ? 1 : 0
            }

            Row {
                id: recordRow
                anchors.centerIn: parent
                spacing: daemon && daemon.isRecording ? (showRecordingDot ? Theme.spacingS : 0) : 0

                DankIcon {
                    visible: daemon ? (daemon.isRecording ? root.showRecordingDot : true) : true
                    name: daemon && daemon.isRecording ? "fiber_manual_record" : "videocam"
                    size: Theme.iconSizeSmall
                    color: daemon && daemon.isRecording ? Theme.error : Theme.surfaceText
                    opacity: daemon && daemon.isRecording ? (blinkRecordDot ? (blinkTimer.blinkOn ? 1.0 : 0.3) : 1.0) : 1.0
                    anchors.verticalCenter: parent.verticalCenter
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
                MouseArea {
                    visible: daemon ? daemon.isRecording : false
                    width: daemon && daemon.isRecording ? Theme.iconSizeSmall : 0
                    height: Theme.iconSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                    cursorShape: Qt.PointingHandCursor
                    
                    DankIcon {
                        name: daemon && daemon.isPaused ? "play_arrow" : "pause"
                        size: Theme.iconSizeSmall
                        color: Theme.primary
                        anchors.centerIn: parent
                    }
                    onClicked: {
                        if (daemon) daemon.pauseRecording();
                    }
                }

                // Stop button
                MouseArea {
                    visible: daemon ? daemon.isRecording : false
                    width: daemon && daemon.isRecording ? Theme.iconSizeSmall : 0
                    height: Theme.iconSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                    cursorShape: Qt.PointingHandCursor

                    DankIcon {
                        name: "stop"
                        size: Theme.iconSizeSmall
                        color: Theme.error
                        anchors.centerIn: parent
                    }
                    onClicked: {
                        if (daemon) daemon.stopRecording();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                visible: daemon ? !daemon.isRecording : true
                onClicked: {
                    root.triggerPopout();
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: Theme.iconSize
            implicitHeight: daemon && daemon.isRecording ? 60 : Theme.iconSizeSmall + Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    visible: daemon ? (daemon.isRecording ? root.showRecordingDot : true) : true
                    name: daemon && daemon.isRecording ? "fiber_manual_record" : "videocam"
                    size: Theme.iconSizeSmall
                    color: daemon && daemon.isRecording ? Theme.error : Theme.surfaceText
                    opacity: daemon && daemon.isRecording ? (blinkRecordDot ? (blinkTimer.blinkOn ? 1.0 : 0.3) : 1.0) : 1.0
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: daemon ? daemon.isRecording : false
                    text: daemon ? daemon.formatDuration(daemon.recordingSeconds) : "00:00"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: "monospace"
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (daemon && daemon.isRecording) {
                        daemon.stopRecording();
                    } else {
                        root.triggerPopout();
                    }
                }
            }
        }
    }

    popoutWidth: 360
    popoutHeight: 180

    popoutContent: Component {
        PopoutComponent {
            id: popoutComp
            headerText: I18n.tr("Screen Recorder")
            detailsText: daemon ? (daemon.recordingState === "starting" ? I18n.tr("Confirm region in portal...") : (daemon.isRecording ? I18n.tr("Recording active") : I18n.tr("Ready to record"))) : ""

            Column {
                width: parent.width
                spacing: Theme.spacingM

                StyledText {
                    text: daemon && daemon.isRecording ? 
                          (daemon.isPaused ? I18n.tr("Paused: ") : I18n.tr("Duration: ")) + daemon.formatDuration(daemon.recordingSeconds) :
                          I18n.tr("Record output will be saved as ") + (daemon ? daemon.videoFormat.toUpperCase() : "")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    // --- IDLE STATE BUTTONS ---
                    DankButton {
                        visible: daemon ? (daemon.recordingState === "idle") : true
                        text: I18n.tr("Screen")
                        iconName: "fullscreen"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        buttonHeight: 40
                        onClicked: {
                            if (daemon) daemon.startRecording("screen");
                            popoutComp.closePopout();
                        }
                    }

                    DankButton {
                        visible: daemon ? (daemon.recordingState === "idle") : true
                        text: I18n.tr("Region/Window")
                        iconName: "aspect_ratio"
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.surfaceText
                        buttonHeight: 40
                        onClicked: {
                            if (daemon) daemon.startRecording("portal");
                            popoutComp.closePopout();
                        }
                    }

                    // --- RECORDING STATE BUTTONS ---
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
