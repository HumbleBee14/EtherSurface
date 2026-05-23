// EtherSurfaceViewController.swift — main view controller
//
// Faithful port of MainActivity.java: full-screen touch surface with a
// toolbar row of five popup menus (Scale, Key, Octave, Size, Sound, About).
// Every option, every scale array, every Csound score message is identical
// to the Android version.

import UIKit
import AVFoundation

final class EtherSurfaceViewController: UIViewController, TouchSurfaceDelegate {

    // MARK: - Sub-components

    private let engine  = CsoundEngine()
    private let surface = TouchSurfaceView()

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
            print("[EtherSurface] Audio session setup failed: \(error)")
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

        let scaleBtn  = makeMenuButton(title: "Scale",  menu: buildScaleMenu())
        let keyBtn    = makeMenuButton(title: "Key",    menu: buildKeyMenu())
        let octBtn    = makeMenuButton(title: "Octave", menu: buildOctaveMenu())
        let sizeBtn   = makeMenuButton(title: "Size",   menu: buildSizeMenu())
        let soundBtn  = makeMenuButton(title: "Sound",  menu: buildSoundMenu())
        let aboutBtn  = UIBarButtonItem(title: "About", style: .plain, target: self,
                                        action: #selector(showAbout))

        toolbar.items = [scaleBtn, flex, keyBtn, flex, octBtn, flex, sizeBtn, flex, soundBtn, flex, aboutBtn]
    }

    private func makeMenuButton(title: String, menu: UIMenu) -> UIBarButtonItem {
        let btn = UIBarButtonItem(title: title, menu: menu)
        return btn
    }

    // MARK: - Scale menu (12 items — exact match of scales.xml)

    private func buildScaleMenu() -> UIMenu {
        UIMenu(title: "Scale", children: [
            UIAction(title: "Default")     { [weak self] _ in self?.engine.setScale(self!.scaleDefault) },
            UIAction(title: "Major")       { [weak self] _ in self?.engine.setScale(self!.scaleMajor) },
            UIAction(title: "Minor")       { [weak self] _ in self?.engine.setScale(self!.scaleMinor) },
            UIAction(title: "Pentatonic")  { [weak self] _ in self?.engine.setScale(self!.scalePent) },
            UIAction(title: "Flamenco")    { [weak self] _ in self?.engine.setScale(self!.scaleFlam) },
            UIAction(title: "Blues")        { [weak self] _ in self?.engine.setScale(self!.scaleBlues) },
            UIAction(title: "Chromatic")   { [weak self] _ in self?.engine.setScale(self!.scaleChrom) },
            UIAction(title: "Whole-Tone")  { [weak self] _ in self?.engine.setScale(self!.scaleWhole) },
            UIAction(title: "Octatonic")   { [weak self] _ in self?.engine.setScale(self!.scaleOct) },
            UIAction(title: "Bohlen-Pierce") { [weak self] _ in self?.engine.setScale(self!.scaleBP) },
            UIAction(title: "Overtone Series Low")  { [weak self] _ in self?.engine.setScale(self!.scaleOTLow) },
            UIAction(title: "Overtone Series High") { [weak self] _ in self?.engine.setScale(self!.scaleOTHigh) },
        ])
    }

    // MARK: - Key menu (C through B — 12 chromatic roots)

    private func buildKeyMenu() -> UIMenu {
        let keys = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        return UIMenu(title: "Key", children: keys.enumerated().map { i, name in
            UIAction(title: name) { [weak self] _ in self?.engine.setKey(i) }
        })
    }

    // MARK: - Octave menu (2, 1, 0, -1, -2 → Csound values 6, 5, 4, 3, 2)

    private func buildOctaveMenu() -> UIMenu {
        let labels = ["2", "1", "0", "-1", "-2"]
        let values = [6, 5, 4, 3, 2]
        return UIMenu(title: "Octave", children: zip(labels, values).map { label, val in
            UIAction(title: label) { [weak self] _ in self?.engine.setOctave(val) }
        })
    }

    // MARK: - Size menu (4 through 14)

    private func buildSizeMenu() -> UIMenu {
        UIMenu(title: "Size", children: (4...14).map { n in
            UIAction(title: "\(n)") { [weak self] _ in
                self?.engine.setSize(n)
                self?.surface.numberOfNotes = Double(n)
            }
        })
    }

    // MARK: - Sound menu (5 sounds — exact match of sounds.xml)

    private func buildSoundMenu() -> UIMenu {
        let names = ["Ether Pad", "Distorted Dreams", "Xanpalamin", "Give it a Tri", "Digital Monk"]
        return UIMenu(title: "Sound", children: names.enumerated().map { i, name in
            UIAction(title: name) { [weak self] _ in self?.engine.setSound(i) }
        })
    }

    // MARK: - About

    @objc private func showAbout() {
        let aboutVC = AboutViewController()
        aboutVC.modalPresentationStyle = .pageSheet
        present(aboutVC, animated: true)
    }
}
