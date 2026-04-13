# Argos — Build Plan

## Immediate fixes needed

### 1. Screen capture safety
**Problem:** Overlay + capture takes full control of the display, hard to escape.
**Fix:**
- Add `Cmd+H` to hide overlay (suspend capture, restore Mac display)
- Add `Esc` key as emergency hide
- Show a countdown / reminder on the Mac display: "Argos running — Cmd+Q to quit"
- Pause capture when overlay is hidden, resume when shown

### 2. Yaw drift correction
**Problem:** No magnetometer → gyro-only yaw drifts slowly.
**Fix options:**
- A) Auto-decay: when gyro.y < threshold for >2s, gently pull yaw back toward lock point
- B) Periodic re-lock: every 30s of stillness, update the lock reference
- C) Accept it — user presses L to re-lock, which is fine for most use cases

Recommended: start with C (already works), add A if drift is annoying in practice.

### 3. Wire settings to running filter
**Problem:** Smoothing/sensitivity sliders in UI don't affect the Rust filter.
**Fix:**
- Expose `argos_set_alpha(session, f64)` and `argos_set_sensitivity(session, f64)` in Rust FFI
- Call from GlassesManager when AppStorage values change
- Also wire `DisplayAnchor.pixelsPerRadian` and `maxOffset` to settings

### 4. Hide overlay shortcut
**Problem:** No quick way to hide overlay without quitting.
**Fix:** Add `Cmd+H` to AppDelegate as a local monitor (same pattern as Cmd+Q).

## Medium-term features

### Proper .app bundle
- Generate Xcode project: `swift package generate-xcodeproj`
- Add `Info.plist` with `NSScreenCaptureUsageDescription` for Screen Recording prompt
- Code sign for Gatekeeper
- Optionally: `brew install --cask argos` via a Homebrew tap

### Capture improvements
- Option to capture a specific window rather than full display
- Scale/crop captured content to fill glasses display correctly
- Hide the Argos overlay itself from the capture (exclude own window)

### Display mode control
- Set glasses to `SameOnBoth` or `Stereo` mode via the ar-drivers `set_display_mode` API
- Expose in menu: Standard / Cinema / SBS

### Brightness control
- ar-drivers supports brightness commands via MCU interface
- Add slider to Settings

### Launch at login
- Wire `launchAtLogin` toggle in SettingsView to actual SMAppService registration

## Architecture decisions made

| Decision | Rationale |
|----------|-----------|
| Rust driver as static lib | ar-drivers-rs already supports Air 2 Pro; no point reimplementing HID |
| C FFI header (not Swift-Rust bridge crate) | Simpler, no extra tooling needed |
| SPM C target for bridge header | Cleanest way to expose C header to Swift in SPM |
| Complementary filter (not Madgwick/EKF) | Good enough for 3DoF display stabilisation; simpler to tune |
| AVSampleBufferDisplayLayer for capture | Low latency, handles CMSampleBuffer directly from SCStream |
| 1.5× canvas with ±180px clamp | Enough panning room without wrap-around or going off-screen |
| Auto-calibrate 30 frames on connect | Prevents startup jump without requiring user action |

## Known gotchas

- `argos_device_present()` returns 0 while a session is open (HID exclusive access) —
  never call it inside the read loop
- Tests must run with `--test-threads=1` — hidapi is not thread-safe
- Rust must be on PATH before building: `source ~/.cargo/env`
- `make build` assumes the release Rust lib is pre-built; Makefile handles this automatically
- The nreal driver remaps gyro axes: raw_z→y (yaw), raw_y→z (pitch), raw_x→x (roll)
