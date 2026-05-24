// SceneDelegate.swift — UIScene lifecycle for the single-scene app.
//
// Replaces the legacy AppDelegate.window pattern. The scene system is
// what enables Stage Manager, Split View, and multi-window on iPad —
// even though Etherpad only ever uses one window, adopting it is
// what silences the "UIScene lifecycle will soon be required" warning
// and future-proofs against the Apple deprecation.

import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)

        let rootVC: UIViewController
        if UIDevice.current.userInterfaceIdiom == .pad {
            rootVC = SplitSynthViewController()
        } else {
            rootVC = EtherpadViewController()
        }

        window.rootViewController = rootVC
        window.makeKeyAndVisible()
        self.window = window
    }
}
