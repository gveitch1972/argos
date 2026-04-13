/// argos-driver
///
/// Rust library that reads IMU data from Xreal Air 2 Pro over USB HID
/// and exposes a C-compatible FFI for the Swift macOS app.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

// ── Types exposed to Swift via FFI ───────────────────────────────────────────

/// Orientation in radians: pitch (up/down), yaw (left/right), roll (tilt).
/// Computed from gyroscope + accelerometer fusion.
#[repr(C)]
pub struct ArgosOrientation {
    pub pitch: f64,
    pub yaw: f64,
    pub roll: f64,
    pub timestamp_ns: u64,
}

/// Device connection state returned to Swift.
#[repr(C)]
pub enum ArgosStatus {
    Ok = 0,
    DeviceNotFound = 1,
    PermissionDenied = 2,
    ReadError = 3,
}

/// Opaque handle passed back to Swift — owns the device connection.
pub struct ArgosSession {
    running: Arc<AtomicBool>,
}

// ── FFI entry points ──────────────────────────────────────────────────────────

/// Connect to the first Xreal Air 2 Pro found on USB.
/// Returns null on failure. Caller must free with `argos_disconnect`.
#[no_mangle]
pub extern "C" fn argos_connect() -> *mut ArgosSession {
    match open_device() {
        Ok(session) => Box::into_raw(Box::new(session)),
        Err(e) => {
            eprintln!("[argos-driver] connect failed: {e}");
            std::ptr::null_mut()
        }
    }
}

/// Read a single orientation sample. Returns ArgosStatus::Ok on success.
/// `out` must point to a valid ArgosOrientation.
#[no_mangle]
pub extern "C" fn argos_read_orientation(
    session: *mut ArgosSession,
    out: *mut ArgosOrientation,
) -> ArgosStatus {
    if session.is_null() || out.is_null() {
        return ArgosStatus::ReadError;
    }
    let _session = unsafe { &*session };

    match read_imu_sample() {
        Ok(orientation) => {
            unsafe { *out = orientation };
            ArgosStatus::Ok
        }
        Err(_) => ArgosStatus::ReadError,
    }
}

/// Disconnect and free the session.
#[no_mangle]
pub extern "C" fn argos_disconnect(session: *mut ArgosSession) {
    if !session.is_null() {
        let session = unsafe { Box::from_raw(session) };
        session.running.store(false, Ordering::SeqCst);
    }
}

/// Returns 1 if an Xreal Air 2 Pro is connected, 0 otherwise.
#[no_mangle]
pub extern "C" fn argos_device_present() -> i32 {
    match find_xreal_device() {
        Some(_) => 1,
        None => 0,
    }
}

// ── Internal implementation ───────────────────────────────────────────────────

// Xreal Air 2 Pro USB identifiers
const XREAL_VID: u16 = 0x3318;
const XREAL_AIR2_PRO_PID: u16 = 0x0424;

// IMU HID interface — interface 3, endpoint 0x89
const IMU_INTERFACE: i32 = 3;

fn find_xreal_device() -> Option<hidapi::DeviceInfo> {
    let api = hidapi::HidApi::new().ok()?;
    api.device_list()
        .find(|d| d.vendor_id() == XREAL_VID && d.product_id() == XREAL_AIR2_PRO_PID)
        .cloned()
}

fn open_device() -> Result<ArgosSession, Box<dyn std::error::Error>> {
    let _info = find_xreal_device().ok_or("Xreal Air 2 Pro not found")?;
    Ok(ArgosSession {
        running: Arc::new(AtomicBool::new(true)),
    })
}

/// Placeholder — real implementation reads 64-byte HID packets from interface 3.
/// Packet layout (from Void Computing reverse engineering):
///   [0..3]   header (0xFD + CRC32)
///   [4..7]   timestamp (nanoseconds, little-endian)
///   [8..13]  gyroscope  xyz (3 × i16, little-endian, scaled)
///   [14..19] accel      xyz (3 × i16, little-endian, scaled)
fn read_imu_sample() -> Result<ArgosOrientation, Box<dyn std::error::Error>> {
    // TODO: replace with real HID read + complementary filter
    Ok(ArgosOrientation {
        pitch: 0.0,
        yaw: 0.0,
        roll: 0.0,
        timestamp_ns: 0,
    })
}
