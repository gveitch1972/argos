import SwiftUI
import AppKit

@main
struct ArgosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(manager: appDelegate.glassesManager)
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    let glassesManager    = GlassesManager()
    let captureManager    = ScreenCaptureManager()
    let virtualDisplay    = VirtualDisplayManager()

    private var statusItem: NSStatusItem?
    private var overlayWindow: OverlayWindow?
    private var overlayShowing  = false
    private var captureActive   = false
    private var virtualActive   = false   // virtual display is up

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye.circle", accessibilityDescription: "Argos")
        }
        statusItem?.menu = buildMenu()

        glassesManager.onOffset = { [weak self] offset in
            self?.overlayWindow?.applyOffset(offset)
        }
        glassesManager.onStatus = { [weak self] text in
            self?.overlayWindow?.setStatus(text)
            self?.updateMenuBarIcon(connected: text.contains("connected"))
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Cmd+Q — global monitor just observes; terminate() is the side-effect we want
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
            }
        }

        glassesManager.start()
        // Everything else is opt-in via menu
    }

    func applicationWillTerminate(_ notification: Notification) {
        virtualDisplay.destroy()
    }

    // ── Overlay ───────────────────────────────────────────────────────────────

    private func tryOpenOverlay() {
        // Exclude the virtual display we created — it has no physical panel
        let virtualID = virtualDisplay.displayID
        let screen = DisplayFinder.xrealScreen()
            ?? DisplayFinder.externalScreens().first(where: { screen in
                guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
                else { return true }
                return id != virtualID
            })
        guard let screen else { return }
        openOverlay(on: screen)
    }

    private func openOverlay(on screen: NSScreen) {
        if let existing = overlayWindow, existing.screen == screen {
            existing.orderFrontRegardless()
            if captureActive {
                existing.attachCaptureLayer(captureManager.displayLayer)
            }
            overlayShowing = true
            updateOverlayMenuItem()
            return
        }

        overlayWindow?.orderOut(nil)

        let window = OverlayWindow(screen: screen)
        window.onHideRequested = { [weak self] in self?.closeOverlay() }
        window.orderFrontRegardless()
        overlayWindow = window
        overlayShowing = true
        if captureActive {
            window.attachCaptureLayer(captureManager.displayLayer)
        }
        updateOverlayMenuItem()
        updateCaptureMenuItem()
    }

    private func closeOverlay() {
        overlayWindow?.orderOut(nil)
        overlayShowing = false
        NSApp.setActivationPolicy(.accessory)
        updateOverlayMenuItem()
    }

    // ── Menu ──────────────────────────────────────────────────────────────────

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let title = NSMenuItem(title: "Argos", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "Show overlay on glasses",
                                    action: #selector(toggleOverlay),
                                    keyEquivalent: "")
        toggleItem.tag = 10
        toggleItem.target = self
        menu.addItem(toggleItem)

        let virtualItem = NSMenuItem(title: "Create virtual display",
                                     action: #selector(toggleVirtualDisplay),
                                     keyEquivalent: "")
        virtualItem.tag = 12
        virtualItem.target = self
        menu.addItem(virtualItem)

        let captureItem = NSMenuItem(title: "Start capture → glasses",
                                     action: #selector(toggleCapture),
                                     keyEquivalent: "")
        captureItem.tag = 11
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(.separator())

        let lockItem = NSMenuItem(title: "Lock screen position", action: #selector(lock), keyEquivalent: "l")
        lockItem.target = self
        menu.addItem(lockItem)

        let resetItem = NSMenuItem(title: "Reset orientation", action: #selector(reset), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(title: "Quit Argos",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        return menu
    }

    private func updateOverlayMenuItem() {
        let title: String
        if overlayShowing {
            title = captureActive ? "Hide overlay (capture keeps running)" : "Hide overlay"
        } else {
            title = captureActive ? "Show overlay (capture running)" : "Show overlay on glasses"
        }
        statusItem?.menu?.item(withTag: 10)?.title = title
    }

    private func updateCaptureMenuItem() {
        statusItem?.menu?.item(withTag: 11)?.title =
            captureActive ? "Stop capture" : "Start capture → glasses"
    }

    private func updateVirtualMenuItem() {
        let base = virtualActive ? "Destroy virtual display" : "Create virtual display"
        let info = virtualActive ? " (id=\(virtualDisplay.displayID ?? 0))" : ""
        statusItem?.menu?.item(withTag: 12)?.title = base + info
    }

    private func updateMenuBarIcon(connected: Bool) {
        let symbol = connected ? "eye.circle.fill" : "eye.circle"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Argos")
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    @objc func toggleOverlay() {
        if overlayShowing { closeOverlay() } else { tryOpenOverlay() }
    }

    @objc func toggleVirtualDisplay() {
        if virtualActive {
            // Also stop capture if it was targeting the virtual display
            if captureActive {
                captureManager.stop()
                captureActive = false
                updateCaptureMenuItem()
            }
            virtualDisplay.destroy()
            virtualActive = false
        } else {
            virtualActive = virtualDisplay.create()
            if !virtualActive {
                showEntitlementAlert()
            }
        }
        updateVirtualMenuItem()
    }

    @objc func toggleCapture() {
        if captureActive {
            captureManager.stop()
            overlayWindow?.detachCaptureLayer()
            captureActive = false
            updateCaptureMenuItem()
            return
        }

        // Auto-open the overlay if it isn't showing — nothing to display capture into otherwise
        if !overlayShowing { tryOpenOverlay() }

        captureActive = true
        let targetID = virtualDisplay.displayID ?? 0
        Task {
            await captureManager.start(displayID: targetID)
            // Attach after start() so the layer is primed before hitting the window
            if let win = overlayWindow {
                win.attachCaptureLayer(captureManager.displayLayer)
            }
        }
        updateCaptureMenuItem()
    }

    @objc func lock()  { Task { await glassesManager.lockScreenPosition() } }
    @objc func reset() { Task { await glassesManager.resetOrientation() } }

    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func screensChanged() {
        if overlayShowing { tryOpenOverlay() }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func showEntitlementAlert() {
        let alert = NSAlert()
        alert.messageText = "Virtual display unavailable"
        alert.informativeText =
            "CGVirtualDisplay requires the com.apple.developer.virtual-display entitlement.\n\n" +
            "Make sure the binary is code-signed with that entitlement (run `make sign` or `make build`)."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows: Bool) -> Bool { true }
}
