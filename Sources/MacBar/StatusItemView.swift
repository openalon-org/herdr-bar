import AppKit
import HerdrCore

final class StatusItemView: NSView {
    private var counts: [AgentStatus: Int] = [:]
    private var online = false
    private var pulse: CGFloat = 0
    private let pulseClock = PulseClock()

    func update(counts: [AgentStatus: Int], online: Bool) {
        self.counts = counts
        self.online = online
        syncPulse()
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func layout() {
        super.layout()
        needsDisplay = true
    }

    /// Marks only. The press-highlight capsule is NSStatusBarButton's.
    override var isOpaque: Bool { false }

    override var isFlipped: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = false
        layer?.backgroundColor = nil
    }

    deinit {
        pulseClock.stop()
    }

    override func draw(_ dirtyRect: NSRect) {
        // Do not call super.draw: NSView fills nothing useful, and a layer-
        // backed ancestor would paint an island over NSStatusBarButton's glass.
        let visible = MenuBarGlance.glanceableStatuses(counts, online: online)
        let alpha: CGFloat = online ? 1 : 0.45

        if visible.isEmpty {
            let size = MenuBarGlance.dotSize
            let dot = NSRect(x: bounds.midX - size / 2, y: bounds.midY - size / 2, width: size, height: size)
            NSColor.tertiaryLabelColor.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: dot).fill()
            return
        }

        let cluster = MenuBarGlance.clusterWidth(counts, online: online)
        var x = ((bounds.width - cluster) / 2).rounded(.toNearestOrAwayFromZero)
        for (index, status) in visible.enumerated() {
            let count = counts[status] ?? 0
            let live = count > 0
            let color = NSColor(herdrHex: status.hexColor).withAlphaComponent(alpha)

            if status.needsAttention { x += MenuBarGlance.haloLeading }

            if status == .working {
                x = drawWorkingFlower(at: x, color: color, spinning: live && online)
            } else {
                let size = MenuBarGlance.dotSize
                let dot = NSRect(x: x, y: bounds.midY - size / 2, width: size, height: size)
                if status.needsAttention, live, online {
                    drawAttentionHalo(around: dot, color: color)
                }
                color.setFill()
                NSBezierPath(ovalIn: dot).fill()
                x += size + MenuBarGlance.markGap
            }

            let text = String(count) as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.labelColor.withAlphaComponent(alpha),
            ]
            let size = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: x, y: bounds.midY - size.height / 2), withAttributes: attrs)
            x += CGFloat(max(1, String(count).count)) * MenuBarGlance.digitWidth
            if index < visible.count - 1 { x += MenuBarGlance.chipGap }
        }
    }

    /// Claude Code Darwin spinner in the working chip. Same 120ms ping-pong as the dashboard.
    @discardableResult
    private func drawWorkingFlower(at x: CGFloat, color: NSColor, spinning: Bool) -> CGFloat {
        let glyph = (spinning ? WorkingSpinner.frame() : WorkingSpinner.restGlyph) as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: color,
        ]
        let size = glyph.size(withAttributes: attrs)
        let slot = MenuBarGlance.workingMarkWidth
        glyph.draw(
            at: NSPoint(x: x + (slot - size.width) / 2, y: bounds.midY - size.height / 2),
            withAttributes: attrs
        )
        return x + slot + MenuBarGlance.markGap
    }

    /// Soft expanding ring, same idea as cmux's attention halo: sine ease, never a hard blink.
    private func drawAttentionHalo(around dot: NSRect, color: NSColor) {
        let t = (sin(pulse) + 1) * 0.5
        let cx = dot.midX
        let cy = dot.midY
        let radius = 4.4 + 1.1 * t
        let glow = NSRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
        color.withAlphaComponent(0.14 + 0.22 * t).setFill()
        NSBezierPath(ovalIn: glow).fill()
        let ring = NSBezierPath(ovalIn: glow.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 1.1
        color.withAlphaComponent(0.36 + 0.40 * t).setStroke()
        ring.stroke()
    }

    private func syncPulse() {
        let hasAttention = online && AgentStatus.order.contains { $0.needsAttention && (counts[$0] ?? 0) > 0 }
        let hasWorking = online && (counts[.working] ?? 0) > 0
        if hasAttention {
            pulseClock.start(interval: 1.0 / 30.0) { [weak self] in
                Task { @MainActor in
                    self?.advancePulse()
                }
            }
        } else if hasWorking {
            pulseClock.start(interval: WorkingSpinner.frameDuration) { [weak self] in
                Task { @MainActor in
                    self?.needsDisplay = true
                }
            }
            pulse = 0
        } else {
            pulseClock.stop()
            pulse = 0
        }
    }

    private func advancePulse() {
        pulse += (.pi * 2) / 48
        if pulse > .pi * 2 { pulse -= .pi * 2 }
        needsDisplay = true
    }
}

/// Isolated from NSView so Swift 6 deinit / timer callbacks stay legal.
private final class PulseClock: @unchecked Sendable {
    private var timer: Timer?
    private var running = false
    private var interval: TimeInterval = 0

    func start(interval: TimeInterval, tick: @escaping @Sendable () -> Void) {
        if running, self.interval == interval { return }
        stop()
        running = true
        self.interval = interval
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        running = false
        interval = 0
    }

    deinit {
        timer?.invalidate()
    }
}

extension NSColor {
    convenience init(herdrHex hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        self.init(
            calibratedRed: CGFloat((int >> 16) & 0xFF) / 255,
            green: CGFloat((int >> 8) & 0xFF) / 255,
            blue: CGFloat(int & 0xFF) / 255,
            alpha: 1
        )
    }
}
