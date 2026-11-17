import UIKit

@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let win = UIWindow(windowScene: windowScene)
        win.backgroundColor = MPTheme.background_dark
        let root_vc = DualPaneViewController()
        win.rootViewController = root_vc
        self.window = win
        win.makeKeyAndVisible()
    }
}
