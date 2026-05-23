// TouchSurfaceView.swift — the full-screen multi-touch instrument surface
//
// Port of MultiTouchView.java: dark background, vertical grid lines
// dividing the surface into `numberOfNotes` zones, and a translucent
// yellow circle under each active finger.
//
// Unlike Android, UITouch objects have stable identity for the lifetime
// of a touch, so we don't need to manually track pointer IDs.

import UIKit

protocol TouchSurfaceDelegate: AnyObject {
    func touchBegan(slot: Int, x: Float, y: Float)
    func touchMoved(slot: Int, x: Float, y: Float)
    func touchEnded(slot: Int)
}

final class TouchSurfaceView: UIView {

    // MARK: - Configuration

    weak var delegate: TouchSurfaceDelegate?

    var numberOfNotes: Double = 8.0 {
        didSet {
            if numberOfNotes != oldValue {
                setNeedsDisplay()
            }
        }
    }

    // MARK: - Visual constants (match Android)

    private let bgColor       = UIColor(red: 0x3b/255.0, green: 0x44/255.0, blue: 0x4b/255.0, alpha: 1)
    private let lineColor     = UIColor(red: 0x50/255.0, green: 0x72/255.0, blue: 0xA7/255.0, alpha: 1)
    private let circleColor   = UIColor(red: 233/255.0, green: 214/255.0, blue: 107/255.0, alpha: 0.5)
    private let circleRadius: CGFloat = 60  // points (≈ 60 dp on Android)
    private let lineWidth: CGFloat = 3.0

    // MARK: - Touch tracking

    /// Maps each active UITouch to a voice slot (0..9).
    private var activeVoices: [UITouch: Int] = [:]
    private let maxSlots = CsoundEngine.maxTouches

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = bgColor
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
        backgroundColor = bgColor
        contentMode = .redraw
    }

    // MARK: - Drawing

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Background
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(bounds)

        // Vertical grid lines
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

        // Touch circles
        ctx.setFillColor(circleColor.cgColor)
        for (touch, _) in activeVoices {
            let p = touch.location(in: self)
            let r = CGRect(x: p.x - circleRadius, y: p.y - circleRadius,
                           width: circleRadius * 2, height: circleRadius * 2)
            ctx.fillEllipse(in: r)
        }
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard activeVoices[touch] == nil else { continue }
            guard let slot = nextFreeSlot() else { continue }
            activeVoices[touch] = slot

            let (x, y) = normalised(touch)
            delegate?.touchBegan(slot: slot, x: x, y: y)
        }
        setNeedsDisplay()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let slot = activeVoices[touch] else { continue }
            let (x, y) = normalised(touch)
            delegate?.touchMoved(slot: slot, x: x, y: y)
        }
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let slot = activeVoices.removeValue(forKey: touch) else { continue }
            delegate?.touchEnded(slot: slot)
        }
        setNeedsDisplay()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    /// Lift all active fingers (called when app backgrounds).
    func cancelAllTouches() {
        for (_, slot) in activeVoices {
            delegate?.touchEnded(slot: slot)
        }
        activeVoices.removeAll()
        setNeedsDisplay()
    }

    // MARK: - Helpers

    private func nextFreeSlot() -> Int? {
        let used = Set(activeVoices.values)
        return (0..<maxSlots).first { !used.contains($0) }
    }

    /// Normalise a touch to (0..1, 0..1) with Y inverted (bottom = 0, top = 1).
    private func normalised(_ touch: UITouch) -> (Float, Float) {
        let p = touch.location(in: self)
        let x = Float(p.x / bounds.width).clamped(to: 0...1)
        let y = Float(1 - p.y / bounds.height).clamped(to: 0...1)
        return (x, y)
    }
}

// MARK: - Float clamping helper

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
