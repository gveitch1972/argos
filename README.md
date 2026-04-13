# Argos

> *Argus Panoptes — the hundred-eyed giant of Greek mythology.*

Native macOS menu bar app for Xreal Air 2 Pro AR glasses.
Stable virtual displays via head tracking. No Nebula required.

## What it does

- Reads IMU data (gyro + accelerometer) directly over USB HID
- Captures Mac desktop via ScreenCaptureKit and mirrors it to the glasses
- Uses 3DoF head tracking to keep the virtual display pinned in space
- Lives in the menu bar — lightweight, no Dock icon
- Auto-calibrates on connect — display starts centred, no initial jump

## Quick start

```bash
# Prerequisites
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh  # Rust
brew install hidapi

# Build
make build

# Run
.build/debug/Argos
```

macOS will prompt for **Screen Recording** permission on first run — required for desktop capture.

## Controls

| Action | How |
|--------|-----|
| Quit | Cmd+Q (works even when overlay covers display) |
| Lock position | Menu bar → Lock screen position |
| Re-centre | Menu bar → Reset orientation |
| Toggle overlay | Menu bar → Show/Hide overlay |

## Architecture

```
┌─────────────────────────────────────────┐
│           Argos.app (Swift/SwiftUI)     │
│  Menu bar · Overlay · Settings          │
│  ScreenCaptureKit → AVSampleBufferLayer │
└────────────┬────────────────────────────┘
             │ C FFI
┌────────────▼────────────────────────────┐
│       argos-driver (Rust static lib)    │
│  ar-drivers-rs · hidapi · comp. filter  │
└────────────┬────────────────────────────┘
             │ USB HID  (VID 0x3318 / PID 0x0432)
┌────────────▼────────────────────────────┐
│     Xreal Air 2 Pro hardware            │
│  Gyroscope · Accelerometer · Display    │
└─────────────────────────────────────────┘
```

## Key files

| File | Purpose |
|------|---------|
| `driver/src/lib.rs` | Rust USB HID driver + complementary filter + C FFI |
| `Sources/Argos/GlassesManager.swift` | IMU polling loop, auto-calibration, offset dispatch |
| `Sources/Argos/OverlayWindow.swift` | Fullscreen borderless window on glasses display |
| `Sources/Argos/DisplayAnchor.swift` | IMU radians → pixel offset with dead zone + EMA |
| `Sources/Argos/ScreenCaptureManager.swift` | SCStream desktop capture → AVSampleBufferDisplayLayer |
| `Sources/Argos/DisplayFinder.swift` | Identifies "Air 2 Pro" screen among connected NSScreens |
| `Sources/ArgosDriver/include/ArgosDriverBridge.h` | C header bridging Rust FFI to Swift |
| `Makefile` | Single-command build: Rust release lib then Swift app |

## Hardware facts

- **3DoF only** — pitch (nod), yaw (turn), roll (tilt). No XYZ position.
- Device shows up as `VID=0x3318 PID=0x0432` in USB HID
- Screen name macOS assigns: `"Air 2 Pro"`
- nreal driver axis map: `raw_z→gyro.y` (yaw), `raw_y→gyro.z` (pitch), `raw_x→gyro.x` (roll)

## Known issues / next steps

See PLAN.md

## References

- [ar-drivers-rs](https://github.com/badicsalex/ar-drivers-rs)
- [xrealmacdriver](https://github.com/punk-kaos/xrealmacdriver)
- [Void Computing: AR glasses USB protocols](https://voidcomputing.hu/blog/good-bad-ugly/)
