import AppKit
import AVFoundation

/// Full-screen borderless window on the Xreal display.
///
/// Two modes:
///   • Idle   — dark background, ARGOS placeholder, grid, crosshair, status bar
///   • Capture — shows live Mac desktop scaled to contentScale; all chrome hidden
class OverlayWindow: NSWindow {

    private var panLayer    = CALayer()
    private let statusLabel = CATextLayer()
    private var crosshairLayer: CAShapeLayer?
    private var argosLabel: CATextLayer?
    private var captureLayer: AVSampleBufferDisplayLayer?
    private var screenSize: CGSize = .zero
    private var hideBarView: HideBarView?

    /// 1.0 = edge-to-edge; 0.75 = floating panel with dark border.
    var contentScale: CGFloat = 0.75

    /// Called when user clicks the top hide-bar.
    var onHideRequested: (() -> Void)?

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
        self.ignoresMouseEvents = false
        self.isMovable = false

        screenSize = screen.frame.size
        setupLayers(bounds: screen.frame)
    }

    // ── Public ────────────────────────────────────────────────────────────────

    /// Attach the live capture layer and switch to capture mode (hides chrome).
    func attachCaptureLayer(_ layer: AVSampleBufferDisplayLayer) {
        captureLayer?.removeFromSuperlayer()

        let pw = panLayer.bounds.width
        let ph = panLayer.bounds.height
        let w  = screenSize.width  * contentScale
        let h  = screenSize.height * contentScale

        layer.frame = CGRect(x: (pw - w) / 2, y: (ph - h) / 2, width: w, height: h)
        layer.videoGravity = .resizeAspectFill
        layer.cornerRadius = 12

        panLayer.insertSublayer(layer, at: 0)
        captureLayer = layer

        setCaptureChrome(visible: false)
    }

    /// Remove capture layer and revert to idle placeholder mode.
    func detachCaptureLayer() {
        captureLayer?.removeFromSuperlayer()
        captureLayer = nil
        setCaptureChrome(visible: true)
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

    /// Update the status text shown in idle mode.
    func setStatus(_ text: String) {
        DispatchQueue.main.async {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.statusLabel.string = text
            CATransaction.commit()
        }
    }

    // ── Private ───────────────────────────────────────────────────────────────

    /// Show or hide the idle-mode chrome (grid, label, crosshair, status, hide-bar text).
    private func setCaptureChrome(visible: Bool) {
        let opacity: Float = visible ? 1 : 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Placeholder elements in panLayer
        panLayer.sublayers?
            .filter { $0 is CAShapeLayer || $0 is CATextLayer }
            .forEach { $0.opacity = opacity }

        // Root-level elements
        crosshairLayer?.opacity = opacity
        statusLabel.opacity     = visible ? 0.9 : 0

        CATransaction.commit()

        // Hide-bar label — visible in both modes but text changes
        hideBarView?.setLabelVisible(visible)
    }

    private func setupLayers(bounds: NSRect) {
        let view = NSView(frame: bounds)
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        contentView = view
        guard let root = view.layer else { return }

        root.backgroundColor = CGColor(red: 0.03, green: 0.03, blue: 0.05, alpha: 1.0)

        // Pan layer — 1.5× screen, centred
        let pw = bounds.width  * 1.5
        let ph = bounds.height * 1.5
        panLayer = CALayer()
        panLayer.bounds   = CGRect(x: 0, y: 0, width: pw, height: ph)
        panLayer.position = CGPoint(x: root.bounds.midX, y: root.bounds.midY)
        panLayer.backgroundColor = CGColor.clear
        root.addSublayer(panLayer)

        addGrid(to: panLayer, width: pw, height: ph)
        let lbl = addLabel(to: panLayer, width: pw, height: ph)
        argosLabel = lbl

        let ch = makeCrosshair(centre: CGPoint(x: bounds.width / 2, y: bounds.height / 2))
        crosshairLayer = ch
        root.addSublayer(ch)

        // Hide-bar — always present, always clickable
        let bar = HideBarView(frame: CGRect(x: 0, y: bounds.height - 28, width: bounds.width, height: 28))
        bar.onHide = { [weak self] in self?.onHideRequested?() }
        view.addSubview(bar)
        hideBarView = bar

        // Status label (idle mode only)
        statusLabel.frame = CGRect(x: 16, y: bounds.height - 26, width: 700, height: 20)
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
        while x <= width  { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: height)); x += spacing }
        var y: CGFloat = 0
        while y <= height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: width, y: y));  y += spacing }
        grid.path = path
        grid.strokeColor = CGColor(red: 0.15, green: 0.25, blue: 0.4, alpha: 0.6)
        grid.lineWidth = 0.5
        grid.fillColor = .clear
        layer.addSublayer(grid)
    }

    @discardableResult
    private func addLabel(to layer: CALayer, width: CGFloat, height: CGFloat) -> CATextLayer {
        let label = CATextLayer()
        label.string = "ARGOS"
        label.fontSize = 64
        label.foregroundColor = CGColor(red: 0.25, green: 0.45, blue: 0.7, alpha: 0.5)
        label.alignmentMode = .center
        label.frame = CGRect(x: width / 2 - 160, y: height / 2 - 40, width: 320, height: 80)
        layer.addSublayer(label)
        return label
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

// ── HideBarView ───────────────────────────────────────────────────────────────

private class HideBarView: NSView {

    var onHide: (() -> Void)?
    private let label = CATextLayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.04)

        label.string = "▲ click to hide overlay"
        label.fontSize = 10
        label.foregroundColor = CGColor(red: 1, green: 1, blue: 1, alpha: 0.25)
        label.alignmentMode = .center
        label.frame = CGRect(x: 0, y: 4, width: frame.width, height: 16)
        layer?.addSublayer(label)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// In capture mode the label fades out — the bar is still clickable.
    func setLabelVisible(_ visible: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        label.opacity = visible ? 1 : 0
        CATransaction.commit()
    }

    override func mouseUp(with event: NSEvent) { onHide?() }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
