import AppKit
import AVFoundation

/// Full-screen borderless window on the Xreal display.
///
/// Shows a live capture of the Mac desktop, panned opposite to head movement
/// so the display feels pinned in space. The capture layer is slightly inset
/// so head movement pans within the padding rather than hitting black instantly.
class OverlayWindow: NSWindow {

    private var panLayer = CALayer()
    private let statusLabel = CATextLayer()
    private let crosshair = CAShapeLayer()
    private var captureLayer: AVSampleBufferDisplayLayer?

    private var screenSize: CGSize = .zero

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

        screenSize = screen.frame.size
        setupLayers(bounds: screen.frame)
    }

    // ── Public ────────────────────────────────────────────────────────────────

    /// Attach the live capture layer from ScreenCaptureManager.
    func attachCaptureLayer(_ layer: AVSampleBufferDisplayLayer) {
        captureLayer?.removeFromSuperlayer()

        // Scale capture (Mac retina) down to glasses display size
        let w = screenSize.width
        let h = screenSize.height
        layer.frame = CGRect(x: 0, y: 0, width: w, height: h)
        layer.videoGravity = .resizeAspectFill

        panLayer.insertSublayer(layer, at: 0) // behind grid + labels
        captureLayer = layer

        // Hide placeholder grid now we have real content
        panLayer.sublayers?
            .filter { $0 is CAShapeLayer }
            .forEach { $0.opacity = 0 }
    }

    /// Shift content opposite to head rotation — makes display feel fixed in space.
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

    private func setupLayers(bounds: NSRect) {
        let view = NSView(frame: bounds)
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        contentView = view
        guard let root = view.layer else { return }

        root.backgroundColor = CGColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0)

        // Pan layer — 1.5× screen, centred. Extra space is the "panning room".
        let pw = bounds.width  * 1.5
        let ph = bounds.height * 1.5
        panLayer = CALayer()
        panLayer.bounds   = CGRect(x: 0, y: 0, width: pw, height: ph)
        panLayer.position = CGPoint(x: root.bounds.midX, y: root.bounds.midY)
        panLayer.backgroundColor = CGColor.clear
        root.addSublayer(panLayer)

        // Placeholder grid — visible until screen capture starts
        addGrid(to: panLayer, width: pw, height: ph)
        addLabel(to: panLayer, width: pw, height: ph)

        // Fixed crosshair at screen centre
        let ch = makeCrosshair(centre: CGPoint(x: bounds.width / 2, y: bounds.height / 2))
        root.addSublayer(ch)

        // Status — fixed top-left
        statusLabel.frame = CGRect(x: 16, y: bounds.height - 32, width: 700, height: 20)
        statusLabel.fontSize = 12
        statusLabel.foregroundColor = CGColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 0.9)
        statusLabel.string = "Argos — starting…"
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        root.addSublayer(statusLabel)
    }

    private func addGrid(to layer: CALayer, width: CGFloat, height: CGFloat) {
        let grid = CAShapeLayer()
        let path = CGMutablePath()
        let spacing: CGFloat = 40
        var x: CGFloat = 0
        while x <= width  { path.move(to: CGPoint(x: x, y: 0));     path.addLine(to: CGPoint(x: x, y: height)); x += spacing }
        var y: CGFloat = 0
        while y <= height { path.move(to: CGPoint(x: 0, y: y));     path.addLine(to: CGPoint(x: width, y: y));  y += spacing }
        grid.path = path
        grid.strokeColor = CGColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 0.6)
        grid.lineWidth = 0.5
        grid.fillColor = .clear
        layer.addSublayer(grid)
    }

    private func addLabel(to layer: CALayer, width: CGFloat, height: CGFloat) {
        let label = CATextLayer()
        label.string = "ARGOS"
        label.fontSize = 64
        label.foregroundColor = CGColor(red: 0.25, green: 0.45, blue: 0.7, alpha: 0.5)
        label.alignmentMode = .center
        label.frame = CGRect(x: width / 2 - 160, y: height / 2 - 40, width: 320, height: 80)
        layer.addSublayer(label)
    }

    private func makeCrosshair(centre: CGPoint) -> CAShapeLayer {
        let size: CGFloat = 14
        let path = CGMutablePath()
        path.move(to: CGPoint(x: centre.x - size, y: centre.y))
        path.addLine(to: CGPoint(x: centre.x + size, y: centre.y))
        path.move(to: CGPoint(x: centre.x, y: centre.y - size))
        path.addLine(to: CGPoint(x: centre.x, y: centre.y + size))
        path.addEllipse(in: CGRect(x: centre.x - 3, y: centre.y - 3, width: 6, height: 6))
        let layer = CAShapeLayer()
        layer.path = path
        layer.strokeColor = CGColor(red: 1, green: 0.3, blue: 0.3, alpha: 0.6)
        layer.lineWidth = 1
        layer.fillColor = .clear
        return layer
    }
}
