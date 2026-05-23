// CsoundEngine.swift — thin wrapper around CsoundObj for EtherSurface
//
// CsoundObj comes from the Csound for iOS framework. It provides:
//   play(_:)              – compile + start + begin audio
//   stop()                – halt audio
//   sendScore(_:)         – inject a score event (e.g. "i1.0 0 -2 0")
//   getInputChannelPtr(_:) – get a float* for a named control channel
//
// This wrapper pre-builds the channel pointers and score strings for
// 10 touch slots, exactly mirroring the Android MainActivity approach.

import Foundation

// ── Forward declaration ─────────────────────────────────────────────
// CsoundObj is an Objective-C class provided by the Csound iOS framework.
// It is imported via the bridging header (EtherSurface-Bridging-Header.h).

final class CsoundEngine {

    // MARK: - Constants

    static let maxTouches = 10

    // MARK: - Csound instance

    private(set) var csound: CsoundObj?
    private var isRunning = false

    // MARK: - Pre-built channel pointers (set after play)

    private var xChannelPtrs: [UnsafeMutablePointer<Float>?] = Array(repeating: nil, count: maxTouches)
    private var yChannelPtrs: [UnsafeMutablePointer<Float>?] = Array(repeating: nil, count: maxTouches)

    // MARK: - Pre-built score strings (never allocate in the touch loop)

    private let noteOnScores:  [String]
    private let noteOffScores: [String]
    private let xChannelNames: [String]
    private let yChannelNames: [String]

    // MARK: - Init

    init() {
        var onScores  = [String]()
        var offScores = [String]()
        var xNames    = [String]()
        var yNames    = [String]()
        for i in 0..<Self.maxTouches {
            xNames.append("touch.\(i).x")
            yNames.append("touch.\(i).y")
            onScores.append("i1.\(i) 0 -2 \(i)")
            offScores.append("i-1.\(i) 0 0 \(i)")
        }
        self.xChannelNames = xNames
        self.yChannelNames = yNames
        self.noteOnScores  = onScores
        self.noteOffScores = offScores
    }

    // MARK: - Lifecycle

    /// Compile the bundled CSD and start the audio engine.
    func start() {
        guard !isRunning else { return }

        guard let csdPath = Bundle.main.path(forResource: "etherpad", ofType: "csd") else {
            print("[EtherSurface] etherpad.csd not found in bundle")
            return
        }

        let cs = CsoundObj()
        csound = cs

        // CsoundObj.play(_:) is asynchronous — it spawns a render thread and
        // returns immediately. The channel pointers are only valid *after*
        // the orchestra has been compiled. Asking for them on the same tick
        // returns nil and every touch becomes a silent no-op.
        cs.play(csdPath)
        isRunning = true

        // Poll for channel readiness on a background queue so the UI thread
        // is not blocked. Retry every 20 ms for up to 2 s. Once the first
        // channel pointer is non-nil the engine is up; grab all 20 pointers
        // and we're done.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let deadline = Date().addingTimeInterval(2.0)
            while Date() < deadline {
                if let probe = cs.getInputChannelPtr(self.xChannelNames[0]) {
                    var xPtrs = Array<UnsafeMutablePointer<Float>?>(
                        repeating: nil, count: Self.maxTouches)
                    var yPtrs = Array<UnsafeMutablePointer<Float>?>(
                        repeating: nil, count: Self.maxTouches)
                    xPtrs[0] = probe
                    yPtrs[0] = cs.getInputChannelPtr(self.yChannelNames[0])
                    for i in 1..<Self.maxTouches {
                        xPtrs[i] = cs.getInputChannelPtr(self.xChannelNames[i])
                        yPtrs[i] = cs.getInputChannelPtr(self.yChannelNames[i])
                    }
                    DispatchQueue.main.async {
                        self.xChannelPtrs = xPtrs
                        self.yChannelPtrs = yPtrs
                        print("[EtherSurface] Csound channels bound")
                    }
                    return
                }
                Thread.sleep(forTimeInterval: 0.02)
            }
            print("[EtherSurface] Csound channels never became available — is the real CsoundObj framework linked? See docs/SETUP_CSOUND.md")
        }
    }

    func stop() {
        guard isRunning else { return }
        csound?.stop()
        csound = nil
        isRunning = false

        for i in 0..<Self.maxTouches {
            xChannelPtrs[i] = nil
            yChannelPtrs[i] = nil
        }
    }

    // MARK: - Touch interface (called from the touch surface)

    /// Start a held note for voice slot `slot` at normalised (x, y).
    func noteOn(slot: Int, x: Float, y: Float) {
        guard isRunning, slot >= 0, slot < Self.maxTouches else { return }
        writeChannel(slot: slot, x: x, y: y)
        csound?.sendScore(noteOnScores[slot])
    }

    /// Update the position of an already-playing voice.
    func updatePosition(slot: Int, x: Float, y: Float) {
        guard isRunning, slot >= 0, slot < Self.maxTouches else { return }
        writeChannel(slot: slot, x: x, y: y)
    }

    /// Set the touch.N.x / touch.N.y channels for `slot`. Uses the cached
    /// pointer if available (fast — direct memory write) and falls back to
    /// the score event `chnset` form if the pointer hasn't been bound yet.
    private func writeChannel(slot: Int, x: Float, y: Float) {
        if let xp = xChannelPtrs[slot], let yp = yChannelPtrs[slot] {
            xp.pointee = x
            yp.pointee = y
        } else {
            // Pointer not bound yet — fall back to score-event channel set.
            csound?.sendScore("chnset \(x), \"\(xChannelNames[slot])\"")
            csound?.sendScore("chnset \(y), \"\(yChannelNames[slot])\"")
        }
    }

    /// Release voice slot `slot`.
    func noteOff(slot: Int) {
        guard isRunning, slot >= 0, slot < Self.maxTouches else { return }
        csound?.sendScore(noteOffScores[slot])
    }

    /// Release all held voices (e.g. when backgrounding).
    func allNotesOff() {
        for i in 0..<Self.maxTouches {
            noteOff(slot: i)
        }
    }

    // MARK: - Parameter setters (mirror instr 100–104 in the CSD)

    func setSize(_ size: Int) {
        csound?.sendScore("i100 0 0.5 \(size)")
    }

    func setKey(_ key: Int) {
        csound?.sendScore("i101 0 0.5 \(key)")
    }

    func setOctave(_ octave: Int) {
        csound?.sendScore("i102 0 0.5 \(octave)")
    }

    func setSound(_ sound: Int) {
        csound?.sendScore("i104 0 0.5 \(sound)")
    }

    /// Set the scale.
    /// Pass `[-1]` for Bohlen-Pierce, `[-2]` for Overtone Low,
    /// `[-3]` for Overtone High, or a 14-element array for ET scales.
    func setScale(_ steps: [Int]) {
        if steps.count == 1 && steps[0] < 0 {
            // Sentinels: -1 = Bohlen-Pierce, -2 = Overtone Low, -3 = Overtone High
            csound?.sendScore("i103 0 0.5 \(steps[0])")
        } else if steps.count >= 14 {
            let args = steps.prefix(14).map { String($0) }.joined(separator: " ")
            csound?.sendScore("i103 0 0.5 \(args)")
        }
    }
}
