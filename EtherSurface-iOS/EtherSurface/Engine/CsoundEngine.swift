// CsoundEngine.swift — thin wrapper around CsoundObj for EtherSurface
//
// CsoundObj comes from the Csound for iOS framework. It provides:
//   play(_:)              – compile + start + begin audio (async)
//   stop()                – halt audio
//   sendScore(_:)         – inject a score event (e.g. "i1.0 0 -2 0")
//   getInputChannelPtr:channelType: – float* for a named control channel
//   addListener(_:)       – fires csoundObjStarted: when mCsData.cs is live
//
// This wrapper pre-builds the channel pointers and score strings for
// 10 touch slots, mirroring the Android MainActivity approach.

import Foundation

final class CsoundEngine {

    // MARK: - Constants

    static let maxTouches = 10

    // MARK: - Csound instance

    private(set) var csound: CsoundObj?
    private var isRunning = false
    private var listenerBridge: CsoundListenerBridge?

    // MARK: - Pre-built channel pointers (set after csoundObjStarted:)

    private var xChannelPtrs: [UnsafeMutablePointer<Float>?] = Array(repeating: nil, count: maxTouches)
    private var yChannelPtrs: [UnsafeMutablePointer<Float>?] = Array(repeating: nil, count: maxTouches)

    // MARK: - Pre-built score strings (never allocate in the touch loop)

    private let noteOnScores:  [String]
    private let noteOffScores: [String]
    fileprivate let xChannelNames: [String]
    fileprivate let yChannelNames: [String]

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

        // Register a CsoundObjListener BEFORE calling play(). Its
        // csoundObjStarted: callback fires once mCsData.cs is set and the
        // engine is rendering — that is the only safe moment to call
        // getInputChannelPtr. Calling it sooner (the previous polling-loop
        // approach) crashes with EXC_BAD_ACCESS because csoundGetChannelPtr
        // dereferences a not-yet-initialised CSOUND*.
        let bridge = CsoundListenerBridge(engine: self)
        listenerBridge = bridge
        cs.add(bridge)

        cs.play(csdPath)
        isRunning = true
    }

    /// Called by the listener bridge on the Csound performance thread,
    /// once the engine is up and channel pointers are valid.
    fileprivate func bindChannelPointers() {
        guard let cs = csound else { return }
        let kType = controlChannelType(CSOUND_CONTROL_CHANNEL.rawValue)
        var xPtrs = Array<UnsafeMutablePointer<Float>?>(repeating: nil, count: Self.maxTouches)
        var yPtrs = Array<UnsafeMutablePointer<Float>?>(repeating: nil, count: Self.maxTouches)
        for i in 0..<Self.maxTouches {
            xPtrs[i] = cs.getInputChannelPtr(xChannelNames[i], channelType: kType)
            yPtrs[i] = cs.getInputChannelPtr(yChannelNames[i], channelType: kType)
        }
        DispatchQueue.main.async {
            self.xChannelPtrs = xPtrs
            self.yChannelPtrs = yPtrs
            let bound = xPtrs.compactMap { $0 }.count
            print("[EtherSurface] Csound channels bound: \(bound)/\(Self.maxTouches)")
        }
    }

    func stop() {
        guard isRunning else { return }
        csound?.stop()
        csound = nil
        listenerBridge = nil
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
    /// pointer if available (fast — direct memory write); silently drops
    /// the write if the engine has not finished starting yet. This is
    /// fine because the engine is usually ready in <100 ms and the first
    /// human touch arrives much later.
    private func writeChannel(slot: Int, x: Float, y: Float) {
        guard let xp = xChannelPtrs[slot], let yp = yChannelPtrs[slot] else { return }
        xp.pointee = x
        yp.pointee = y
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
            csound?.sendScore("i103 0 0.5 \(steps[0])")
        } else if steps.count >= 14 {
            let args = steps.prefix(14).map { String($0) }.joined(separator: " ")
            csound?.sendScore("i103 0 0.5 \(args)")
        }
    }
}

// MARK: - Listener bridge
//
// CsoundObjListener is an Obj-C protocol; the listener must inherit from
// NSObject. This tiny adapter forwards csoundObjStarted: into the
// CsoundEngine instance.

private final class CsoundListenerBridge: NSObject, CsoundObjListener {
    weak var engine: CsoundEngine?
    init(engine: CsoundEngine) { self.engine = engine }

    func csoundObjStarted(_ csoundObj: CsoundObj!) {
        engine?.bindChannelPointers()
    }

    func csoundObjCompleted(_ csoundObj: CsoundObj!) { }
}
