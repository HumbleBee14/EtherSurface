// SynthPanelViewController.swift — one independent synth panel (engine + surface + toolbar)
//
// A reusable view controller that owns one CsoundEngine, one TouchSurfaceView, and one
// toolbar with five control buttons (Scale, Key, Octave, Size, Sound). Used twice in
// SplitSynthViewController (left and right panels on iPad) or once in SceneDelegate
// (full-screen on iPhone / split mode OFF on iPad).
//
// Each panel maintains its own parameter state independently.

import UIKit
import AVFoundation

final class SynthPanelViewController: UIViewController, TouchSurfaceDelegate {

    // MARK: - Components

    private let engine  = CsoundEngine()
    private let surface = TouchSurfaceView()

    // MARK: - Toolbar buttons

    private var scaleBtn:  UIBarButtonItem!
    private var keyBtn:    UIBarButtonItem!
    private var octBtn:    UIBarButtonItem!
    private var sizeBtn:   UIBarButtonItem!
    private var soundBtn:  UIBarButtonItem!

    // MARK: - State (mirrors CSD defaults)

    private var selectedScale:  String = "Default"
    private var selectedKey:    Int    = 0
    private var selectedOctave: Int    = 4
    private var selectedSize:   Int    = 8
    private var selectedSound:  Int    = 0

    // MARK: - Scales

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
    private let scaleOTLow:   [Int] = [-2]
    private let scaleOTHigh:  [Int] = [-3]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

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

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    deinit {
        NotificationCenter.default.removeObserver(self)
        engine.allNotesOff()
        engine.stop()
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

    // MARK: - Lifecycle notifications

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
    }

    // MARK: - Toolbar

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

        toolbar.items = [scaleBtn, flex, keyBtn, flex, octBtn, flex, sizeBtn, flex, soundBtn]
    }

    private func makeAction(title: String, isSelected: Bool, isDefault: Bool = false,
                            handler: @escaping () -> Void) -> UIAction {
        let displayTitle = isDefault ? "• \(title)" : title
        return UIAction(title: displayTitle, state: isSelected ? .on : .off) { _ in handler() }
    }

    // MARK: - Menu builders

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
}
