import AppKit

/// Finds the Xreal Air 2 Pro display among connected NSScreens.
struct DisplayFinder {

    /// Returns the NSScreen corresponding to the Xreal glasses, or nil if not found.
    static func xrealScreen() -> NSScreen? {
        let candidates = NSScreen.screens.filter { isXrealDisplay($0) }
        return candidates.first
    }

    /// All non-built-in screens — fallback if Xreal name matching fails.
    static func externalScreens() -> [NSScreen] {
        NSScreen.screens.filter { !$0.isBuiltIn }
    }

    // ── Private ───────────────────────────────────────────────────────────────

    private static func isXrealDisplay(_ screen: NSScreen) -> Bool {
        let name = screen.localizedName.lowercased()
        return name.contains("xreal") || name.contains("nreal") || name.contains("air")
    }
}

private extension NSScreen {
    /// True if this is the built-in display (MacBook panel).
    var isBuiltIn: Bool {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return false
        }
        return CGDisplayIsBuiltin(id) != 0
    }
}
