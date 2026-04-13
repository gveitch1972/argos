import Foundation
import CoreGraphics

/// Converts IMU orientation (radians) into a pixel offset for the overlay window.
///
/// When your head rotates right, the display should shift left by the same
/// angle — making it feel pinned in space.
///
/// Dead zone: small head movements (< threshold) are ignored to prevent
/// micro-jitter from being visible.
struct DisplayAnchor {

    // ── Configuration ─────────────────────────────────────────────────────────

    /// Pixels of travel per radian of head rotation.
    /// At 1.0 rad (57°) the display shifts by this many pixels.
    var pixelsPerRadian: Double = 800.0

    /// Movements smaller than this (radians) are ignored — prevents micro-jitter.
    var deadZone: Double = 0.005

    /// Exponential moving average coefficient for the output.
    /// Higher = smoother output, more lag. Range 0..1.
    var outputSmoothing: Double = 0.85

    // ── State ─────────────────────────────────────────────────────────────────

    private var smoothedX: Double = 0
    private var smoothedY: Double = 0
    private var lockedPitch: Double = 0
    private var lockedYaw: Double = 0
    private var isLocked: Bool = false

    // ── Public API ────────────────────────────────────────────────────────────

    /// Lock the current orientation as the "zero" reference point.
    mutating func lock(pitch: Double, yaw: Double) {
        lockedPitch = pitch
        lockedYaw = yaw
        isLocked = true
    }

    mutating func unlock() {
        isLocked = false
        lockedPitch = 0
        lockedYaw = 0
    }

    /// Convert orientation sample to a display offset in points.
    /// Returns (dx, dy) — apply these to shift the overlay content.
    mutating func offset(pitch: Double, yaw: Double) -> CGPoint {
        let basePitch = isLocked ? lockedPitch : 0
        let baseYaw   = isLocked ? lockedYaw   : 0

        var dPitch = pitch - basePitch
        var dYaw   = yaw   - baseYaw

        // Dead zone — snap small movements to zero
        if abs(dPitch) < deadZone { dPitch = 0 }
        if abs(dYaw)   < deadZone { dYaw   = 0 }

        // Convert radians → pixels (negate: head right → display left)
        let targetX = -dYaw   * pixelsPerRadian
        let targetY =  dPitch * pixelsPerRadian

        // Exponential moving average
        let α = outputSmoothing
        smoothedX = α * smoothedX + (1 - α) * targetX
        smoothedY = α * smoothedY + (1 - α) * targetY

        return CGPoint(x: smoothedX, y: smoothedY)
    }

    mutating func reset() {
        smoothedX = 0
        smoothedY = 0
    }
}
