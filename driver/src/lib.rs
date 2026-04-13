/// argos-driver
///
/// Rust library that reads IMU data from Xreal Air 2 Pro over USB HID
/// and exposes a C-compatible FFI for the Swift macOS app.
///
/// Uses ar-drivers-rs (nreal feature) for device communication,
/// and a complementary filter for stable orientation output.

use ar_drivers::{any_glasses, ARGlasses, GlassesEvent};
use nalgebra::Vector3;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::Instant;

// ── Types exposed to Swift via FFI ───────────────────────────────────────────

/// Orientation in radians: pitch (up/down), yaw (left/right), roll (tilt).
#[repr(C)]
pub struct ArgosOrientation {
    pub pitch: f64,
    pub yaw: f64,
    pub roll: f64,
    pub timestamp_ns: u64,
}

#[repr(C)]
pub enum ArgosStatus {
    Ok = 0,
    DeviceNotFound = 1,
    PermissionDenied = 2,
    ReadError = 3,
}

/// Owns the glasses connection and sensor fusion state.
pub struct ArgosSession {
    glasses: Box<dyn ARGlasses>,
    fusion: ComplementaryFilter,
    running: Arc<AtomicBool>,
}

// ── FFI entry points ──────────────────────────────────────────────────────────

/// Connect to the first Xreal Air 2 Pro found on USB.
/// Returns null on failure. Caller must free with `argos_disconnect`.
#[no_mangle]
pub extern "C" fn argos_connect() -> *mut ArgosSession {
    match any_glasses() {
        Ok(glasses) => {
            let session = ArgosSession {
                glasses,
                fusion: ComplementaryFilter::new(),
                running: Arc::new(AtomicBool::new(true)),
            };
            eprintln!("[argos] connected");
            Box::into_raw(Box::new(session))
        }
        Err(e) => {
            eprintln!("[argos] connect failed: {e}");
            std::ptr::null_mut()
        }
    }
}

/// Block until the next orientation sample is ready.
/// Returns ArgosStatus::Ok on success; `out` is written only on success.
#[no_mangle]
pub extern "C" fn argos_read_orientation(
    session: *mut ArgosSession,
    out: *mut ArgosOrientation,
) -> ArgosStatus {
    if session.is_null() || out.is_null() {
        return ArgosStatus::ReadError;
    }
    let session = unsafe { &mut *session };

    loop {
        match session.glasses.read_event() {
            Ok(GlassesEvent::AccGyro { accelerometer, gyroscope, timestamp }) => {
                let orientation = session.fusion.update(accelerometer, gyroscope, timestamp);
                unsafe { *out = orientation };
                return ArgosStatus::Ok;
            }
            Ok(_) => continue, // skip non-IMU events (key press, vsync, etc.)
            Err(e) => {
                eprintln!("[argos] read error: {e}");
                return ArgosStatus::ReadError;
            }
        }
    }
}

/// Disconnect and free the session.
#[no_mangle]
pub extern "C" fn argos_disconnect(session: *mut ArgosSession) {
    if !session.is_null() {
        let session = unsafe { Box::from_raw(session) };
        session.running.store(false, Ordering::SeqCst);
        eprintln!("[argos] disconnected");
    }
}

/// Returns 1 if an Xreal / Nreal device is detected on USB, 0 otherwise.
#[no_mangle]
pub extern "C" fn argos_device_present() -> i32 {
    let api = match hidapi::HidApi::new() {
        Ok(a) => a,
        Err(_) => return 0,
    };
    let found = api
        .device_list()
        .any(|d| d.vendor_id() == XREAL_VID && d.product_id() == XREAL_AIR2_PRO_PID);
    if found { 1 } else { 0 }
}

// ── USB identifiers ───────────────────────────────────────────────────────────

const XREAL_VID: u16 = 0x3318;
const XREAL_AIR2_PRO_PID: u16 = 0x0432;

// ── Complementary filter ──────────────────────────────────────────────────────
//
// Blends gyroscope integration (high-freq, drifts) with accelerometer
// tilt estimate (low-freq, noisy). Alpha controls the blend:
//   α close to 1.0 → trust gyro more → smoother but slower to correct drift
//   α close to 0.0 → trust accel more → jittery but drift-free
//
// 0.96 is a good starting point; exposed to Swift as a tunable setting.

const DEFAULT_ALPHA: f64 = 0.96;

struct ComplementaryFilter {
    pitch: f64,
    yaw: f64,
    roll: f64,
    last_timestamp_us: Option<u64>,
    alpha: f64,
    wall_start: Instant,
}

