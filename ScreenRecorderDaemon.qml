pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins

PluginComponent {
    id: root

    pluginId: "screenRecorderLH"
    pluginService: PluginService

    property bool isRecording: false
    property bool isPaused: false
    property bool isProcessing: false
    property int recordingSeconds: 0
    property string outputPath: ""
    property string recordingState: "idle" // "idle", "starting", "recording", "paused"
    property bool isCancelling: false

    // Settings preferences
    property string outputDirectory: pluginData.outputDirectory ?? "~/Videos/Recordings"
    property string videoFormat: pluginData.videoFormat ?? "mp4"
    property bool recordAudio: pluginData.recordAudio ?? false
    property bool showCursor: pluginData.showCursor ?? true
    property string videoQuality: pluginData.videoQuality ?? "very_high"
    property bool forceCfr: pluginData.forceCfr ?? false
    property bool lowPower: pluginData.lowPower ?? false
    property string videoCodec: pluginData.videoCodec ?? "auto"
    property bool overclock: pluginData.overclock ?? false
    property string encoderTune: pluginData.encoderTune ?? "performance"
    property string colorRange: pluginData.colorRange ?? "full"
    property string audioCodec: pluginData.audioCodec ?? "opus"
    property string postRecordCommand: pluginData.postRecordCommand ?? ""
    property string compressVideo: pluginData.compressVideo ?? "disabled"
    property string targetResolution: pluginData.targetResolution ?? "original"
    property int maxTargetSize: {
        var size = pluginData.maxTargetSize ?? 0;
        return parseInt(size) || 0;
    }
    property int framerate: {
        var fr = pluginData.framerate ?? 60;
        return parseInt(fr) || 60;
    }
    property string postNotification: pluginData.postNotification ?? "notification"
    property bool openVideoOnFinish: pluginData.openVideoOnFinish ?? false
    property string targetMonitor: pluginData.targetMonitor ?? "all"
    property string recordingMode: pluginData.recordingMode ?? "screen"
    property string regionGeometry: pluginData.regionGeometry ?? "1028x768+100+100"
    property var monitorsList: [{"label": I18n.tr("First Monitor Found"), "value": "all", "width": 1920, "height": 1080}]
    property bool recordMic: pluginData.recordMic ?? false
    property string micDevice: pluginData.micDevice ?? "default_input"
    property string systemAudioDevice: pluginData.systemAudioDevice ?? "default_output"
    property real micBoost: {
        var val = pluginData.micBoost;
        if (val === undefined || val === null) return 2.0;
        var num = parseFloat(val);
        if (isNaN(num)) return 2.0;
        return num / 10;
    }
    property var audioInputsList: [{"label": I18n.tr("Default Microphone"), "value": "default_input"}]
    property var audioOutputsList: [{"label": I18n.tr("Default Output"), "value": "default_output"}]

    property string activeRecordingMode: ""
    property int _recordedAudioCount: 0
    property int regionX: 0
    property int regionY: 0
    property int regionW: 0
    property int regionH: 0

    onRegionGeometryChanged: {
        var match = regionGeometry.match(/^(\d+)x(\d+)\+(\d+)\+(\d+)/);
        if (match) {
            regionW = parseInt(match[1]) || 0;
            regionH = parseInt(match[2]) || 0;
            regionX = parseInt(match[3]) || 0;
            regionY = parseInt(match[4]) || 0;
        }
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
        interval: 15000 // wait longer for portal confirmation
        repeat: false
        onTriggered: {
            if (root.recordingState === "starting" || (root.isRecording && !recorderProcess.running)) {
                fileCheckTimer.stop();
                root.recordingState = "idle";
                root.isRecording = false;
                root.isPaused = false;
                root.activeRecordingMode = "";
            }
        }
    }

    Timer {
        id: fileCheckTimer
        interval: 300
        repeat: true
        running: root.recordingState === "starting"
        onTriggered: {
            Proc.runCommand("screenRecorder.checkFile", ["test", "-s", root.outputPath], (stdout, exitCode) => {
                if (exitCode === 0) {
                    fileCheckTimer.stop();
                    root.recordingState = "recording";
                    root.isRecording = true;
                    root.isPaused = false;
                    root.recordingSeconds = 0;
                }
            });
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
            const prevMode = root.activeRecordingMode;
            const prevState = root.recordingState;

            safetyTimer.stop();
            fileCheckTimer.stop();
            root.recordingState = "idle";
            root.isRecording = false;
            root.isPaused = false;
            root.activeRecordingMode = "";

            if (root.isCancelling) {
                // Delete the partial/finalized file and suppress notification
                if (root.outputPath) {
                    Proc.runCommand("screenRecorderLH.cancel", ["rm", "-f", root.outputPath]);
                }
                root.isCancelling = false;
                root.outputPath = "";
                return;
            }

            if (exitCode === 0) {
                const videoPath = root.outputPath.replace(/^file:\/\//, "");
                root.performPostProcessing(videoPath);
            } else {
                if ((prevMode === "portal" || prevMode === "window") && prevState === "starting") {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showWarning(I18n.tr("Screen Recorder"), I18n.tr("Window selection canceled."));
                    }
                    if (root.outputPath) {
                        Proc.runCommand("screenRecorderLH.cancel", ["rm", "-f", root.outputPath]);
                    }
                } else {
                    root.sendFinishedNotification(true, I18n.tr("Recording failed with exit code: ") + exitCode);
                }
            }
        }
    }

    function sendFinishedNotification(isError, message, thumbPath) {
        const mode = root.postNotification;
        if (mode === "none") return;

        // Toast Notification
        if (mode === "toast" || mode === "both") {
            if (typeof ToastService !== "undefined" && ToastService) {
                if (isError) {
                    ToastService.showError(I18n.tr("Screen Recorder"), message);
                } else {
                    ToastService.showInfo(I18n.tr("Screen Recorder"), message);
                }
            }
        }

        // System Notification
        if (mode === "notification" || mode === "both") {
            let icon = isError ? "error" : "video-x-generic";
            if (!isError) {
                if (thumbPath) {
                    icon = thumbPath;
                } else if (root.outputPath) {
                    icon = root.outputPath.replace(/^file:\/\//, "");
                }
            }
            const title = isError ? I18n.tr("Screen Recorder Error") : I18n.tr("Screen Recorder");
            const args = ["notify-send", "-a", "Screen Recorder", "-i", icon, title, message];
            if (isError) {
                args.push("-u", "critical");
            }
            Proc.runCommand("screen-recorder-notify", args);
        }
    }

    function _applyMicBoost(videoPath) {
        root.isProcessing = true;
        var ext = root.videoFormat;
        var tempOut = videoPath + ".boosted." + ext;
        var boost = root.micBoost;

        var ffmpegArgs = ["ffmpeg", "-y", "-i", videoPath,
            "-filter:a", "volume=" + boost,
            "-map", "0:v", "-map", "0:a", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", tempOut];

        console.log("[ScreenRecorderDaemon] Applying mic boost: " + ffmpegArgs.join(" "));

        Proc.runCommand("screenRecorderLH.applyMicBoost", ffmpegArgs, (stdout, exitCode) => {
            if (exitCode === 0) {
                Proc.runCommand("screenRecorderLH.replaceBoosted", ["mv", "-f", tempOut, videoPath], () => {
                    root.performPostProcessing(videoPath);
                });
            } else {
                console.log("[ScreenRecorderDaemon] Mic boost failed, using original");
                Proc.runCommand("screenRecorderLH.cleanupTemp", ["rm", "-f", tempOut]);
                root.performPostProcessing(videoPath);
            }
        });
    }

    function _mergeAudio(videoPath) {
        root.isProcessing = true;
        var ext = root.videoFormat;
        var tempOut = videoPath + ".audio_merged." + ext;

        var boost = root.micBoost;
        var ffmpegArgs = ["ffmpeg", "-y", "-i", videoPath,
            "-filter_complex", "[0:a:0]anull[a0];[0:a:1]volume=" + boost + "[a1];[a0][a1]amix=inputs=2:duration=first:normalize=0[a]",
            "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", tempOut];

        console.log("[ScreenRecorderDaemon] Merging audio tracks: " + ffmpegArgs.join(" "));

        Proc.runCommand("screenRecorderLH.mergeAudio", ffmpegArgs, (stdout, exitCode) => {
            if (exitCode === 0) {
                Proc.runCommand("screenRecorderLH.replaceMerged", ["mv", "-f", tempOut, videoPath], () => {
                    root._recordedAudioCount = 1;
                    root.performPostProcessing(videoPath);
                });
            } else {
                console.log("[ScreenRecorderDaemon] Audio merge failed, using original");
                Proc.runCommand("screenRecorderLH.cleanupTemp", ["rm", "-f", tempOut]);
                root.performPostProcessing(videoPath);
            }
        });
    }

    function performPostProcessing(videoPath) {
        if (root._recordedAudioCount > 1) {
            root._mergeAudio(videoPath);
            return;
        }

        if (root._recordedAudioCount === 1 && root.recordMic && root.micBoost !== 1.0) {
            root._applyMicBoost(videoPath);
            return;
        }

        var needsCompression = (root.compressVideo !== "disabled");
        var needsScaling = (root.targetResolution !== "original");
        
        if (!needsCompression && !needsScaling) {
            root.finalizeRecording(videoPath);
            return;
        }

        root.isProcessing = true;

        var ffmpegArgs = ["ffmpeg", "-y", "-i", videoPath];

        if (needsScaling) {
            if (root.targetResolution === "1080p") {
                ffmpegArgs.push("-vf", "scale=-2:1080");
            } else if (root.targetResolution === "720p") {
                ffmpegArgs.push("-vf", "scale=-2:720");
            } else if (root.targetResolution === "480p") {
                ffmpegArgs.push("-vf", "scale=-2:480");
            }
        }

        var codec = "libx264";
        var crf = "23";
        if (root.compressVideo === "hevc") {
            codec = "libx265";
            crf = "26";
        } else if (root.compressVideo === "av1") {
            codec = "libsvtav1";
            crf = "30";
        }
        ffmpegArgs.push("-c:v", codec);

        if (root.maxTargetSize > 0) {
            var duration = Math.max(1, root.recordingSeconds);
            var targetBitrateKbps = Math.round((root.maxTargetSize * 8192) / duration);
            var videoBitrate = Math.max(100, targetBitrateKbps - 128);
            ffmpegArgs.push("-b:v", videoBitrate + "k", "-maxrate", Math.round(videoBitrate * 1.5) + "k", "-bufsize", (videoBitrate * 2) + "k");
        } else {
            ffmpegArgs.push("-crf", crf);
        }

        ffmpegArgs.push("-c:a", "copy");

        var ext = root.videoFormat;
        var tempOut = videoPath + ".tmp." + ext;
        ffmpegArgs.push(tempOut);

        console.log("[ScreenRecorderDaemon] Spawning FFmpeg compression process: " + ffmpegArgs.join(" "));

        Proc.runCommand("screenRecorderLH.compress", ffmpegArgs, (stdout, exitCode) => {
            if (exitCode === 0) {
                Proc.runCommand("screenRecorderLH.replaceOriginal", ["mv", "-f", tempOut, videoPath], (mvStdout, mvExitCode) => {
                    root.finalizeRecording(videoPath);
                });
            } else {
                console.log("[ScreenRecorderDaemon] FFmpeg compression failed with code: " + exitCode);
                Proc.runCommand("screenRecorderLH.cleanupTemp", ["rm", "-f", tempOut]);
                root.finalizeRecording(videoPath);
            }
        });
    }

    function finalizeRecording(videoPath) {
        const thumbPath = "/tmp/dms_screen_recorder_thumb.png";
        Proc.runCommand("screenRecorderLH.extractThumb", ["ffmpeg", "-y", "-i", videoPath, "-ss", "00:00:00", "-frames:v", "1", thumbPath], (stdout, extractExitCode) => {
            const useThumb = (extractExitCode === 0);
            root.sendFinishedNotification(false, I18n.tr("Recording saved to: ") + videoPath, useThumb ? thumbPath : "");
            root.isProcessing = false;
        });

        if (root.postRecordCommand && root.postRecordCommand.trim() !== "") {
            const safePath = "'" + videoPath.replace(/'/g, "'\\''") + "'";
            const cmdStr = root.postRecordCommand.replace(/\$1/g, safePath);
            console.log("[ScreenRecorderDaemon] Executing post-record command: " + cmdStr);
            Proc.runCommand("screenRecorderLH.postRecordCommand", ["sh", "-c", cmdStr]);
        }

        if (root.openVideoOnFinish) {
            console.log("[ScreenRecorderDaemon] Opening video: " + videoPath);
            Quickshell.execDetached(["xdg-open", videoPath]);
        }
    }

    function openOutputFolder() {
        const homeDir = Quickshell.env("HOME");
        const dir = root.outputDirectory.replace(/^~/, homeDir);
        Proc.runCommand("screenRecorderLH.openFolder", ["bash", "-c", "xdg-open '" + dir + "'"], null, 0);
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

    Timer {
        id: recordingDelayTimer
        interval: 150
        repeat: false
        property string sourceType: ""
        onTriggered: {
            root.startRecordingDirect(sourceType);
        }
    }

    function startRecording(sourceType) {
        if (root.recordingState !== "idle") return;
        recordingDelayTimer.sourceType = sourceType || "";
        recordingDelayTimer.start();
    }

    function startRecordingDirect(sourceType) {
        if (root.recordingState !== "idle") return;

        if (root.gpuScreenRecorderMissing) {
            if (typeof ToastService !== "undefined" && ToastService) {
                ToastService.showError(I18n.tr("Screen Recorder"), I18n.tr("gpu-screen-recorder is not installed. Please install it first."));
            }
            return;
        }

        var activeMode = sourceType || root.recordingMode;
        console.log("[ScreenRecorderDaemon] startRecording called, activeMode: " + activeMode);
        if (!root.showCursor && (activeMode === "window" || activeMode === "portal")) {
            if (typeof ToastService !== "undefined" && ToastService) {
                ToastService.showWarning(I18n.tr("Screen Recorder"), I18n.tr("Hiding cursor may not work in Region/Window mode on Wayland due to compositor limitations."));
            }
        }

        if (activeMode === "region") {
            console.log("[ScreenRecorderDaemon] triggering slurp via detached process...");
            Quickshell.execDetached([
                "bash",
                "-c",
                "rm -f /tmp/dms_slurp_geom.txt; slurp -f '%wx%h+%x+%y' > /tmp/dms_slurp_geom.txt && dms ipc screenRecorderLH slurpSuccess || dms ipc screenRecorderLH slurpCanceled"
            ]);
        } else {
            root.proceedToRecord(activeMode, "");
        }
    }

    function selectRegionInteractive() {
        console.log("[ScreenRecorderDaemon] triggering slurp interactive via detached process...");
        Quickshell.execDetached([
            "bash",
            "-c",
            "rm -f /tmp/dms_slurp_geom.txt; slurp -f '%wx%h+%x+%y' > /tmp/dms_slurp_geom.txt && dms ipc screenRecorderLH slurpInteractiveSuccess || dms ipc screenRecorderLH slurpInteractiveCanceled"
        ]);
    }

    function proceedToRecord(activeMode, geom) {
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
            var source = "";
            var reg = "";
            if (activeMode === "window" || activeMode === "portal") {
                source = "portal";
            } else if (activeMode === "region") {
                source = "region";
                reg = geom || root.regionGeometry;
            } else {
                source = (root.targetMonitor === "all" ? "screen" : root.targetMonitor);
            }
            
            var args = ["gpu-screen-recorder", "-w", source];
            if (reg !== "") {
                args.push("-region", reg);
            }
            args.push("-f", root.framerate.toString(), "-o", root.outputPath);
            args.push("-cursor", root.showCursor ? "yes" : "no");
            var hasAudio = false;
            root._recordedAudioCount = 0;
            if (root.recordAudio) {
                args.push("-a", root.systemAudioDevice || "default_output");
                hasAudio = true;
                root._recordedAudioCount++;
            }
            if (root.recordMic) {
                args.push("-a", root.micDevice || "default_input");
                hasAudio = true;
                root._recordedAudioCount++;
            }
            if (hasAudio) {
                args.push("-ac", root.audioCodec);
            }
            
            // Video Quality (-q)
            args.push("-q", root.videoQuality);
            
            // Constant Frame Rate (-fm cfr)
            if (root.forceCfr) {
                args.push("-fm", "cfr");
            }
            
            // Low Power Mode (-low-power yes/no)
            args.push("-low-power", root.lowPower ? "yes" : "no");
            
            // Video Codec (-k)
            if (root.videoCodec !== "auto") {
                args.push("-k", root.videoCodec);
            }

            // GPU Overclock (-oc yes/no)
            args.push("-oc", root.overclock ? "yes" : "no");

            // Encoder Tuning (-tune performance/quality)
            args.push("-tune", root.encoderTune);

            // Color Range (-cr limited/full)
            args.push("-cr", root.colorRange);

            recorderProcess.command = args;
            recorderProcess.running = true;
            
            root.recordingState = "starting";
            root.activeRecordingMode = activeMode;
            
            safetyTimer.interval = (activeMode === "portal" || activeMode === "window") ? 120000 : 15000;
            safetyTimer.restart();
        });
    }

    function pauseRecording() {
        if (!root.isRecording) return;

        root.isPaused = !root.isPaused;
        root.recordingState = root.isPaused ? "paused" : "recording";
        
        var signal = root.isPaused ? "-STOP" : "-CONT";
        Proc.runCommand("screenRecorder.signal", ["killall", signal, "gpu-screen-recorder"]);
    }

    function stopRecording() {
        if (!root.isRecording) return;

        Proc.runCommand("screenRecorder.stop", ["sh", "-c", "killall -CONT gpu-screen-recorder; killall -INT gpu-screen-recorder"]);
        safetyTimer.restart();
    }

    function cancelRecording() {
        if (root.recordingState === "idle") return;

        root.isCancelling = true;
        safetyTimer.stop();
        fileCheckTimer.stop();
        root.recordingState = "idle";
        root.isRecording = false;
        root.isPaused = false;
        root.activeRecordingMode = "";

        // SIGKILL prevents gpu-screen-recorder from finalizing the file;
        // file deletion happens in onExited after process is confirmed dead.
        Proc.runCommand("screenRecorderLH.kill", ["killall", "-KILL", "gpu-screen-recorder"]);
    }

    IpcHandler {
        target: "screenRecorderLH"

        function start(sourceType: string): string {
            if (root.isRecording) return "ALREADY_RECORDING";
            root.startRecording(sourceType);
            return "STARTED";
        }

        function startScreen(): string {
            if (root.isRecording) return "ALREADY_RECORDING";
            root.startRecording("screen");
            return "STARTED";
        }

        function startRegion(): string {
            if (root.isRecording) return "ALREADY_RECORDING";
            root.startRecording("region");
            return "STARTED";
        }

        function startPortal(): string {
            if (root.isRecording) return "ALREADY_RECORDING";
            root.startRecording("portal");
            return "STARTED";
        }

        function toggle(sourceType: string): string {
            if (root.isRecording) {
                root.stopRecording();
                return "STOPPED";
            } else {
                root.startRecording(sourceType);
                return "STARTED";
            }
        }

        function toggleScreen(): string {
            if (root.isRecording) {
                root.stopRecording();
                return "STOPPED";
            } else {
                root.startRecording("screen");
                return "STARTED";
            }
        }

        function toggleRegion(): string {
            if (root.isRecording) {
                root.stopRecording();
                return "STOPPED";
            } else {
                root.startRecording("region");
                return "STARTED";
            }
        }

        function togglePortal(): string {
            if (root.isRecording) {
                root.stopRecording();
                return "STOPPED";
            } else {
                root.startRecording("portal");
                return "STARTED";
            }
        }

        function startSavedRegion(): string {
            if (root.isRecording) return "ALREADY_RECORDING";
            
            var geom = root.regionGeometry;
            var match = geom.match(/^(\d+)x(\d+)\+(\d+)\+(\d+)/);
            if (match) {
                var w = parseInt(match[1]) || 0;
                var h = parseInt(match[2]) || 0;
                var x = parseInt(match[3]) || 0;
                var y = parseInt(match[4]) || 0;
                
                if (w % 2 !== 0) w--;
                if (h % 2 !== 0) h--;
                
                if (w < 2) w = 2;
                if (h < 2) h = 2;
                
                geom = w + "x" + h + "+" + x + "+" + y;
                root.regionGeometry = geom;
            }
            
            root.proceedToRecord("region", geom);
            return "STARTED";
        }

        function toggleSavedRegion(): string {
            if (root.isRecording) {
                root.stopRecording();
                return "STOPPED";
            } else {
                return startSavedRegion();
            }
        }

        function slurpSuccess(): string {
            Proc.runCommand("screenRecorder.readSlurpGeom", ["cat", "/tmp/dms_slurp_geom.txt"], (stdout, exitCode) => {
                if (exitCode === 0 && stdout) {
                    var geom = stdout.trim();
                    console.log("[ScreenRecorderDaemon] slurp success IPC geometry: " + geom);
                    if (geom) {
                        var match = geom.match(/^(\d+)x(\d+)\+(\d+)\+(\d+)/);
                        if (match) {
                            var w = parseInt(match[1]) || 0;
                            var h = parseInt(match[2]) || 0;
                            var x = parseInt(match[3]) || 0;
                            var y = parseInt(match[4]) || 0;
                            
                            if (w % 2 !== 0) w--;
                            if (h % 2 !== 0) h--;
                            
                            if (w < 2) w = 2;
                            if (h < 2) h = 2;
                            
                            geom = w + "x" + h + "+" + x + "+" + y;
                        }
                        root.regionGeometry = geom;
                        root.proceedToRecord("region", geom);
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showWarning(I18n.tr("Screen Recorder"), I18n.tr("Invalid region geometry selected."));
                        }
                    }
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showWarning(I18n.tr("Screen Recorder"), I18n.tr("Failed to read selected region."));
                    }
                }
            });
            return "SUCCESS_HANDLED";
        }

        function slurpCanceled(): string {
            return "CANCELED_HANDLED";
        }

        function selectRegion(): string {
            root.selectRegionInteractive();
            return "TRIGGERED";
        }

        function slurpInteractiveSuccess(): string {
            Proc.runCommand("screenRecorder.readSlurpGeom", ["cat", "/tmp/dms_slurp_geom.txt"], (stdout, exitCode) => {
                if (exitCode === 0 && stdout) {
                    var geom = stdout.trim();
                    console.log("[ScreenRecorderDaemon] slurp interactive success: " + geom);
                    if (geom) {
                        var match = geom.match(/^(\d+)x(\d+)\+(\d+)\+(\d+)/);
                        if (match) {
                            var w = parseInt(match[1]) || 0;
                            var h = parseInt(match[2]) || 0;
                            var x = parseInt(match[3]) || 0;
                            var y = parseInt(match[4]) || 0;
                            
                            if (w % 2 !== 0) w--;
                            if (h % 2 !== 0) h--;
                            
                            if (w < 2) w = 2;
                            if (h < 2) h = 2;
                            
                            geom = w + "x" + h + "+" + x + "+" + y;
                        }
                        root.regionGeometry = geom;
                        pluginService.savePluginData(pluginId, "regionGeometry", geom);
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showSuccess(I18n.tr("Screen Recorder"), I18n.tr("Selected region: %1").arg(geom));
                        }
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showWarning(I18n.tr("Screen Recorder"), I18n.tr("Invalid region geometry selected."));
                        }
                    }
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showWarning(I18n.tr("Screen Recorder"), I18n.tr("Failed to read selected region."));
                    }
                }
            });
            return "SUCCESS_HANDLED";
        }

        function slurpInteractiveCanceled(): string {
            return "CANCELED_HANDLED";
        }

        function stop(): string {
            if (!root.isRecording) return "NOT_RECORDING";
            root.stopRecording();
            return "STOPPED";
        }

        function cancel(): string {
            if (!root.isRecording) return "NOT_RECORDING";
            root.cancelRecording();
            return "CANCELED";
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
                "recordingState": root.recordingState,
                "isRecording": root.isRecording,
                "isPaused": root.isPaused,
                "duration": root.recordingSeconds,
                "outputPath": root.outputPath
            });
        }
    }

    function refreshAudioDevices() {
        Proc.runCommand("screenRecorder.listAudioDevices", ["gpu-screen-recorder", "--list-audio-devices"], (stdout, exitCode) => {
            var inputs = [{"label": I18n.tr("Default Microphone"), "value": "default_input"}];
            var outputs = [{"label": I18n.tr("Default Output"), "value": "default_output"}];
            
            if (exitCode === 0 && stdout) {
                var lines = stdout.trim().split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split("|");
                    if (parts.length >= 2) {
                        var name = parts[0];
                        var label = parts[1];
                        
                        if (name.includes(".monitor") || name.includes("output") || name === "default_output") {
                            if (name !== "default_output") {
                                outputs.push({
                                    "label": label,
                                    "value": name
                                });
                            }
                        } else {
                            if (name !== "default_input") {
                                inputs.push({
                                    "label": label,
                                    "value": name
                                });
                            }
                        }
                    }
                }
            }
            root.audioInputsList = inputs;
            root.audioOutputsList = outputs;
        });
    }

    function refreshMonitors() {
        Proc.runCommand("screenRecorder.listMonitors", ["gpu-screen-recorder", "--list-monitors"], (stdout, exitCode) => {
            var defaultObj = {
                "label": I18n.tr("First Monitor Found"),
                "value": "all",
                "width": Screen.width || 1920,
                "height": Screen.height || 1080
            };
            
            if (exitCode === 0 && stdout) {
                var lines = stdout.trim().split("\n");
                var list = [defaultObj];
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim();
                    if (!line) continue;
                    var parts = line.split("|");
                    if (parts.length >= 1) {
                        var name = parts[0];
                        var res = parts[1] || "";
                        var w = 1920;
                        var h = 1080;
                        if (res) {
                            var resParts = res.split("x");
                            if (resParts.length >= 2) {
                                w = parseInt(resParts[0]) || 1920;
                                h = parseInt(resParts[1]) || 1080;
                            }
                        }
                        list.push({
                            "label": name + (res ? " (" + res + ")" : ""),
                            "value": name,
                            "width": w,
                            "height": h
                        });
                    }
                }
                root.monitorsList = list;
            } else {
                root.monitorsList = [defaultObj];
            }
        });
    }

    Component.onCompleted: {
        PluginService.setGlobalVar(pluginId, "instance", root);
        refreshMonitors();
        refreshAudioDevices();
        // Parse initial region geometry
        var match = regionGeometry.match(/^(\d+)x(\d+)\+(\d+)\+(\d+)/);
        if (match) {
            regionW = parseInt(match[1]) || 0;
            regionH = parseInt(match[2]) || 0;
            regionX = parseInt(match[3]) || 0;
            regionY = parseInt(match[4]) || 0;
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            required property var modelData
            screen: modelData
            
            // Only visible when recording is active and the active mode is region
            visible: root.isRecording && root.activeRecordingMode === "region"
            color: "transparent"
            
            WlrLayershell.namespace: "dms:screen-recorder-overlay"
            WlrLayershell.layer: WlrLayershell.Overlay
            WlrLayershell.exclusiveZone: -1
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            
            mask: Region {}
            
            anchors {
                left: true
                right: true
                top: true
                bottom: true
            }

            Rectangle {
                readonly property int padding: 4
                // Determine screen-local overlap, padded outward by 4px to avoid showing in recording
                x: root.regionX - padding - modelData.x
                y: root.regionY - padding - modelData.y
                width: root.regionW + (padding * 2)
                height: root.regionH + (padding * 2)
                color: "transparent"
                
                // Only show if the geometry actually overlaps this screen
                visible: (x + width > 0) && (x < modelData.width) && (y + height > 0) && (y < modelData.height)

                Canvas {
                    id: borderCanvas
                    anchors.fill: parent
                    
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.strokeStyle = Theme.primary;
                        ctx.lineWidth = 2.5;
                        ctx.setLineDash([6, 5]);
                        
                        var x = 1.25;
                        var y = 1.25;
                        var w = width - 2.5;
                        var h = height - 2.5;
                        var r = 8; // Corner radius
                        
                        ctx.beginPath();
                        ctx.moveTo(x + r, y);
                        ctx.lineTo(x + w - r, y);
                        ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                        ctx.lineTo(x + w, y + h - r);
                        ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
                        ctx.lineTo(x + r, y + h);
                        ctx.quadraticCurveTo(x, y + h, x, y + h - r);
                        ctx.lineTo(x, y + r);
                        ctx.quadraticCurveTo(x, y, x + r, y);
                        ctx.closePath();
                        ctx.stroke();
                    }
                    
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                }

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.6; to: 0.15; duration: 1500; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.15; to: 0.6; duration: 1500; easing.type: Easing.InOutQuad }
                }
            }
        }
    }
}
