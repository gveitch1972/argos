# Argos — Project State

Last updated: 2026-04-13

## What works right now

- Xreal Air 2 Pro detected over USB HID (VID `0x3318` / PID `0x0432`)
- Rust driver (`ar-drivers-rs` nreal feature) reads live IMU at ~500Hz
- Complementary filter fuses gyro + accel → stable pitch, yaw, roll
- Auto-calibration on connect: 30 frames averaged as zero baseline (no startup jump)
- Swift menu bar app opens fullscreen overlay on glasses display (`"Air 2 Pro"`)
- Head movement pans overlay opposite direction — display feels pinned in space
- ScreenCaptureKit captures Mac desktop → mirrored in overlay (needs Screen Recording permission)
- Cmd+Q quits from anywhere (even when overlay covers display)
- Menu: toggle overlay, lock position, reset orientation, settings, quit

## What doesn't work yet / known issues

1. **Screen capture takes full control** — when overlay is on glasses AND capture is active,
   Mac display can become hard to interact with. Need a toggle to pause/resume capture.

2. **Yaw drift** — no magnetometer on Air 2 Pro, so yaw integrates gyro only and drifts
   slowly over time. Workaround: use "Lock position" (L) to re-calibrate.
   Proper fix: periodic drift decay when head is stationary.

3. **Settings not wired to running filter** — smoothing/sensitivity sliders in Settings UI
   exist but don't update the running Rust complementary filter yet.

4. **Capture covers terminal** — need a keyboard shortcut to hide the overlay without
   quitting the app, so the user can interact with macOS normally.

5. **No release build / .app bundle** — currently run as a debug binary from terminal.
   Needs Xcode project or `swift package generate-xcodeproj` for proper .app packaging.

## Build instructions

```bash
cd /Users/G/projects/argos

# One-shot build
make build

# Run
.build/debug/Argos &

# Kill
pkill -f "\.build/debug/Argos"
```

Rust must be on PATH. If not: `source ~/.cargo/env`

## Session history (what was built and when)

### Session 1 (2026-04-13)
- Created project from scratch
- Rust driver: USB HID detection, connect/disconnect, C FFI
- Found correct PID (0x0432 not 0x0424)
- Implemented complementary filter for IMU fusion
- Verified live IMU data flowing (20 samples read successfully)
- Swift app: menu bar, overlay window, display anchor, settings UI
- Fixed axis mapping (nreal driver swaps gyro.y↔gyro.z)
- Fixed HID exclusive-access bug (device invisible to scans while held open)
- Added auto-calibration on connect
- Added ScreenCaptureKit desktop mirroring

## Repo

github.com/gveitch1972/argos (public)
