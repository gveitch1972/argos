# Argos 👁

> *Argus Panoptes — the hundred-eyed giant of Greek mythology.*

A native macOS menu bar app for Xreal Air 2 Pro AR glasses.  
Stable virtual displays. No jitter. No Nebula required.

## What it does

- Reads IMU data (gyro + accelerometer) directly over USB HID
- Anchors your virtual screen using 3DoF head tracking
- Lives in the menu bar — lightweight, always available
- Fixes the drift and jitter that Nebula never solved

## Architecture

```
┌─────────────────────────────────────────┐
│           Argos.app (SwiftUI)           │
│   Menu bar · Settings · Display control │
└────────────────┬────────────────────────┘
                 │ FFI
┌────────────────▼────────────────────────┐
│         argos-driver (Rust)             │
│   ar-drivers-rs · hidapi · IMU fusion   │
└────────────────┬────────────────────────┘
                 │ USB HID
┌────────────────▼────────────────────────┐
│       Xreal Air 2 Pro Hardware          │
│   Gyroscope · Accelerometer · Display   │
└─────────────────────────────────────────┘
```

## Hardware notes

- **3DoF only** — rotation tracking (pitch, yaw, roll)
- No positional tracking — Air 2 Pro has no camera
- Display modes up to 3840×1080 @ 90Hz

## Stack

| Layer | Tech |
|-------|------|
| macOS app | Swift / SwiftUI |
| USB driver | Rust (`ar-drivers-rs`, `hidapi`) |
| Bridge | Swift/Rust FFI via C header |
| Build | Swift Package Manager + Cargo |

## Getting started

### Prerequisites

- macOS 13.0+
- Rust toolchain: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- Xreal Air 2 Pro connected via USB-C

### Build

```bash
# Build the Rust driver
cd driver && cargo build --release

# Build and run the macOS app
swift run
```

## References

- [ar-drivers-rs](https://github.com/badicsalex/ar-drivers-rs) — Rust library for AR glasses
- [xrealmacdriver](https://github.com/punk-kaos/xrealmacdriver) — macOS HID proof of concept
- [Void Computing: AR glasses USB protocols](https://voidcomputing.hu/blog/good-bad-ugly/) — protocol reverse engineering

## Name

**Argos** (Ἄργος) — In Greek mythology, Argus Panoptes was a giant with a hundred eyes,  
set to watch over things that mattered. Seemed fitting.
