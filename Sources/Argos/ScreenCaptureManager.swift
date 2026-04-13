import ScreenCaptureKit
import AVFoundation
import AppKit

/// Captures a display (real or virtual) and delivers frames to an
/// AVSampleBufferDisplayLayer for rendering in the overlay.
@MainActor
class ScreenCaptureManager: NSObject {

    /// Drop this layer into the overlay window — it receives live screen frames.
    let displayLayer = AVSampleBufferDisplayLayer()

    private var stream: SCStream?
    private var isRunning = false

    // ── Start / stop ──────────────────────────────────────────────────────────

    /// Start capturing the given display.
    /// - Parameter displayID: CGDirectDisplayID to capture.
    ///   Pass `kCGNullDirectDisplay` (0) to capture the main Mac display.
    func start(displayID targetID: CGDirectDisplayID = 0) async {
        NSLog("[capture] start() called, targetID=%u, isRunning=%d", targetID, isRunning ? 1 : 0)
        guard !isRunning else { NSLog("[capture] already running, skipping"); return }

        guard await requestPermission() else {
            NSLog("[capture] screen recording permission denied")
            return
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            NSLog("[capture] found %d displays", content.displays.count)

            // Find the requested display; fall back to main display.
            let display: SCDisplay
            if targetID != 0,
               let found = content.displays.first(where: { $0.displayID == targetID }) {
                display = found
                NSLog("[capture] targeting virtual display %u", targetID)
            } else if let main = content.displays.first(where: { CGDisplayIsMain($0.displayID) != 0 }) {
                display = main
                if targetID != 0 {
                    NSLog("[capture] virtual display %u not visible to SCKit yet, using main", targetID)
                } else {
                    NSLog("[capture] targeting main display %u", main.displayID)
                }
            } else if let first = content.displays.first {
                display = first
                NSLog("[capture] using first available display %u", first.displayID)
            } else {
                NSLog("[capture] no display found — giving up")
                return
            }

            let config = SCStreamConfiguration()
            config.width  = display.width  * 2   // retina / HiDPI
            config.height = display.height * 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.capturesAudio = false

            // Exclude Argos itself from the capture — prevents recursive feedback loop
            let argosApp = content.applications.first(where: { $0.bundleIdentifier == "com.grahamveitch.argos" })
            let excludedApps = argosApp.map { [$0] } ?? []
            let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
            let s = SCStream(filter: filter, configuration: config, delegate: self)
            try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
            try await s.startCapture()

            stream = s
            isRunning = true
            NSLog("[capture] started — %dx%d", display.width, display.height)
        } catch {
            NSLog("[capture] failed to start: %@", error.localizedDescription)
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        displayLayer.flushAndRemoveImage()  // clear last frame immediately
        let s = stream
        stream = nil
        Task { try? await s?.stopCapture() }
        NSLog("[capture] stopped")
    }

    // ── Private ───────────────────────────────────────────────────────────────

    private func requestPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.current
            return true
        } catch {
            return false
        }
    }
}

// ── SCStreamOutput ────────────────────────────────────────────────────────────

extension ScreenCaptureManager: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        DispatchQueue.main.async {
            if self.displayLayer.isReadyForMoreMediaData {
                self.displayLayer.enqueue(buffer)
            }
        }
    }
}

extension ScreenCaptureManager: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("[capture] stream stopped: %@", error.localizedDescription)
        DispatchQueue.main.async { self.isRunning = false }
    }
}
