import Foundation

enum SharedConstants {
    /// Must match the App Group configured in both targets' entitlements
    /// (Signing & Capabilities → App Groups) and in project.yml.
    static let appGroupID = "group.com.roblinger.apidashboard"
}

/// Caches the last successful snapshot in the shared App Group container so the
/// widget can render instantly on relaunch/reload before its own fetch completes,
/// and so the settings app can show "last synced" without an extra network call.
enum SharedCache {
    private static let key = "lastSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedConstants.appGroupID)
    }

    static func save(_ snapshot: DashboardSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> DashboardSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(DashboardSnapshot.self, from: data)
    }
}
