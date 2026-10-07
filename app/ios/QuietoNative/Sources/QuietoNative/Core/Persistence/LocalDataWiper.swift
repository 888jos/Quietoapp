import Foundation
import UserNotifications

/// Everything Quieto keeps on this iPhone for the signed-in person. Used on
/// sign-out and after account deletion (RGPD art. 17). The generic on-device
/// narrations of the catalogue are not personal and stay cached.
struct LocalDataWiper {
    let preferences: QuietoPreferences
    let downloads: QuietoDownloadManaging
    let louaneMemory: LouaneMemoryProviding
    /// Lets in-memory state (practice journal, badges) follow the wiped storage.
    var onWiped: (@MainActor () -> Void)?

    @MainActor
    func wipe() {
        preferences.removeAll()
        downloads.deleteAll()
        louaneMemory.remove()
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: LouaneMemoryStore.fileURL.deletingLastPathComponent())
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let exports = (try? fileManager.contentsOfDirectory(at: caches, includingPropertiesForKeys: nil)) ?? []
        exports.filter { $0.lastPathComponent.hasPrefix("Quieto-export-") }.forEach { try? fileManager.removeItem(at: $0) }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        URLCache.shared.removeAllCachedResponses()
        onWiped?()
    }
}
