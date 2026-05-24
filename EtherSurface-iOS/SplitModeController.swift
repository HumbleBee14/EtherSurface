import UIKit

final class SplitModeController {
    private static let key = "EtherpadSplitModeEnabled"
    static let didChangeNotification = NSNotification.Name("EtherpadSplitModeDidChange")

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }
}
