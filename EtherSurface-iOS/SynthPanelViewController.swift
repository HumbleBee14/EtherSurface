import UIKit
import AVFoundation

final class SynthPanelViewController: UIViewController, TouchSurfaceDelegate {

    var showsAboutButton: Bool = true
    var trailingAlignedToolbar: Bool = false

    private let engine  = CsoundEngine()
    private let surface = TouchSurfaceView()

    private var scaleBtn: UIButton!
    private var keyBtn:   UIButton!
    private var octBtn:   UIButton!
    private var sizeBtn:  UIButton!
    private var soundBtn: UIButton!
    private weak var settingsBtn: UIButton?

    private var selectedScale:  String = "Default"
    private var selectedKey:    Int    = 0
    private var selectedOctave: Int    = 4
    private var selectedSize:   Int    = 8
    private var selectedSound:  Int    = 0

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

    override func viewDidLoad() {
        super.viewDidLoad()

        surface.delegate = self
        surface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(surface)
        // Surface extends behind the translucent toolbar so the blur has content to sample.
        NSLayoutConstraint.activate([
            surface.topAnchor.constraint(equalTo: view.topAnchor),
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

    func touchBegan(slot: Int, x: Float, y: Float) {
        engine.noteOn(slot: slot, x: x, y: y)
    }

    func touchMoved(slot: Int, x: Float, y: Float) {
        engine.updatePosition(slot: slot, x: x, y: y)
    }

    func touchEnded(slot: Int) {
        engine.noteOff(slot: slot)
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
    }

    private func configureToolbar() {
        // Clip so toolbar can't overflow this panel's bounds in split mode.
        view.clipsToBounds = true

        // Resolve UIGlassEffect dynamically so this builds against older SDKs.
        let effect: UIVisualEffect = {
            if let cls = NSClassFromString("UIGlassEffect") as? NSObject.Type,
               let obj = cls.init() as? UIVisualEffect {
                return obj
            }
            return UIBlurEffect(style: .systemThinMaterial)
        }()
        let bar = UIVisualEffectView(effect: effect)
        bar.clipsToBounds = true
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 44),
        ])

        scaleBtn = makeBarButton(title: "Scale",  menu: buildScaleMenu())
        keyBtn   = makeBarButton(title: "Key",    menu: buildKeyMenu())
        octBtn   = makeBarButton(title: "Octave", menu: buildOctaveMenu())
        sizeBtn  = makeBarButton(title: "Size",   menu: buildSizeMenu())
        soundBtn = makeBarButton(title: "Sound",  menu: buildSoundMenu())

        var buttons: [UIButton] = [scaleBtn, keyBtn, octBtn, sizeBtn, soundBtn]
        if showsAboutButton {
            let gear = UIButton(type: .system)
            let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            gear.setImage(UIImage(systemName: "gearshape", withConfiguration: cfg), for: .normal)
            gear.tintColor = .white
            gear.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
            settingsBtn = gear
            buttons.append(gear)
        }

        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bar.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bar.contentView.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: bar.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bar.contentView.trailingAnchor),
        ])
    }

    private func makeBarButton(title: String, menu: UIMenu) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 14)
        b.titleLabel?.adjustsFontSizeToFitWidth = true
        b.titleLabel?.minimumScaleFactor = 0.6
        b.titleLabel?.lineBreakMode = .byClipping
        b.menu = menu
        b.showsMenuAsPrimaryAction = true
        return b
    }

    private func makeAction(title: String, isSelected: Bool, isDefault: Bool = false,
                            handler: @escaping () -> Void) -> UIAction {
        let displayTitle = isDefault ? "• \(title)" : title
        return UIAction(title: displayTitle, state: isSelected ? .on : .off) { _ in handler() }
    }

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
                self.soundBtn.menu = self.buildSoundMenu()
            }
        }
        return UIMenu(title: "Sound", children: actions)
    }

    @objc private func showSettings() {
        let settings = AboutViewController()
        settings.modalPresentationStyle = .popover
        settings.preferredContentSize = CGSize(width: 520, height: 560)
        if let pop = settings.popoverPresentationController {
            pop.sourceView = settingsBtn
            pop.sourceRect = settingsBtn?.bounds ?? .zero
            pop.permittedArrowDirections = .up
            pop.delegate = self
        }
        present(settings, animated: true)
    }
}

extension SynthPanelViewController: UIPopoverPresentationControllerDelegate {
    // Keep popover style even on compact-width iPhones (prevents full-screen sheet).
    func adaptivePresentationStyle(
        for controller: UIPresentationController,
        traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        .none
    }
}
