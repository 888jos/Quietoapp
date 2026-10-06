import SwiftUI
import CoreText
import UIKit

enum QuietoFontRegistrar {
    static func registerBundledFonts() {
        ["CormorantGaramond", "HankenGrotesk"].forEach { name in
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { return }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

final class QuietoApplicationDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        QuietoFontRegistrar.registerBundledFonts()
        UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 10, weight: .medium)], for: .normal)
        UITabBarItem.appearance().setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 10, weight: .semibold)], for: .selected)
        Task { @MainActor in QuietoSuperwallService.shared.configure() }
        Task { @MainActor in await QuietoSupabaseService.shared.bootstrap() }
        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == QuietoDownloadStore.sessionIdentifier else { completionHandler(); return }
        QuietoDownloadStore.shared.backgroundEventsCompletion = completionHandler
    }
}

@main
struct QuietoNativeApp: App {
    @UIApplicationDelegateAdaptor(QuietoApplicationDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(QuietoColor.background.ignoresSafeArea())
        }
    }
}
