// SplitModeController.swift — manages split-screen dual-synth mode on iPad
//
// Persists split mode on/off state to UserDefaults and posts notifications
// when the state changes. Used by SceneDelegate (route decision) and
// AboutViewController (toggle UI).

import UIKit

final class SplitModeController {
    private static let key = "EtherpadSplitModeEnabled"
    static let didChangeNotification = NSNotification.Name("EtherpadSplitModeDidChange")

    // Default: split mode OFF (single synth) on first launch
    static var isEnabled: Bool {
        get {
            // Only meaningful on iPad; always false on iPhone
            guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
            // Check if key exists. If not (first launch), default to false.
            if UserDefaults.standard.object(forKey: key) == nil {
                return false
            }
            return UserDefaults.standard.bool(forKey: key)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }
}
