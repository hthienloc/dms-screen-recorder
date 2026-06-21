import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    property bool isRecording: false
    property bool isPaused: false
    property int recordingSeconds: 0
    property string outputPath: ""

    // Settings preferences
    readonly property string outputDirectory: pluginData.outputDirectory ?? "~/Videos/Recordings"
    readonly property string videoFormat: pluginData.videoFormat ?? "mp4"
    readonly property bool recordAudio: pluginData.recordAudio ?? false
    readonly property int framerate: pluginData.framerate ?? 60

    readonly property bool isDaemonInstance: root.parent !== null
    readonly property var masterInstance: isDaemonInstance ? root : PluginService.getGlobalVar(pluginId, "instance")

    pluginId: "screenRecorder"
    pluginService: PluginService

    // Blinking Timer for recording dot
    Timer {
        id: blinkTimer
        interval: 1000
        repeat: true
        running: masterInstance ? (masterInstance.isRecording && !masterInstance.isPaused) : false
        property bool blinkOn: true
        onTriggered: blinkOn = !blinkOn
    }

    // Recording duration timer
    Timer {
        id: durationTimer
        interval: 1000
        repeat: true
        running: isDaemonInstance && isRecording && !isPaused
        onTriggered: {
            recordingSeconds++;
        }
    }

    // Gpu-screen-recorder process
    Process {
        id: recorderProcess
        running: false
        
        onExited: exitCode => {
            if (isDaemonInstance) {
                root.isRecording = false;
                root.isPaused = false;
                
                if (exitCode === 0) {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showInfo(I18n.tr("Screen Recorder"), I18n.tr("Recording saved to: ") + root.outputPath);
                    }
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError(I18n.tr("Screen Recorder"), I18n.tr("Recording failed with exit code: ") + exitCode);
                    }
                }
            }
        }
    }

    function formatDuration(totalSeconds) {
        var m = Math.floor(totalSeconds / 60);
        var s = totalSeconds % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function getTimestampString() {
        var now = new Date();
        var yyyy = now.getFullYear();
        var mm = now.getMonth() + 1;
        var dd = now.getDate();
        var hh = now.getHours();
        var min = now.getMinutes();
        var ss = now.getSeconds();
        
        return yyyy + (mm < 10 ? "0" : "") + mm + (dd < 10 ? "0" : "") + dd + "_" +
               (hh < 10 ? "0" : "") + hh + (min < 10 ? "0" : "") + min + (ss < 10 ? "0" : "") + ss;
    }

    function startRecording() {
        if (isRecording) return;

        if (!isDaemonInstance) {
            const daemon = PluginService.pluginInstances["screenRecorder"];
            if (daemon) {
                daemon.startRecording();
            }
            return;
        }

        // Resolve home directory
        var homeDir = Quickshell.env("HOME");
        var resolvedDir = outputDirectory.replace(/^~/, homeDir);

        // Ensure target directory exists
        Proc.runCommand("screenRecorder.mkdir", ["mkdir", "-p", resolvedDir], (stdout, exitCode) => {
            if (exitCode !== 0) {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.tr("Screen Recorder"), I18n.tr("Failed to create output directory."));
                }
                return;
            }

            root.outputPath = resolvedDir + "/recording_" + getTimestampString() + "." + videoFormat;
            
            // Build arguments
            var args = ["gpu-screen-recorder", "-w", "screen", "-f", framerate.toString(), "-o", root.outputPath];
            if (recordAudio) {
                args.push("-a", "default_output");
            }

            recorderProcess.command = args;
            recorderProcess.running = true;
            
            root.isRecording = true;
            root.isPaused = false;
            root.recordingSeconds = 0;
            
            if (typeof ToastService !== "undefined" && ToastService) {
                ToastService.showInfo(I18n.tr("Screen Recorder"), I18n.tr("Recording started"));
            }
        });
    }

    function pauseRecording() {
        if (!isRecording) return;

        if (!isDaemonInstance) {
            const daemon = PluginService.pluginInstances["screenRecorder"];
            if (daemon) {
                daemon.pauseRecording();
            }
            return;
        }

        root.isPaused = !root.isPaused;
        
        var signal = root.isPaused ? "-STOP" : "-CONT";
        Proc.runCommand("screenRecorder.signal", ["killall", signal, "gpu-screen-recorder"], (stdout, exitCode) => {
            if (typeof ToastService !== "undefined" && ToastService) {
                if (root.isPaused) {
                    ToastService.showInfo(I18n.tr("Screen Recorder"), I18n.tr("Recording paused"));
                } else {
                    ToastService.showInfo(I18n.tr("Screen Recorder"), I18n.tr("Recording resumed"));
                }
            }
        });
    }

    function stopRecording() {
        if (!isRecording) return;

        if (!isDaemonInstance) {
            const daemon = PluginService.pluginInstances["screenRecorder"];
            if (daemon) {
                daemon.stopRecording();
            }
            return;
        }

        Proc.runCommand("screenRecorder.stop", ["killall", "-SIGINT", "gpu-screen-recorder"]);
    }

    // CC integration
    ccWidgetIcon: "videocam"
    ccWidgetPrimaryText: I18n.tr("Screen Recorder")
    ccWidgetSecondaryText: {
        const master = masterInstance;
        if (!master) return I18n.tr("Idle");
        if (master.isRecording) {
            return (master.isPaused ? I18n.tr("Paused: ") : I18n.tr("Recording: ")) + formatDuration(master.recordingSeconds);
        }
        return I18n.tr("Idle");
    }
    ccWidgetIsActive: masterInstance ? masterInstance.isRecording : false
    onCcWidgetToggled: {
        const master = masterInstance;
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
            implicitWidth: masterInstance && masterInstance.isRecording ? (recordRow.implicitWidth + Theme.spacingM * 2) : (Theme.iconSizeSmall + Theme.spacingM * 2)
            implicitHeight: Theme.iconSize
            anchors.verticalCenter: parent.verticalCenter

            Behavior on implicitWidth {
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }

            StyledRect {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: masterInstance && masterInstance.isRecording ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.1) : "transparent"
                border.color: masterInstance && masterInstance.isRecording ? Theme.error : "transparent"
                border.width: masterInstance && masterInstance.isRecording ? 1 : 0
            }

            Row {
                id: recordRow
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DankIcon {
                    name: "fiber_manual_record"
                    size: Theme.iconSizeSmall
                    color: masterInstance && masterInstance.isRecording ? Theme.error : Theme.surfaceText
                    opacity: masterInstance && masterInstance.isRecording ? (blinkTimer.blinkOn ? 1.0 : 0.3) : 1.0
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    visible: masterInstance ? masterInstance.isRecording : false
                    text: masterInstance ? formatDuration(masterInstance.recordingSeconds) : "00:00"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Pause button
                MouseArea {
                    visible: masterInstance ? masterInstance.isRecording : false
                    width: Theme.iconSizeSmall
                    height: Theme.iconSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                    cursorShape: Qt.PointingHandCursor
                    
                    DankIcon {
                        name: masterInstance && masterInstance.isPaused ? "play_arrow" : "pause"
                        size: Theme.iconSizeSmall
                        color: Theme.primary
                        anchors.centerIn: parent
                    }
                    onClicked: {
                        if (masterInstance) masterInstance.pauseRecording();
                    }
                }

                // Stop button
                MouseArea {
                    visible: masterInstance ? masterInstance.isRecording : false
                    width: Theme.iconSizeSmall
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
                        if (masterInstance) masterInstance.stopRecording();
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.PointingHandCursor
                visible: masterInstance ? !masterInstance.isRecording : true
                onClicked: {
                    root.triggerPopout();
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: Theme.iconSize
            implicitHeight: masterInstance && masterInstance.isRecording ? 60 : Theme.iconSizeSmall + Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: masterInstance && masterInstance.isRecording ? "fiber_manual_record" : "videocam"
                    size: Theme.iconSizeSmall
                    color: masterInstance && masterInstance.isRecording ? Theme.error : Theme.surfaceText
                    opacity: masterInstance && masterInstance.isRecording ? (blinkTimer.blinkOn ? 1.0 : 0.3) : 1.0
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    visible: masterInstance ? masterInstance.isRecording : false
                    text: masterInstance ? formatDuration(masterInstance.recordingSeconds) : "00:00"
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeExtraSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (masterInstance && masterInstance.isRecording) {
                        masterInstance.stopRecording();
                    } else {
                        root.triggerPopout();
                    }
                }
            }
        }
    }

    popoutWidth: 320
    popoutHeight: 180

    popoutContent: Component {
        PopoutComponent {
            headerText: I18n.tr("Screen Recorder")
            detailsText: masterInstance && masterInstance.isRecording ? I18n.tr("Recording active") : I18n.tr("Ready to record")

            Column {
                width: parent.width
                spacing: Theme.spacingM
                anchors.centerIn: parent

                StyledText {
                    text: masterInstance && masterInstance.isRecording ? 
                          (masterInstance.isPaused ? I18n.tr("Paused: ") : I18n.tr("Duration: ")) + formatDuration(masterInstance.recordingSeconds) :
                          I18n.tr("Record output will be saved as ") + root.videoFormat.toUpperCase()
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.spacingM

                    DankButton {
                        visible: masterInstance ? !masterInstance.isRecording : true
                        text: I18n.tr("Start Recording")
                        iconName: "fiber_manual_record"
                        backgroundColor: Theme.primary
                        textColor: Theme.onPrimary
                        buttonHeight: 40
                        onClicked: {
                            if (masterInstance) masterInstance.startRecording();
                            root.closePopout();
                        }
                    }

                    DankButton {
                        visible: masterInstance ? masterInstance.isRecording : false
                        text: masterInstance && masterInstance.isPaused ? I18n.tr("Resume") : I18n.tr("Pause")
                        iconName: masterInstance && masterInstance.isPaused ? "play_arrow" : "pause"
                        backgroundColor: Theme.surfaceContainerHigh
                        textColor: Theme.surfaceText
                        buttonHeight: 40
                        onClicked: {
                            if (masterInstance) masterInstance.pauseRecording();
                        }
                    }

                    DankButton {
                        visible: masterInstance ? masterInstance.isRecording : false
                        text: I18n.tr("Stop")
                        iconName: "stop"
                        backgroundColor: Theme.error
                        textColor: Theme.surfaceText
                        buttonHeight: 40
                        onClicked: {
                            if (masterInstance) masterInstance.stopRecording();
                            root.closePopout();
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "screenRecorder"

        function start(): string {
            if (masterInstance) {
                if (masterInstance.isRecording) return "ALREADY_RECORDING";
                masterInstance.startRecording();
                return "STARTED";
            }
            return "ERROR";
        }

        function stop(): string {
            if (masterInstance) {
                if (!masterInstance.isRecording) return "NOT_RECORDING";
                masterInstance.stopRecording();
                return "STOPPED";
            }
            return "ERROR";
        }

        function pause(): string {
            if (masterInstance) {
                if (!masterInstance.isRecording) return "NOT_RECORDING";
                if (masterInstance.isPaused) return "ALREADY_PAUSED";
                masterInstance.pauseRecording();
                return "PAUSED";
            }
            return "ERROR";
        }

        function resume(): string {
            if (masterInstance) {
                if (!masterInstance.isRecording) return "NOT_RECORDING";
                if (!masterInstance.isPaused) return "NOT_PAUSED";
                masterInstance.pauseRecording();
                return "RESUMED";
            }
            return "ERROR";
        }

        function status(): string {
            if (masterInstance) {
                return JSON.stringify({
                    "isRecording": masterInstance.isRecording,
                    "isPaused": masterInstance.isPaused,
                    "duration": masterInstance.recordingSeconds,
                    "outputPath": masterInstance.outputPath
                });
            }
            return "ERROR";
        }
    }

    onPluginIdChanged: {
        if (isDaemonInstance && pluginId !== "") {
            PluginService.setGlobalVar(pluginId, "instance", root);
        }
    }

    Component.onCompleted: {
        if (isDaemonInstance) {
            if (pluginId !== "") {
                PluginService.setGlobalVar(pluginId, "instance", root);
            }
        }
    }
}
