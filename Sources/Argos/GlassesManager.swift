import Foundation
import CoreGraphics
import ArgosDriver

/// Manages the USB connection to Xreal Air 2 Pro.
/// Runs a blocking IMU read loop on a background thread and
/// publishes orientation + display offsets on the main thread.
@MainActor
class GlassesManager: ObservableObject {

    @Published var isConnected: Bool = false
    @Published var pitch: Double = 0
    @Published var yaw: Double = 0
    @Published var roll: Double = 0

    var onOffset: ((CGPoint) -> Void)?   // called ~500Hz with display offset
    var onStatus: ((String) -> Void)?    // called when status text changes

    private var anchor = DisplayAnchor()
    private var pollingTask: Task<Void, Never>?

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    func start() {
        pollingTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.connectionLoop()
        }
    }

    func stop() {
        pollingTask?.cancel()
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    func lockScreenPosition() {
        anchor.lock(pitch: pitch, yaw: yaw)
        onStatus?("Argos — locked  pitch=\(fmt(pitch))  yaw=\(fmt(yaw))")
    }

    func resetOrientation() {
        anchor.unlock()
        anchor.reset()
        onStatus?("Argos — tracking")
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    private func connectionLoop() async {
        while !Task.isCancelled {
            let present = argos_device_present()
            if present == 1 {
                await readLoop()
            } else {
                await MainActor.run {
                    self.isConnected = false
                    self.onStatus?("Argos — no glasses found")
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func readLoop() async {
        // argos_connect() and argos_read_orientation() are blocking C calls
        // — must run off the main thread
        let session = argos_connect()
        guard session != nil else {
            try? await Task.sleep(for: .seconds(2))
            return
        }

        await MainActor.run {
            self.isConnected = true
            self.onStatus?("Argos — calibrating…")
        }

        // Collect 30 frames to establish a stable baseline orientation.
        // Without this the initial IMU reading immediately pans the display.
        var calibPitch = 0.0, calibYaw = 0.0
        let calibFrames = 30
        for _ in 0..<calibFrames {
            var s = ArgosOrientation(pitch: 0, yaw: 0, roll: 0, timestamp_ns: 0)
            guard argos_read_orientation(session, &s) == ARGOS_OK else { break }
            calibPitch += s.pitch / Double(calibFrames)
            calibYaw   += s.yaw   / Double(calibFrames)
        }
        anchor.lock(pitch: calibPitch, yaw: calibYaw)

        await MainActor.run {
            self.onStatus?("Argos — connected  (⌘L to re-lock)")
        }

        // Spin reading samples — argos_read_orientation blocks until data arrives.
        // Do NOT call argos_device_present() here — once we hold the HID device
        // exclusively, it won't appear in scans and would immediately exit the loop.
        while !Task.isCancelled {
            var sample = ArgosOrientation(pitch: 0, yaw: 0, roll: 0, timestamp_ns: 0)
            let status = argos_read_orientation(session, &sample)

            guard status == ARGOS_OK else { break }

            // Compute display offset (can stay off main thread)
            let offset = anchor.offset(pitch: sample.pitch, yaw: sample.yaw)

            await MainActor.run {
                self.pitch = sample.pitch
                self.yaw   = sample.yaw
                self.roll  = sample.roll
                self.onOffset?(offset)
                self.onStatus?("Argos — connected  p:\(self.fmt(sample.pitch))  y:\(self.fmt(sample.yaw))")
            }
        }

        argos_disconnect(session)
        await MainActor.run {
            self.isConnected = false
            self.onStatus?("Argos — disconnected")
        }
    }

    private func fmt(_ v: Double) -> String {
        String(format: "%.3f", v)
    }
}
