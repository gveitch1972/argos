# Argos — Project State

Last updated: 2026-04-13

## What works right now

- Xreal Air 2 Pro detected over USB HID (VID `0x3318` / PID `0x0432`)
- Rust driver (`ar-drivers-rs` nreal feature) reads live IMU at ~500Hz
- Complementary filter fuses gyro + accel → stable pitch, yaw, roll
- Auto-calibration on connect: 30 frames averaged as zero baseline (no startup jump)
- Swift menu bar app opens fullscreen overlay on glasses display (`"Air 2 Pro"`)
- Head movement pans overlay opposite direction — display feels pinned in space
- ScreenCaptureKit captures any display by CGDirectDisplayID
- Cmd+Q quits from anywhere (even when overlay covers display)
- Menu: toggle overlay, create virtual display, start/stop capture, lock, reset, settings, quit

## CGVirtualDisplay (new)

Argos can now create a proper macOS virtual monitor (invisible framebuffer):

1. **Menu → Create virtual display** → macOS registers a new 1920×1080@60Hz monitor
2. Drag apps/windows to "Argos Virtual Display" in System Settings > Displays (or drag windows there)
3. **Menu → Start capture → glasses** → captures the virtual display, shows in overlay with head tracking
4. **Menu → Destroy virtual display** → removes it

The virtual display requires the `com.apple.developer.virtual-display` entitlement,
which is baked in via `make build` (codesigns with `Argos.entitlements`).

## Architecture

```
Virtual Display (invisible macOS monitor)
    ↓ SCStream (ScreenCaptureKit)
ScreenCaptureManager (AVSampleBufferDisplayLayer)
    ↓ attachCaptureLayer
OverlayWindow (fullscreen on "Air 2 Pro" glasses display)
    ↓ applyOffset (IMU → DisplayAnchor → CGPoint)
GlassesManager (Rust IMU loop → complementary filter → offset)
```

## What doesn't work yet / known issues

1. **Virtual display blocked on Apple entitlement** — `com.apple.developer.virtual-display`
   is a restricted entitlement enforced server-side by WindowServer. Without Apple
   provisioning it to the App ID, `CGVirtualDisplay initWithDescriptor:` returns nil.
   - Apple Developer support case submitted: **102868488700** (Development & Technical →
     Entitlements). Awaiting response (~2 business days).
   - Code is ready: `VirtualDisplay.m`, `VirtualDisplayManager.swift`, `Argos.entitlements`
     (entitlement key commented out until provisioning profile is in hand).
   - Next: support N virtual displays (remove singleton in `VirtualDisplay.m`).

2. **Settings not wired to running filter** — smoothing/sensitivity sliders in Settings UI
   exist but don't update the running Rust complementary filter yet.

3. **Yaw drift** — no magnetometer on Air 2 Pro, so yaw integrates gyro only and drifts
   slowly over time. Workaround: use "Lock position" (L) to re-calibrate.

4. **Virtual display SCKit latency** — SCStream may take 1-2 seconds to discover a newly
   created CGVirtualDisplay; fallback to main display in the interim.

## Build instructions

```bash
cd /Users/G/projects/argos

# One-shot: builds Rust lib + Swift app + code signs with entitlements
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
- Added ScreenCaptureKit desktop mirroring (any displayID)

### Session 2 (2026-04-13)
- Added CGVirtualDisplay support via private CoreGraphics ObjC API
- ObjC wrapper in ArgosDriver C target (VirtualDisplay.m) → C functions → Swift
- Entitlements file (Argos.entitlements) with com.apple.developer.virtual-display
- Makefile updated: `make build` now auto-signs with entitlements
- ScreenCaptureManager updated: captures by displayID (virtual or real)
- New menu item: "Create virtual display" / "Destroy virtual display"
- VirtualDisplayManager.swift manages lifecycle
- Discovered `com.apple.developer.virtual-display` is a restricted entitlement;
  entitlement key is commented out in Argos.entitlements pending Apple approval
- Submitted Apple Developer support case 102868488700 to request the entitlement

## Repo

github.com/gveitch1972/argos (public)
