import Foundation
import Combine

/// Manages the connection to Xreal Air 2 Pro and publishes orientation updates.
class GlassesManager: ObservableObject {

    @Published var isConnected: Bool = false
    @Published var orientation: Orientation = .zero
    @Published var isLocked: Bool = false

    private var session: OpaquePointer? // ArgosSession*
    private var pollingTask: Task<Void, Never>?
    private var lockedOrientation: Orientation = .zero

    struct Orientation {
        var pitch: Double // up / down
        var yaw: Double   // left / right
        var roll: Double  // tilt

        static let zero = Orientation(pitch: 0, yaw: 0, roll: 0)
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    func start() {
        pollingTask = Task {
            await connectionLoop()
        }
    }

    func stop() {
        pollingTask?.cancel()
        disconnect()
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    func lockScreenPosition() {
        lockedOrientation = orientation
        isLocked = true
    }

    func resetOrientation() {
        isLocked = false
        lockedOrientation = .zero
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    private func connectionLoop() async {
        while !Task.isCancelled {
            if argos_device_present() == 1 {
                await connect()
            } else {
                await MainActor.run { isConnected = false }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func connect() async {
        session = OpaquePointer(argos_connect())
        guard session != nil else {
            try? await Task.sleep(for: .seconds(2))
            return
        }

        await MainActor.run { isConnected = true }

        // Poll IMU at ~60 Hz
        while !Task.isCancelled && argos_device_present() == 1 {
            var sample = ArgosOrientation(pitch: 0, yaw: 0, roll: 0, timestamp_ns: 0)
            let status = argos_read_orientation(session, &sample)

            if status == ArgosStatus(rawValue: 0) { // .Ok
                let o = Orientation(pitch: sample.pitch, yaw: sample.yaw, roll: sample.roll)
                await MainActor.run { orientation = o }
                applyToDisplay(o)
            }

            try? await Task.sleep(for: .milliseconds(16)) // ~60 Hz
        }

        disconnect()
    }

    private func disconnect() {
        if let s = session {
            argos_disconnect(UnsafeMutablePointer(s))
            session = nil
        }
        Task { await MainActor.run { isConnected = false } }
    }

    /// Translate head orientation into display position offset.
    /// This is the core of the "stable screen" experience.
    private func applyToDisplay(_ o: Orientation) {
        guard isConnected else { return }

        let base = isLocked ? lockedOrientation : .zero
        let _ = o.yaw - base.yaw     // horizontal offset
        let _ = o.pitch - base.pitch // vertical offset

        // TODO: use CoreGraphics / CGDisplaySetSmoothDisplayMode or
        //       a virtual display layer to shift screen position
        // Smoothing: apply exponential moving average to avoid jitter
    }
}
