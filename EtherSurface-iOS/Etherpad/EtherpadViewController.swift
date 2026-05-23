// EtherpadViewController.swift — main view controller
//
// Faithful port of MainActivity.java: full-screen touch surface with a
// toolbar row of five popup menus (Scale, Key, Octave, Size, Sound, About).
// Every option, every scale array, every Csound score message is identical
// to the Android version.

import UIKit
import AVFoundation

final class EtherpadViewController: UIViewController, TouchSurfaceDelegate {

    // MARK: - Sub-components

    private let engine  = CsoundEngine()
    private let surface = TouchSurfaceView()

    // MARK: - Toolbar buttons (kept so we can refresh their menus when
    // selection changes — UIMenu is immutable, so to update the
    // checkmark we have to rebuild and reassign the whole menu.)

    private var scaleBtn:  UIBarButtonItem!
    private var keyBtn:    UIBarButtonItem!
    private var octBtn:    UIBarButtonItem!
    private var sizeBtn:   UIBarButtonItem!
    private var soundBtn:  UIBarButtonItem!

    // MARK: - Current selections (mirror the CSD's init defaults)

    private var selectedScale:  String = "Default"          // matches scaleDefault + giscale_type=0
    private var selectedKey:    Int    = 0                  // C
    private var selectedOctave: Int    = 4                  // 0 (middle) — Csound value 4
    private var selectedSize:   Int    = 8                  // matches gisize init 8
    private var selectedSound:  Int    = 0                  // Ether Pad

    // MARK: - Scales (exact copies from MainActivity.java)

