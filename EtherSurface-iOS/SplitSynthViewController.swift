// SplitSynthViewController.swift — iPad split-screen dual-synth container
//
// On iPad: manages two SynthPanelViewController instances (left/right) with shared About sheet.
// Configures AVAudioSession once. Listens to SplitModeController changes and transitions
// between split layout and single-synth full-screen.
//
// On iPhone: this VC should not be instantiated (SceneDelegate routes to EtherpadViewController instead).

import UIKit
import AVFoundation

final class SplitSynthViewController: UIViewController {

    // MARK: - Child view controllers

    private var leftPanel:  SynthPanelViewController?
    private var rightPanel: SynthPanelViewController?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        configureAudioSession()

        // Only iPad should use this controller, but add safety check
        if UIDevice.current.userInterfaceIdiom != .pad {
            fatalError("SplitSynthViewController is iPad-only")
        }

        // On first launch, split mode is OFF — show single synth
        // When user toggles split mode ON in About, we rebuild the layout
        rebuildLayout()

        NotificationCenter.default.addObserver(
            self, selector: #selector(splitModeDidChange),
            name: SplitModeController.didChangeNotification, object: nil)
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Audio session

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)
        } catch {
            print("[Etherpad] Audio session setup failed: \(error)")
        }
    }

    // MARK: - Layout rebuild

    @objc private func splitModeDidChange() {
        rebuildLayout()
    }

    private func rebuildLayout() {
        // Remove old child VCs
        leftPanel?.removeFromParent()
        rightPanel?.removeFromParent()
        leftPanel?.view.removeFromSuperview()
        rightPanel?.view.removeFromSuperview()

        view.subviews.forEach { $0.removeFromSuperview() }

        if SplitModeController.isEnabled {
            layoutSplitMode()
        } else {
            layoutSingleMode()
        }
    }

    // Split mode: two panels side-by-side
    private func layoutSplitMode() {
        let left = SynthPanelViewController()
        let right = SynthPanelViewController()

        leftPanel = left
        rightPanel = right

        addChild(left)
        addChild(right)

        left.view.translatesAutoresizingMaskIntoConstraints = false
        right.view.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(left.view)
        view.addSubview(right.view)

        NSLayoutConstraint.activate([
            // Left panel: left 50% of screen
            left.view.topAnchor.constraint(equalTo: view.topAnchor),
            left.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            left.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            left.view.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),

            // Right panel: right 50% of screen
            right.view.topAnchor.constraint(equalTo: view.topAnchor),
            right.view.leadingAnchor.constraint(equalTo: left.view.trailingAnchor),
            right.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            right.view.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5),
        ])

        left.didMove(toParent: self)
        right.didMove(toParent: self)

        // Add a divider line between them
        let divider = UIView()
        divider.backgroundColor = UIColor(red: 0x50/255, green: 0x72/255, blue: 0xA7/255, alpha: 0.5)
        divider.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(divider)
        NSLayoutConstraint.activate([
            divider.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            divider.topAnchor.constraint(equalTo: view.topAnchor),
            divider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 2),
        ])

        print("[Etherpad] Split mode: 2 synths side-by-side")
    }

    // Single mode: one panel full-screen
    private func layoutSingleMode() {
        let panel = SynthPanelViewController()
        leftPanel = panel
        rightPanel = nil

        addChild(panel)
        panel.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel.view)

        NSLayoutConstraint.activate([
            panel.view.topAnchor.constraint(equalTo: view.topAnchor),
            panel.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        panel.didMove(toParent: self)

        print("[Etherpad] Single mode: 1 synth full-screen")
    }
}
