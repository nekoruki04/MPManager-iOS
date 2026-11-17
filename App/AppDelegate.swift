import UIKit
import Darwin

@main
@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        _ = setuid(0)
        _ = setgid(0)
        _ = seteuid(0)
        _ = setegid(0)

        let win = UIWindow(frame: UIScreen.main.bounds)
        win.backgroundColor = MPTheme.background_dark
        let root_vc = DualPaneViewController()
        win.rootViewController = root_vc
        win.makeKeyAndVisible()
        self.window = win
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
