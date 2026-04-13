# Argos Architecture

## Overview

Argos is a native macOS menu bar app that connects directly to Xreal Air 2 Pro glasses over USB HID, reads IMU sensor data, and uses it to anchor a stable virtual display — without Nebula.

## Layers

### 1. Rust driver (`driver/`)

Handles all USB communication. Built as a static library (`libargos_driver.a`) and linked into the Swift app.

**Why Rust:**  
`ar-drivers-rs` already supports Xreal Air 2 Pro and handles the HID protocol. No point rewriting this in Swift.

**Key responsibilities:**
- Open USB HID device (VID `0x3318`, PID `0x0424`)  
- Read 64-byte IMU packets from interface 3, endpoint `0x89`
- Parse gyroscope + accelerometer (3×i16 little-endian, nanosecond timestamps)
- Expose clean C FFI: `argos_connect / argos_read_orientation / argos_disconnect`

### 2. Swift app (`Sources/Argos/`)

| File | Role |
|------|------|
| `ArgosApp.swift` | App entry point, menu bar setup |
| `GlassesManager.swift` | Connection lifecycle, 60Hz polling loop, display control |
| `SettingsView.swift` | SwiftUI settings panel (smoothing, sensitivity) |
| `ArgosDriverBridge.h` | C header that exposes Rust FFI to Swift |

### 3. Display anchoring

The hard part. Two approaches to investigate:

**Option A — Virtual display offset**  
Use a private CoreGraphics API or a kernel extension to shift the virtual display position based on head angle. Cleanest UX but requires digging into private APIs.

**Option B — Overlay window**  
Create a borderless, always-on-top NSWindow that covers the full screen and pans its content layer based on orientation. Simpler, no private APIs needed.

Start with Option B.

## USB Protocol (Xreal Air 2 Pro)

Source: [Void Computing reverse engineering](https://voidcomputing.hu/blog/good-bad-ugly/)

```
Interface 3 — IMU (HID interrupt, endpoint 0x89)
Packet size: 64 bytes

Offset  Size  Field
0       1     Header (0xFD)
1       4     CRC32 (Adler)
5       2     Data length
7       4     Request ID
11      4     Timestamp (ns)
15      2     Command ID
17      6     Gyroscope  XYZ (3 × i16, little-endian)
23      6     Accelerometer XYZ (3 × i16, little-endian)
...
```

## Sensor fusion

Raw gyro + accel → stable orientation via complementary filter:

```
angle = α × (angle + gyro × dt) + (1 − α) × accel_angle
```

`α` = smoothing coefficient (user-adjustable, default 0.85).

## Hardware limits

- **3DoF only** — pitch, yaw, roll. No XYZ position.
- No camera on Air 2 Pro → no SLAM, no 6DoF.
- Display modes: 1920×1080 @ 60Hz to 3840×1080 @ 90Hz.
