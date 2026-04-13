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
    private var captureActive = false

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

        // Cmd+Q only — global monitor just observes, cannot consume,
        // but terminate() works fine as a side effect.
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
            }
        }

        glassesManager.start()
        // Overlay and capture are both OFF at startup — open manually via menu
        // so you can always see and interact with your Mac display first
    }

    // ── Overlay ───────────────────────────────────────────────────────────────

    private func tryOpenOverlay() {
        guard let screen = DisplayFinder.xrealScreen() ?? DisplayFinder.externalScreens().first else {
            return
        }
        openOverlay(on: screen)
    }

    private func openOverlay(on screen: NSScreen) {
        // Re-use existing window if screen hasn't changed — never close() it
        if let existing = overlayWindow, existing.screen == screen {
            existing.orderFrontRegardless()
            overlayShowing = true
            updateOverlayMenuItem()
            return
        }

        // New screen — hide old window first (don't close)
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
        // Re-assert accessory policy — SCStream permission UI can flip it to .regular
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

        let captureItem = NSMenuItem(title: "Start screen capture",
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
        statusItem?.menu?.item(withTag: 10)?.title = overlayShowing ? "Hide overlay (click top bar)" : "Show overlay on glasses"
    }

    private func updateCaptureMenuItem() {
        statusItem?.menu?.item(withTag: 11)?.title = captureActive ? "Stop screen capture" : "Start screen capture"
    }

    private func updateMenuBarIcon(connected: Bool) {
        let symbol = connected ? "eye.circle.fill" : "eye.circle"
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Argos")
    }

    // ── Actions ───────────────────────────────────────────────────────────────

    @objc func toggleOverlay() {
        if overlayShowing { closeOverlay() } else { tryOpenOverlay() }
    }

    @objc func toggleCapture() {
        if captureActive {
            captureManager.stop()
            captureActive = false
        } else {
            captureActive = true
            Task {
                await captureManager.start()
                overlayWindow?.attachCaptureLayer(captureManager.displayLayer)
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

    // Prevent app from quitting when last window closes
    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }

    // Prevent app from hiding when it loses focus
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows: Bool) -> Bool { true }
}
