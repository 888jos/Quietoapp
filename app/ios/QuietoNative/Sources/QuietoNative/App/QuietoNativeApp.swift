import SwiftUI
import CoreText
import UIKit

enum QuietoFontRegistrar {
    static func registerBundledFonts() {
        ["Faro-Regular", "Faro-SemiBold", "Faro-Bold", "HankenGrotesk"].forEach { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { return }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// UIKit chrome (tab bar, navigation bars) in the app's two typefaces.
enum QuietoAppearance {
    static func apply() {
        let tab = hanken(10, weight: .semibold)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tab], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: tab], for: .selected)
        let nav = UINavigationBar.appearance()
        if let title = UIFont(name: "Faro-SemiBoldLucky", size: 17) {
            nav.titleTextAttributes = [.font: title, .foregroundColor: UIColor.white]
        }
        if let large = UIFont(name: "Faro-SemiBoldLucky", size: 30) {
            nav.largeTitleTextAttributes = [.font: large, .foregroundColor: UIColor.white]
        }
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: hanken(16, weight: .semibold)], for: .normal)
    }

    /// Hanken Grotesk is a variable font: the weight goes through its descriptor.
    static func hanken(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFontDescriptor(fontAttributes: [.family: "Hanken Grotesk"])
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        let font = UIFont(descriptor: descriptor, size: size)
        return font.familyName == "Hanken Grotesk" ? font : .systemFont(ofSize: size, weight: weight)
    }
}

@MainActor
final class QuietoApplicationDelegate: NSObject, UIApplicationDelegate {
    let container: AppContainer

    override init() {
        // Before anything reads a string: every lookup then follows the chosen language.
        QuietoLocalization.install()
        container = AppContainer()
        super.init()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        QuietoFontRegistrar.registerBundledFonts()
        QuietoAppearance.apply()
        container.sessionCoordinator.start()
        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == QuietoDownloadStore.sessionIdentifier else { completionHandler(); return }
        container.downloads.backgroundEventsCompletion = completionHandler
    }
}

@main
struct QuietoNativeApp: App {
    @UIApplicationDelegateAdaptor(QuietoApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView(container: appDelegate.container)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(QuietoBackground())
        }
    }
}
