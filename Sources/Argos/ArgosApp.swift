import SwiftUI

@main
struct ArgosApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — lives entirely in the menu bar
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var glassesManager = GlassesManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // hide from Dock

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Argos")
            button.action = #selector(toggleMenu)
            button.target = self
        }

        statusItem?.menu = buildMenu()
        glassesManager.start()
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Argos — Xreal Air 2 Pro", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())

        let statusItem = NSMenuItem(title: "Searching for glasses…", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Lock screen position", action: #selector(lockPosition), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Reset orientation", action: #selector(resetOrientation), keyEquivalent: "r"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Quit Argos", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    @objc func toggleMenu() {}

    @objc func lockPosition() {
        glassesManager.lockScreenPosition()
    }

    @objc func resetOrientation() {
        glassesManager.resetOrientation()
    }

    @objc func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateStatus(_ text: String) {
        DispatchQueue.main.async {
            self.statusItem?.menu?.item(withTag: 100)?.title = text
        }
    }
}
