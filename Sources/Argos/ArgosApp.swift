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

    let glassesManager = GlassesManager()
    let captureManager = ScreenCaptureManager()

    private var statusItem: NSStatusItem?
    private var overlayWindow: OverlayWindow?
    private var overlayShowing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye.circle", accessibilityDescription: "Argos")
        }
        statusItem?.menu = buildMenu()

        // Wire GlassesManager callbacks
        glassesManager.onOffset = { [weak self] offset in
            self?.overlayWindow?.applyOffset(offset)
        }
        glassesManager.onStatus = { [weak self] text in
            self?.overlayWindow?.setStatus(text)
            self?.updateMenuBarIcon(connected: text.contains("connected"))
        }

        // Listen for display changes (user plugs/unplugs glasses)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        // Global Cmd+Q — works even when overlay covers the display
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
            }
            return event
        }

        glassesManager.start()
        tryOpenOverlay()
        Task { await captureManager.start() }
    }

    // ── Overlay ───────────────────────────────────────────────────────────────

    private func tryOpenOverlay() {
        guard let screen = DisplayFinder.xrealScreen() ?? DisplayFinder.externalScreens().first else {
            return
        }
        openOverlay(on: screen)
    }

    private func openOverlay(on screen: NSScreen) {
        overlayWindow?.close()
        let window = OverlayWindow(screen: screen)
        window.makeKeyAndOrderFront(nil)
        overlayWindow = window
        overlayShowing = true
        updateOverlayMenuItem()
        // Attach live capture once overlay is open
        window.attachCaptureLayer(captureManager.displayLayer)
    }

    private func closeOverlay() {
        overlayWindow?.close()
        overlayWindow = nil
        overlayShowing = false
        updateOverlayMenuItem()
    }

    // ── Menu ──────────────────────────────────────────────────────────────────

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let title = NSMenuItem(title: "Argos", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let toggleItem = NSMenuItem(
            title: "Show overlay on glasses",
            action: #selector(toggleOverlay),
            keyEquivalent: "o"
        )
        toggleItem.tag = 10
        toggleItem.target = self
        menu.addItem(toggleItem)

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

        menu.addItem(NSMenuItem(
            title: "Quit Argos",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }

    private func updateOverlayMenuItem() {
        let title = overlayShowing ? "Hide overlay" : "Show overlay on glasses"
        statusItem?.menu?.item(withTag: 10)?.title = title
    }

    private func updateMenuBarIcon(connected: Bool) {
        let symbol = connected ? "eye.circle.fill" : "eye.circle"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Argos")
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    @objc func toggleOverlay() {
        if overlayShowing {
            closeOverlay()
        } else {
            tryOpenOverlay()
        }
    }

    @objc func lock() {
        Task { await glassesManager.lockScreenPosition() }
    }

    @objc func reset() {
        Task { await glassesManager.resetOrientation() }
    }

    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func screensChanged() {
        if overlayShowing {
            tryOpenOverlay() // re-open on correct screen if displays changed
        }
    }
}