impl ComplementaryFilter {
    fn new() -> Self {
        Self {
            pitch: 0.0,
            yaw: 0.0,
            roll: 0.0,
            last_timestamp_us: None,
            alpha: DEFAULT_ALPHA,
            wall_start: Instant::now(),
        }
    }

    fn update(
        &mut self,
        accel: Vector3<f32>,
        gyro: Vector3<f32>,
        timestamp_us: u64,
    ) -> ArgosOrientation {
        // dt in seconds from device timestamps (microseconds)
        let dt = match self.last_timestamp_us {
            Some(prev) => (timestamp_us.saturating_sub(prev)) as f64 / 1_000_000.0,
            None => 0.0,
        };
        self.last_timestamp_us = Some(timestamp_us);

        // Gyro integration (rad/s → radians)
        //
        // nreal_air driver remaps raw axes before emitting GlassesEvent:
        //   raw_x → gyro.x (negated) — physical side-tilt (roll)
        //   raw_y → gyro.z           — physical nod up/down (pitch)
        //   raw_z → gyro.y           — physical turn left/right (yaw)
        //
        // So the correct mapping when worn as glasses is:
        //   yaw   = gyro.y  (left/right head turn)
        //   pitch = gyro.z  (nod up/down)
        //   roll  = gyro.x  (side tilt)
        let gyro_pitch = self.pitch + gyro.z as f64 * dt;
        let gyro_yaw   = self.yaw   + gyro.y as f64 * dt;
        let gyro_roll  = self.roll  + gyro.x as f64 * dt;

        // Accelerometer tilt estimate (only valid when not accelerating).
        // In RUB at rest: accel ≈ (0, +9.81, 0)
        // Pitch (nod): angle of forward tilt = atan2(-accel.z, accel.y)
        // Roll  (tilt): angle of side tilt   = atan2( accel.x, accel.y)
        let accel_pitch = (-(accel.z as f64)).atan2(accel.y as f64);
        let accel_roll  = (  accel.x as f64 ).atan2(accel.y as f64);
        // Accel can't estimate yaw — gyro-only

        // Blend
        let alpha = self.alpha;
        self.pitch = alpha * gyro_pitch + (1.0 - alpha) * accel_pitch;
        self.yaw   = gyro_yaw;
        self.roll  = alpha * gyro_roll  + (1.0 - alpha) * accel_roll;

        let timestamp_ns = self.wall_start.elapsed().as_nanos() as u64;

        ArgosOrientation {
            pitch: self.pitch,
            yaw:   self.yaw,
            roll:  self.roll,
            timestamp_ns,
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_device_detection() {
        let api = hidapi::HidApi::new().expect("hidapi init failed");
        let found = api
            .device_list()
            .any(|d| d.vendor_id() == XREAL_VID && d.product_id() == XREAL_AIR2_PRO_PID);
        println!(
            "Xreal Air 2 Pro present: {}",
            if found { "YES ✓" } else { "NO — plug in glasses" }
        );
        assert!(found, "Expected device VID={:#06x} PID={:#06x}", XREAL_VID, XREAL_AIR2_PRO_PID);
    }

    #[test]
    fn test_connect_read_disconnect() {
        let session = argos_connect();
        if session.is_null() {
            println!("No device — skipping");
            return;
        }
        println!("Connected ✓");

        // Read 20 IMU samples and print them
        for i in 0..20 {
            let mut out = ArgosOrientation { pitch: 0.0, yaw: 0.0, roll: 0.0, timestamp_ns: 0 };
            let status = argos_read_orientation(session, &mut out);
            match status {
                ArgosStatus::Ok => println!(
                    "  [{i:02}] pitch={:.4}  yaw={:.4}  roll={:.4}  t={}ns",
                    out.pitch, out.yaw, out.roll, out.timestamp_ns
                ),
                _ => println!("  [{i:02}] read error"),
            }
        }

        argos_disconnect(session);
        println!("Disconnected ✓");
    }

    #[test]
    fn test_list_all_hid_devices() {
        let api = hidapi::HidApi::new().expect("hidapi init failed");
        println!("\n── Connected HID devices ──");
        for d in api.device_list() {
            println!(
                "  VID={:#06x}  PID={:#06x}  manufacturer={:?}  product={:?}",
                d.vendor_id(), d.product_id(),
                d.manufacturer_string(), d.product_string(),
            );
        }
        println!("──────────────────────────");
    }
}
