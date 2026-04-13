import ScreenCaptureKit
import AVFoundation
import AppKit

/// Captures the main Mac display and delivers frames to an AVSampleBufferDisplayLayer.
/// The overlay window uses this layer as its content — panning it with head movement
/// gives the "display pinned in space" effect.
@MainActor
class ScreenCaptureManager: NSObject {

    /// Drop this layer into the overlay window — it receives live screen frames.
    let displayLayer = AVSampleBufferDisplayLayer()

    private var stream: SCStream?
    private var isRunning = false

    // ── Start / stop ──────────────────────────────────────────────────────────

    func start() async {
        guard !isRunning else { return }

        // Request permission — prompts the user once, then remembered
        guard await requestPermission() else {
            print("[capture] screen recording permission denied")
            return
        }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            // Capture the main display (not the glasses display)
            guard let display = content.displays.first(where: { CGDisplayIsMain($0.displayID) != 0 })
                              ?? content.displays.first else {
                print("[capture] no display found")
                return
            }

            let config = SCStreamConfiguration()
            config.width  = display.width  * 2   // retina
            config.height = display.height * 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            config.capturesAudio = false

            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let s = SCStream(filter: filter, configuration: config, delegate: self)
            try s.addStreamOutput(self, type: .screen, sampleHandlerQueue: .main)
            try await s.startCapture()

            stream = s
            isRunning = true
            print("[capture] started — capturing \(display.width)×\(display.height)")
        } catch {
            print("[capture] failed to start: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        Task {
            try? await stream?.stopCapture()
            stream = nil
            isRunning = false
        }
    }

    // ── Private ───────────────────────────────────────────────────────────────

    private func requestPermission() async -> Bool {
        do {
            // This call triggers the permission prompt if not yet granted
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
        print("[capture] stream stopped: \(error)")
        DispatchQueue.main.async { self.isRunning = false }
    }
}