    private let scaleMajor:   [Int] = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23]
    private let scaleMinor:   [Int] = [0, 2, 3, 5, 7, 8, 11, 12, 14, 15, 17, 19, 20, 23]
    private let scalePent:    [Int] = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 30]
    private let scaleBlues:   [Int] = [0, 3, 5, 6, 7, 10, 12, 15, 17, 18, 19, 22, 24, 27]
    private let scaleChrom:   [Int] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
    private let scaleWhole:   [Int] = [0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26]
    private let scaleOct:     [Int] = [0, 1, 3, 4, 6, 7, 9, 10, 12, 13, 15, 16, 18, 19, 21]
    private let scaleFlam:    [Int] = [0, 1, 4, 5, 7, 8, 11, 12, 13, 16, 17, 19, 21, 22]
    private let scaleDefault: [Int] = [0, 2, 4, 7, 9, 11, 12, 14, 16, 19, 21, 24, 26, 28]
    private let scaleBP:      [Int] = [-1]
    // Overtone series use giscale_type 2 and 3 in the CSD
    private let scaleOTLow:   [Int] = [-2]  // sentinel: giscale_type = 2
    private let scaleOTHigh:  [Int] = [-3]  // sentinel: giscale_type = 3

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        configureAudioSession()

        surface.delegate = self
        surface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(surface)
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            surface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            surface.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        configureToolbar()
        engine.start()

        NotificationCenter.default.addObserver(
            self, selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    // Edge touches belong to the synth, not the system swipe-up gestures.
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    deinit {
        NotificationCenter.default.removeObserver(self)
        engine.allNotesOff()
        engine.stop()
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)  // ~5 ms
            try session.setActive(true)
        } catch {
            print("[Etherpad] Audio session setup failed: \(error)")
        }
    }

    @objc private func appWillResignActive() {
        surface.cancelAllTouches()
        engine.allNotesOff()
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        if type == .began {
            surface.cancelAllTouches()
            engine.allNotesOff()
        }
        // On .ended, AVAudioSession resumes automatically for .playback category.
    }

    // MARK: - TouchSurfaceDelegate

    func touchBegan(slot: Int, x: Float, y: Float) {
        engine.noteOn(slot: slot, x: x, y: y)
    }

    func touchMoved(slot: Int, x: Float, y: Float) {
        engine.updatePosition(slot: slot, x: x, y: y)
    }

    func touchEnded(slot: Int) {
        engine.noteOff(slot: slot)
    }

    // MARK: - Toolbar (mirrors Android ActionBar with 5 popup buttons + About)

    private func configureToolbar() {
        let toolbar = UIToolbar()
        toolbar.barStyle = .black
        toolbar.isTranslucent = false
        toolbar.barTintColor = UIColor(red: 0x3b/255, green: 0x44/255, blue: 0x4b/255, alpha: 1)
        toolbar.tintColor = .white
        toolbar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(toolbar)
        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        scaleBtn  = UIBarButtonItem(title: "Scale",  menu: buildScaleMenu())
        keyBtn    = UIBarButtonItem(title: "Key",    menu: buildKeyMenu())
        octBtn    = UIBarButtonItem(title: "Octave", menu: buildOctaveMenu())
        sizeBtn   = UIBarButtonItem(title: "Size",   menu: buildSizeMenu())
        soundBtn  = UIBarButtonItem(title: "Sound",  menu: buildSoundMenu())
        let aboutBtn = UIBarButtonItem(title: "About", style: .plain, target: self,
                                       action: #selector(showAbout))

        toolbar.items = [scaleBtn, flex, keyBtn, flex, octBtn, flex, sizeBtn, flex, soundBtn, flex, aboutBtn]
    }

    /// Build a UIAction with a checkmark when `isSelected` is true.
    /// If `isDefault`, prepend a small bullet so the user can identify
    /// the CSD's original default value at a glance. (UIAction titles
    /// are plain strings; iOS does not render attributed-string underlines
    /// inside UIMenu rows, so a leading glyph is the cleanest equivalent.)
    private func makeAction(title: String, isSelected: Bool, isDefault: Bool = false,
                            handler: @escaping () -> Void) -> UIAction {
        let displayTitle = isDefault ? "• \(title)" : title
        return UIAction(title: displayTitle, state: isSelected ? .on : .off) { _ in handler() }
    }

    // MARK: - Menus
    //
    // Each menu shows a checkmark next to the currently selected option.
    // After a selection, we update the stored state, push the value to
    // Csound, refresh the button title to show the choice inline (e.g.
    // "Scale: Major"), and rebuild the menu so the checkmark moves to
    // the new row.

    // Scale (12 items — exact match of scales.xml)

    private struct ScaleOption {
        let name: String
        let steps: [Int]
    }

    private var scaleOptions: [ScaleOption] {
        [
            .init(name: "Default",     steps: scaleDefault),
            .init(name: "Major",       steps: scaleMajor),
            .init(name: "Minor",       steps: scaleMinor),
            .init(name: "Pentatonic",  steps: scalePent),
            .init(name: "Flamenco",    steps: scaleFlam),
            .init(name: "Blues",       steps: scaleBlues),
            .init(name: "Chromatic",   steps: scaleChrom),
            .init(name: "Whole-Tone",  steps: scaleWhole),
            .init(name: "Octatonic",   steps: scaleOct),
            .init(name: "Bohlen-Pierce", steps: scaleBP),
            .init(name: "Overtone Series Low",  steps: scaleOTLow),
            .init(name: "Overtone Series High", steps: scaleOTHigh),
        ]
    }

    private func buildScaleMenu() -> UIMenu {
        let actions = scaleOptions.map { opt in
            makeAction(title: opt.name,
                       isSelected: opt.name == selectedScale,
                       isDefault: opt.name == "Default") { [weak self] in
                guard let self = self else { return }
                self.selectedScale = opt.name
                self.engine.setScale(opt.steps)
                self.scaleBtn.title = "Scale: \(opt.name)"
                self.scaleBtn.menu = self.buildScaleMenu()
            }
        }
        return UIMenu(title: "Scale", children: actions)
    }

    // Key (C through B — 12 chromatic roots)

    private let keyNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    private func buildKeyMenu() -> UIMenu {
        let actions = keyNames.enumerated().map { i, name in
            makeAction(title: name, isSelected: i == selectedKey, isDefault: i == 0) { [weak self] in
                guard let self = self else { return }
                self.selectedKey = i
                self.engine.setKey(i)
                self.keyBtn.title = "Key: \(name)"
                self.keyBtn.menu = self.buildKeyMenu()
            }
        }
        return UIMenu(title: "Key", children: actions)
    }

    // Octave (labels 2..-2 → Csound values 6..2)

    private let octaveLabels = ["2", "1", "0", "-1", "-2"]
    private let octaveValues = [6, 5, 4, 3, 2]

    private func buildOctaveMenu() -> UIMenu {
        let actions = zip(octaveLabels, octaveValues).map { label, val in
            makeAction(title: label, isSelected: val == selectedOctave, isDefault: val == 4) { [weak self] in
                guard let self = self else { return }
                self.selectedOctave = val
                self.engine.setOctave(val)
                self.octBtn.title = "Octave: \(label)"
                self.octBtn.menu = self.buildOctaveMenu()
            }
        }
        return UIMenu(title: "Octave", children: actions)
    }

    // Size (4 through 14)

    private func buildSizeMenu() -> UIMenu {
        let actions = (4...14).map { n in
            makeAction(title: "\(n)", isSelected: n == selectedSize, isDefault: n == 8) { [weak self] in
                guard let self = self else { return }
                self.selectedSize = n
                self.engine.setSize(n)
                self.surface.numberOfNotes = Double(n)
                self.sizeBtn.title = "Size: \(n)"
                self.sizeBtn.menu = self.buildSizeMenu()
            }
        }
        return UIMenu(title: "Size", children: actions)
    }

    // Sound (5 sounds — exact match of sounds.xml)

    private let soundNames = ["Ether Pad", "Distorted Dreams", "Xanpalamin", "Give it a Tri", "Digital Monk"]

    private func buildSoundMenu() -> UIMenu {
        let actions = soundNames.enumerated().map { i, name in
            makeAction(title: name, isSelected: i == selectedSound, isDefault: i == 0) { [weak self] in
                guard let self = self else { return }
                self.selectedSound = i
                self.engine.setSound(i)
                self.soundBtn.title = "Sound: \(name)"
                self.soundBtn.menu = self.buildSoundMenu()
            }
        }
        return UIMenu(title: "Sound", children: actions)
    }

    // MARK: - About

    @objc private func showAbout() {
        let aboutVC = AboutViewController()
        aboutVC.modalPresentationStyle = .pageSheet
        present(aboutVC, animated: true)
    }
}
