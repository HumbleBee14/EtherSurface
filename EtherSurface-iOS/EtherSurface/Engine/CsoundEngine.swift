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

        // Start Csound — play() compiles + starts + begins the audio thread.
        cs.play(csdPath)
        isRunning = true

        // Grab channel pointers now that the engine is running.
        // CsoundObj.getInputChannelPtr(_:) returns a float* for the named
        // control channel. All channels used by instr 1 are control-rate
        // (chnget in the CSD).
        for i in 0..<Self.maxTouches {
            xChannelPtrs[i] = cs.getInputChannelPtr(xChannelNames[i])
            yChannelPtrs[i] = cs.getInputChannelPtr(yChannelNames[i])
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
        xChannelPtrs[slot]?.pointee = x
        yChannelPtrs[slot]?.pointee = y
        csound?.sendScore(noteOnScores[slot])
    }

    /// Update the position of an already-playing voice.
    func updatePosition(slot: Int, x: Float, y: Float) {
        guard isRunning, slot >= 0, slot < Self.maxTouches else { return }
        xChannelPtrs[slot]?.pointee = x
        yChannelPtrs[slot]?.pointee = y
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
