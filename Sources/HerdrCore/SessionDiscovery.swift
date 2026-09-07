import Foundation

public struct DiscoveredSession: Hashable, Sendable {
    public var name: String
    public var socketPath: String
}

public enum SessionDiscovery {
    public static var herdrHome: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/herdr")
            .path
    }

    /// `HERDR_SOCKET` pins a single demo/dev socket named "demo".
    public static func discover(
        home: String = FileManager.default.homeDirectoryForCurrentUser.path,
        extraSockets: [String] = ProcessInfo.processInfo.environment["HERDR_SOCKET"].map { [$0] } ?? []
    ) -> [DiscoveredSession] {
        if let pinned = extraSockets.first, !pinned.isEmpty {
            let path = (pinned as NSString).expandingTildeInPath
            return [DiscoveredSession(name: "demo", socketPath: path)]
        }

        var sessions: [DiscoveredSession] = []
        let defaultPath = HerdrLogic.socketPath(home: home, session: "default", explicitPath: "")
        if FileManager.default.fileExists(atPath: defaultPath) {
            sessions.append(DiscoveredSession(name: "default", socketPath: defaultPath))
        }

        let sessionsDir = home + "/.config/herdr/sessions"
        if let names = try? FileManager.default.contentsOfDirectory(atPath: sessionsDir) {
            for name in names.sorted() {
                let path = HerdrLogic.socketPath(home: home, session: name, explicitPath: "")
                if FileManager.default.fileExists(atPath: path) {
                    sessions.append(DiscoveredSession(name: name, socketPath: path))
                }
            }
        }
        return sessions
    }
}
