import AppKit
import SwiftUI

/// Full-screen borderless window that sits on the Xreal display.
/// Pans its content layer opposite to head movement — making the
/// virtual display feel pinned in space.
class OverlayWindow: NSWindow {

    private let contentLayer = CALayer()
    private let panLayer = CALayer()       // child layer that actually moves
    private let statusLabel = CATextLayer()
    private let crosshair = CAShapeLayer() // centre reference point

    // Published so the menu bar can reflect connection state
    var onOrientationUpdate: ((Double, Double, Double) -> Void)?

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

        setupLayers(frame: screen.frame)
    }

    // ── Public ────────────────────────────────────────────────────────────────

    /// Apply a pan offset (points) to the content layer — call from GlassesManager.
    func applyOffset(_ offset: CGPoint) {
        CATransaction.begin()
        CATransaction.setDisableActions(true) // no implicit animation
        panLayer.position = CGPoint(
            x: contentLayer.bounds.midX + offset.x,
            y: contentLayer.bounds.midY + offset.y
        )
        CATransaction.commit()
    }

    /// Update the status overlay text.
    func setStatus(_ text: String) {
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.statusLabel.string = text
            CATransaction.commit()
        }
    }

    // ── Private ───────────────────────────────────────────────────────────────

    private func setupLayers(frame: NSRect) {
        let view = NSView(frame: frame)
        view.wantsLayer = true
        contentView = view
        guard let root = view.layer else { return }

        // Root layer — fills the window
        root.backgroundColor = CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 0.85)

        // Pan layer — this is what moves with your head
        panLayer.frame = root.bounds
        panLayer.backgroundColor = CGColor.clear
        root.addSublayer(panLayer)

        // Grid — visual reference so you can see the panning
        addGrid(to: panLayer, bounds: root.bounds)

        // Crosshair at absolute centre of window (doesn't move)
        let ch = makeCrosshair(centre: CGPoint(x: frame.midX, y: frame.midY))
        root.addSublayer(ch)

        // Status label (top-left, fixed)
        statusLabel.frame = CGRect(x: 20, y: frame.height - 40, width: 500, height: 24)
        statusLabel.fontSize = 14
        statusLabel.foregroundColor = CGColor(red: 0.4, green: 1.0, blue: 0.4, alpha: 1)
        statusLabel.string = "Argos — connecting…"
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        root.addSublayer(statusLabel)
    }

    private func addGrid(to layer: CALayer, bounds: CGRect) {
        let grid = CAShapeLayer()
        let path = CGMutablePath()
        let spacing: CGFloat = 80

        var x = bounds.minX.truncatingRemainder(dividingBy: spacing)
        while x <= bounds.maxX + spacing {
            path.move(to: CGPoint(x: x, y: bounds.minY - spacing))
            path.addLine(to: CGPoint(x: x, y: bounds.maxY + spacing))
            x += spacing
        }
        var y = bounds.minY.truncatingRemainder(dividingBy: spacing)
        while y <= bounds.maxY + spacing {
            path.move(to: CGPoint(x: bounds.minX - spacing, y: y))
            path.addLine(to: CGPoint(x: bounds.maxX + spacing, y: y))
            y += spacing
        }

        grid.path = path
        grid.strokeColor = CGColor(red: 0.2, green: 0.3, blue: 0.4, alpha: 0.5)
        grid.lineWidth = 0.5
        grid.fillColor = .clear
        layer.addSublayer(grid)

        // Argos label in the centre of the pan layer
        let label = CATextLayer()
        label.string = "ARGOS"
        label.fontSize = 48
        label.foregroundColor = CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.3)
        label.font = NSFont.systemFont(ofSize: 48, weight: .thin)
        label.frame = CGRect(x: bounds.midX - 80, y: bounds.midY - 30, width: 160, height: 60)
        label.alignmentMode = .center
        layer.addSublayer(label)
    }

    private func makeCrosshair(centre: CGPoint) -> CAShapeLayer {
        let size: CGFloat = 20
        let path = CGMutablePath()
        path.move(to: CGPoint(x: centre.x - size, y: centre.y))
        path.addLine(to: CGPoint(x: centre.x + size, y: centre.y))
        path.move(to: CGPoint(x: centre.x, y: centre.y - size))
        path.addLine(to: CGPoint(x: centre.x, y: centre.y + size))

        let layer = CAShapeLayer()
        layer.path = path
        layer.strokeColor = CGColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.8)
        layer.lineWidth = 1.5
        return layer
    }
}
