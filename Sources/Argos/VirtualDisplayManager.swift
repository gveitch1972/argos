import AppKit
import CoreGraphics
import ArgosDriver   // exposes argos_vdisplay_create / destroy / id

/// Creates and manages a CGVirtualDisplay — an invisible macOS monitor that
/// apps can target just like a real external display.
///
/// Entitlement required: com.apple.developer.virtual-display
/// The binary must be signed with Argos.entitlements (run `make build`).
///
/// Usage:
///   1. Call `create()` → macOS adds a new display in System Settings > Displays
///   2. Capture it: ScreenCaptureManager.start(displayID: virtualDisplay.displayID!)
///   3. Call `destroy()` on quit (deinit also cleans up)
@MainActor
class VirtualDisplayManager {

    /// The CGDirectDisplayID of the virtual monitor, nil if not yet created.
    private(set) var displayID: CGDirectDisplayID?

    // ── Public ────────────────────────────────────────────────────────────────

    /// Create the virtual display. Returns true on success.
    @discardableResult
    func create() -> Bool {
        if let existing = displayID { return existing != 0 }

        // 1920×1080 @ 60 Hz, 1:1 pixel mapping — matches Air 2 Pro panel
        let id = argos_vdisplay_create("Argos Virtual Display", 1920, 1080, 60.0, 0)
        guard id != 0 else { return false }
        displayID = CGDirectDisplayID(id)
        return true
    }

    /// Remove the virtual display from macOS display layout.
    func destroy() {
        argos_vdisplay_destroy()
        displayID = nil
    }
}
