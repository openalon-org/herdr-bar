import Foundation

/// Open-at-login is a system login item (`SMAppService`), not a herdr-bar.json key.
/// This type only maps status → UI. MacBar talks to ServiceManagement.
public enum LoginItem {
    public enum Registration: Equatable, Sendable {
        case enabled
        case notRegistered
        case requiresApproval
        case notFound
    }

    /// `Bundle.main.bundlePath` is `HerdrBar.app` when packed; `swift run` is a bare binary.
    public static func isPackedApp(bundlePath: String) -> Bool {
        URL(fileURLWithPath: bundlePath).pathExtension.lowercased() == "app"
    }

    /// Switch on while enabled, and while the user asked but System Settings still
    /// needs to approve — turning it off then unregisters.
    public static func isOn(_ status: Registration) -> Bool {
        status == .enabled || status == .requiresApproval
    }

    public static func footer(packed: Bool, status: Registration, error: String?) -> String {
        if let error, !error.isEmpty { return error }
        if !packed {
            return "Install HerdrBar.app first. A throwaway `swift run` cannot register a login item."
        }
        switch status {
        case .requiresApproval:
            return "Approve HerdrBar in System Settings → General → Login Items."
        case .notFound:
            return "This build is not a packed app, so macOS cannot add a login item."
        case .enabled, .notRegistered:
            return "Launches the extra when you log in. Same list as System Settings → Login Items."
        }
    }
}
