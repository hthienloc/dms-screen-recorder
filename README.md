# Screen Recorder Plugin

Wayland screen recorder plugin for DankMaterialShell (DMS), powered by `gpu-screen-recorder`.

<img src="screenshot.png" width="400" alt="Screenshot">

## Install

Use the DMS CLI:
```bash
dms plugins install screenRecorderLH
```

Or manually:
```bash
git clone https://github.com/hthienloc/dms-screen-recorder ~/.config/DankMaterialShell/plugins/screenRecorderLH
```

## Features

- **GPU Accelerated** - High-performance hardware encoding (NVENC, VAAPI, AMF).
- **Dynamic Control** - Real-time file size estimation, FPS slider, codec selectors, and audio toggles.
- **Smart Notifications** - First-frame video thumbnail extraction on completion.

## Requirements

- `gpu-screen-recorder`
- `ffmpeg` (for thumbnail extraction)
- `notify-send` (for desktop notifications)

## Wayland Cursor Hiding Note (Important)

When disabling **Show Cursor**:
- **Screen Mode (`-w screen`)**: Direct KMS capture can hide the cursor. However, it requires root permissions or special capabilities:
  ```bash
  sudo setcap cap_sys_admin+ep /usr/bin/gpu-screen-recorder
  ```

## Roadmap

- [ ] **Region/Window Capture (`-w portal`)** - Enable and stabilize region/window capture utilizing XDG Desktop Portal.
- [ ] **Instant Replay Buffer (`-r <sec>`)** - Support saving the last N seconds of screen activity in RAM or disk.
- [ ] **Webcam Overlay (`-w "screen|/dev/video0"`)** - Support embedding a webcam overlay on the recording with custom positioning.
- [ ] **Application Audio Capture (`-a <app_name>`)** - Support recording audio from a specific application instead of the entire system.
- [ ] **Content Frame Rate Mode (`-fm content`)** - Support dynamically adjusting frame rate based on desktop content to save storage.

## License

MIT
