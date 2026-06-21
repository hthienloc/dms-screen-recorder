pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    pluginId: "screenRecorder"
    pluginService: PluginService

    property bool isRecording: false
    property bool isPaused: false
    property int recordingSeconds: 0
    property string outputPath: ""

    // Settings preferences
    readonly property string outputDirectory: pluginData.outputDirectory ?? "~/Videos/Recordings"
    readonly property string videoFormat: pluginData.videoFormat ?? "mp4"
    readonly property bool recordAudio: pluginData.recordAudio ?? false
    readonly property int framerate: {
        var fr = pluginData.framerate ?? "60";
        return parseInt(fr) || 60;
    }


    property bool gpuScreenRecorderMissing: false

    Process {
        id: binaryCheck
        command: ["sh", "-c", "command -v gpu-screen-recorder >/dev/null 2>&1"]
        running: true
        onExited: exitCode => {
            root.gpuScreenRecorderMissing = (exitCode !== 0);
        }
    }

    Timer {
        id: safetyTimer
        interval: 1000
        repeat: false
        onTriggered: {
            if (root.isRecording && !recorderProcess.running) {
                root.isRecording = false;
                root.isPaused = false;
            }
        }
    }
    Timer {
        id: durationTimer
        interval: 1000
        repeat: true
        running: root.isRecording && !root.isPaused
        onTriggered: {
            root.recordingSeconds++;
        }
    }

    // Gpu-screen-recorder process
    Process {
        id: recorderProcess
        running: false
        
        onExited: exitCode => {
            safetyTimer.stop();
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
        if (root.isRecording) return;

        if (root.gpuScreenRecorderMissing) {
            if (typeof ToastService !== "undefined" && ToastService) {
                ToastService.showError(I18n.tr("Screen Recorder"), I18n.tr("gpu-screen-recorder is not installed. Please install it first."));
            }
            return;
        }

        // Resolve home directory
        var homeDir = Quickshell.env("HOME");
        var resolvedDir = root.outputDirectory.replace(/^~/, homeDir);

        // Ensure target directory exists
        Proc.runCommand("screenRecorder.mkdir", ["mkdir", "-p", resolvedDir], (stdout, exitCode) => {
            if (exitCode !== 0) {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.tr("Screen Recorder"), I18n.tr("Failed to create output directory."));
                }
                return;
            }

            root.outputPath = resolvedDir + "/recording_" + getTimestampString() + "." + root.videoFormat;
            
            // Build arguments
            var args = ["gpu-screen-recorder", "-w", "screen", "-f", root.framerate.toString(), "-o", root.outputPath];
            if (root.recordAudio) {
                args.push("-a", "default_output");
            }

            recorderProcess.command = args;
            recorderProcess.running = true;
            
            root.isRecording = true;
            root.isPaused = false;
            root.recordingSeconds = 0;
            
            safetyTimer.restart();

            if (typeof ToastService !== "undefined" && ToastService) {
                ToastService.showInfo(I18n.tr("Screen Recorder"), I18n.tr("Recording started"));
            }
        });
    }

    function pauseRecording() {
        if (!root.isRecording) return;

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
        if (!root.isRecording) return;

        Proc.runCommand("screenRecorder.stop", ["sh", "-c", "killall -CONT gpu-screen-recorder; killall -INT gpu-screen-recorder"]);
        safetyTimer.restart();
    }

    IpcHandler {
        target: "screenRecorder"

        function start(): string {
            if (root.isRecording) return "ALREADY_RECORDING";
            root.startRecording();
            return "STARTED";
        }

        function stop(): string {
            if (!root.isRecording) return "NOT_RECORDING";
            root.stopRecording();
            return "STOPPED";
        }

        function pause(): string {
            if (!root.isRecording) return "NOT_RECORDING";
            if (root.isPaused) return "ALREADY_PAUSED";
            root.pauseRecording();
            return "PAUSED";
        }

        function resume(): string {
            if (!root.isRecording) return "NOT_RECORDING";
            if (!root.isPaused) return "NOT_PAUSED";
            root.pauseRecording();
            return "RESUMED";
        }

        function status(): string {
            return JSON.stringify({
                "isRecording": root.isRecording,
                "isPaused": root.isPaused,
                "duration": root.recordingSeconds,
                "outputPath": root.outputPath
            });
        }
    }

    Component.onCompleted: {
        PluginService.setGlobalVar(pluginId, "instance", root);
    }
}
