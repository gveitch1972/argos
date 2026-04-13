import AppKit
import SwiftUI

/// Full-screen borderless window that sits on the Xreal display.
///
/// The panLayer is 3× the screen size — the window clips it, acting as a
/// viewport into a larger canvas. Moving the panLayer pans the view without
/// revealing the background.
class OverlayWindow: NSWindow {

    private var panLayer = CALayer()       // oversized canvas — this moves
    private let statusLabel = CATextLayer()
    private let crosshair = CAShapeLayer() // stays fixed at screen centre

    // ── Init ──────────────────────────────────────────────────────────────────

    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.ignoresMouseEvents = true
        self.isMovable = false

        setupLayers(screenBounds: screen.frame)
    }

    // ── Public ────────────────────────────────────────────────────────────────

    /// Shift the canvas by `offset` points to simulate a fixed display in space.
    /// Call from GlassesManager at ~60 Hz.
    func applyOffset(_ offset: CGPoint) {
        guard let root = contentView?.layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panLayer.position = CGPoint(
            x: root.bounds.midX + offset.x,
            y: root.bounds.midY + offset.y
        )
        CATransaction.commit()
    }

    func setStatus(_ text: String) {
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.statusLabel.string = text
            CATransaction.commit()
        }
    }

    // ── Private ───────────────────────────────────────────────────────────────

    private func setupLayers(screenBounds: NSRect) {
        let view = NSView(frame: screenBounds)
        view.wantsLayer = true
        view.layer?.masksToBounds = true  // clips panLayer at screen edges
        contentView = view
        guard let root = view.layer else { return }

        root.backgroundColor = CGColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 0.92)

        // PanLayer — 1.5× screen size, initially centred.
        // The extra margin gives room for stabilisation without wrapping.
        let pw = screenBounds.width * 1.5
        let ph = screenBounds.height * 1.5
        panLayer = CALayer()
        panLayer.bounds = CGRect(x: 0, y: 0, width: pw, height: ph)
        panLayer.position = CGPoint(x: root.bounds.midX, y: root.bounds.midY)
        panLayer.backgroundColor = CGColor.clear
        root.addSublayer(panLayer)

        addGrid(to: panLayer, width: pw, height: ph)
        addCentreLabel(to: panLayer, width: pw, height: ph)

        // Fixed crosshair at exact screen centre — does NOT move
        let ch = makeCrosshair(centre: CGPoint(x: screenBounds.width / 2, y: screenBounds.height / 2))
        root.addSublayer(ch)

        // Status label — fixed top-left
        statusLabel.frame = CGRect(x: 20, y: screenBounds.height - 36, width: 600, height: 22)
        statusLabel.fontSize = 13
        statusLabel.foregroundColor = CGColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 0.9)
        statusLabel.string = "Argos — starting…"
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        root.addSublayer(statusLabel)
    }

    private func addGrid(to layer: CALayer, width: CGFloat, height: CGFloat) {
        let grid = CAShapeLayer()
        let path = CGMutablePath()
        let spacing: CGFloat = 40   // tighter grid

        var x: CGFloat = 0
        while x <= width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: height))
            x += spacing
        }
        var y: CGFloat = 0
        while y <= height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: width, y: y))
            y += spacing
        }

        grid.path = path
        grid.strokeColor = CGColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 0.6)
        grid.lineWidth = 0.5
        grid.fillColor = .clear
        layer.addSublayer(grid)
    }

    private func addCentreLabel(to layer: CALayer, width: CGFloat, height: CGFloat) {
        let label = CATextLayer()
        label.string = "ARGOS"
        label.fontSize = 64
        label.foregroundColor = CGColor(red: 0.25, green: 0.45, blue: 0.7, alpha: 0.25)
        label.alignmentMode = .center
        label.frame = CGRect(x: width / 2 - 160, y: height / 2 - 40, width: 320, height: 80)
        layer.addSublayer(label)

        // Subtle ring at canvas centre
        let ring = CAShapeLayer()
        let r: CGFloat = 60
        ring.path = CGPath(ellipseIn: CGRect(x: width/2 - r, y: height/2 - r, width: r*2, height: r*2), transform: nil)
        ring.strokeColor = CGColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.3)
        ring.fillColor = .clear
        ring.lineWidth = 1
        layer.addSublayer(ring)
    }

    private func makeCrosshair(centre: CGPoint) -> CAShapeLayer {
        let size: CGFloat = 16
        let path = CGMutablePath()
        path.move(to: CGPoint(x: centre.x - size, y: centre.y))
        path.addLine(to: CGPoint(x: centre.x + size, y: centre.y))
        path.move(to: CGPoint(x: centre.x, y: centre.y - size))
        path.addLine(to: CGPoint(x: centre.x, y: centre.y + size))

        // Small circle around crosshair centre
        path.addEllipse(in: CGRect(x: centre.x - 4, y: centre.y - 4, width: 8, height: 8))

        let layer = CAShapeLayer()
        layer.path = path
        layer.strokeColor = CGColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.7)
        layer.lineWidth = 1
        layer.fillColor = .clear
        return layer
    }
}
