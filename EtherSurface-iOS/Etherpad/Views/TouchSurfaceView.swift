import UIKit

protocol TouchSurfaceDelegate: AnyObject {
    func touchBegan(slot: Int, x: Float, y: Float)
    func touchMoved(slot: Int, x: Float, y: Float)
    func touchEnded(slot: Int)
}

final class TouchSurfaceView: UIView {

    weak var delegate: TouchSurfaceDelegate?

    var numberOfNotes: Double = 8.0 {
        didSet { if numberOfNotes != oldValue { setNeedsDisplay() } }
    }

    private var effects: VisualEffects = .current

    private let bgColor     = UIColor(red: 0x3b/255, green: 0x44/255, blue: 0x4b/255, alpha: 1)
    private let lineColor   = UIColor(red: 0x50/255, green: 0x72/255, blue: 0xA7/255, alpha: 1)
    private let circleColor = UIColor(red: 233/255, green: 214/255, blue: 107/255, alpha: 0.5)
    private let glowColor   = UIColor(red: 233/255, green: 214/255, blue: 107/255, alpha: 0.07)
    private let baseRadius: CGFloat = 60
    private let lineWidth: CGFloat = 3

    private var activeVoices: [UITouch: Int] = [:]
    private let maxSlots = CsoundEngine.maxTouches

    private struct Ripple { var origin: CGPoint; var t: CFTimeInterval }
    private var ripples: [Ripple] = []
    private static let rippleDuration: CFTimeInterval = 0.8
    private static let rippleMaxRadius: CGFloat = 220

    private struct TrailPoint { var p: CGPoint; var t: CFTimeInterval }
    private var trails: [UITouch: [TrailPoint]] = [:]
    private static let trailDuration: CFTimeInterval = 1.2

    private var displayLink: CADisplayLink?

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    private func commonInit() {
        isMultipleTouchEnabled = true
        backgroundColor = bgColor
        contentMode = .redraw
        NotificationCenter.default.addObserver(
            self, selector: #selector(effectsChanged),
            name: .visualEffectsChanged, object: nil)
    }

    deinit {
        displayLink?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func effectsChanged() {
        effects = .current
        updateDisplayLink()
        setNeedsDisplay()
    }

    private func updateDisplayLink() {
        // Only run the per-frame loop when an animated effect is active.
        let needsAnimation = effects.contains(.ripple) || effects.contains(.trail)
        if needsAnimation && displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else if !needsAnimation {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        ripples.removeAll { now - $0.t > Self.rippleDuration }
        for key in trails.keys {
            trails[key]?.removeAll { now - $0.t > Self.trailDuration }
        }
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let now = CACurrentMediaTime()

        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(bounds)

        // Pitch column glow under each active touch.
        if effects.contains(.columnGlow), numberOfNotes > 0 {
            let cols = CGFloat(numberOfNotes)
            let colW = bounds.width / cols
            ctx.setFillColor(glowColor.cgColor)
            for (touch, _) in activeVoices {
                let p = touch.location(in: self)
                let idx = max(0, min(Int(cols) - 1, Int(p.x / colW)))
                let r = CGRect(x: CGFloat(idx) * colW, y: 0, width: colW, height: bounds.height)
                ctx.fill(r)
            }
        }

        // Grid lines.
        ctx.setStrokeColor(lineColor.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineJoin(.round)
        let noteCount = max(numberOfNotes, 1)
        for i in 1..<Int(noteCount) {
            let x = bounds.width / CGFloat(noteCount) * CGFloat(i)
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: bounds.height))
        }
        ctx.strokePath()

        // Trail behind each finger.
        if effects.contains(.trail) {
            for (_, pts) in trails {
                for tp in pts {
                    let age = now - tp.t
                    let life = max(0, 1 - age / Self.trailDuration)
                    let alpha = life * 0.35
                    // Older points shrink toward 30% of their original radius for a tapered trail.
                    let r: CGFloat = 18 * (0.3 + 0.7 * CGFloat(life))
                    ctx.setFillColor(UIColor(red: 233/255, green: 214/255, blue: 107/255,
                                             alpha: alpha).cgColor)
                    ctx.fillEllipse(in: CGRect(x: tp.p.x - r, y: tp.p.y - r, width: r * 2, height: r * 2))
                }
            }
        }

        // Ripples.
        if effects.contains(.ripple) {
            for ring in ripples {
                let age = now - ring.t
                let p = CGFloat(age / Self.rippleDuration)
                let radius = Self.rippleMaxRadius * p
                let alpha = max(0, 1 - p) * 0.6
                ctx.setStrokeColor(UIColor(red: 233/255, green: 214/255, blue: 107/255,
                                           alpha: alpha).cgColor)
                ctx.setLineWidth(2)
                ctx.strokeEllipse(in: CGRect(x: ring.origin.x - radius,
                                             y: ring.origin.y - radius,
                                             width: radius * 2, height: radius * 2))
            }
        }

        // Touch circles (size scales with Y if .intensity is on).
        ctx.setFillColor(circleColor.cgColor)
        for (touch, _) in activeVoices {
            let p = touch.location(in: self)
            let scale: CGFloat
            if effects.contains(.intensity) {
                let y = 1 - p.y / bounds.height
                scale = 0.5 + y * 0.7  // 0.5x at bottom → 1.2x at top
            } else {
                scale = 1
            }
            let r = baseRadius * scale
            ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard activeVoices[touch] == nil else { continue }
            guard let slot = nextFreeSlot() else { continue }
            activeVoices[touch] = slot

            let p = touch.location(in: self)
            if effects.contains(.ripple) {
                ripples.append(Ripple(origin: p, t: CACurrentMediaTime()))
            }
            if effects.contains(.trail) {
                trails[touch] = [TrailPoint(p: p, t: CACurrentMediaTime())]
            }

            let (x, y) = normalised(touch)
            delegate?.touchBegan(slot: slot, x: x, y: y)
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let slot = activeVoices[touch] else { continue }
            if effects.contains(.trail) {
                trails[touch, default: []].append(TrailPoint(p: touch.location(in: self),
                                                             t: CACurrentMediaTime()))
            }
            let (x, y) = normalised(touch)
            delegate?.touchMoved(slot: slot, x: x, y: y)
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let slot = activeVoices.removeValue(forKey: touch) else { continue }
            // Keep the trail so it can fade out gracefully.
            delegate?.touchEnded(slot: slot)
        }
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    func cancelAllTouches() {
        for (_, slot) in activeVoices {
            delegate?.touchEnded(slot: slot)
        }
        activeVoices.removeAll()
        setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateDisplayLink()
    }

    private func nextFreeSlot() -> Int? {
        let used = Set(activeVoices.values)
        return (0..<maxSlots).first { !used.contains($0) }
    }

    private func normalised(_ touch: UITouch) -> (Float, Float) {
        let p = touch.location(in: self)
        let x = Float(p.x / bounds.width).clamped(to: 0...1)
        let y = Float(1 - p.y / bounds.height).clamped(to: 0...1)
        return (x, y)
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
