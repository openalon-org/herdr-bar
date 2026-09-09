import Darwin
import Foundation

/// Desktop widget payload. The extra writes this file; WidgetKit only reads it.
/// Never open a Herdr socket from the widget process.
public struct WidgetSnapshot: Equatable, Sendable, Codable {
    public var writtenAt: Date
    public var anyOnline: Bool
    public var hideIdle: Bool
    public var sessionNames: [String]
    public var counts: [String: Int]
    public var groups: [Group]

    public init(
        writtenAt: Date,
        anyOnline: Bool,
        hideIdle: Bool,
        sessionNames: [String],
        counts: [String: Int],
        groups: [Group]
    ) {
        self.writtenAt = writtenAt
        self.anyOnline = anyOnline
        self.hideIdle = hideIdle
        self.sessionNames = sessionNames
        self.counts = counts
        self.groups = groups
    }

    public struct Group: Equatable, Sendable, Codable, Identifiable {
        public var folder: String
        public var hiddenIdle: Int
        public var rows: [Row]

        public var id: String { folder }

        public init(folder: String, hiddenIdle: Int, rows: [Row]) {
            self.folder = folder
            self.hiddenIdle = hiddenIdle
            self.rows = rows
        }
    }

    public struct Row: Equatable, Sendable, Codable, Identifiable {
        public var session: String
        public var paneId: String
        public var title: String
        public var subtitle: String
        public var status: AgentStatus
        public var modelName: String?

        public var id: String { "\(session)::\(paneId)" }

        public init(
            session: String,
            paneId: String,
            title: String,
            subtitle: String,
            status: AgentStatus,
            modelName: String? = nil
        ) {
            self.session = session
            self.paneId = paneId
            self.title = title
            self.subtitle = subtitle
            self.status = status
            self.modelName = modelName
        }
    }

    /// All-scope dashboard list under the current eye. Widget has no session chips.
    public static func make(
        agents: [Agent],
        anyOnline: Bool,
        hideIdle: Bool,
        sessionNames: [String],
        home: String,
        now: Date = Date()
    ) -> WidgetSnapshot {
        let counts = HerdrLogic.counts(of: agents)
        var encoded: [String: Int] = [:]
        for status in AgentStatus.order {
            encoded[status.rawValue] = counts[status] ?? 0
        }
        let showSession = sessionNames.count > 1
        var groups: [Group] = []
        for group in HerdrLogic.grouped(agents) {
            let rows = HerdrLogic.visibleAgents(in: group, hideIdle: hideIdle)
            if rows.isEmpty { continue }
            groups.append(Group(
                folder: HerdrLogic.groupHeader(for: group),
                hiddenIdle: HerdrLogic.hiddenIdleCount(in: group, hideIdle: hideIdle),
                rows: rows.map { agent in
                    Row(
                        session: agent.sessionName,
                        paneId: agent.paneId,
                        title: HerdrLogic.agentLabel(agent, maxLength: 40),
                        subtitle: HerdrLogic.subtitle(
                            for: agent,
                            among: agents,
                            home: home,
                            showSession: showSession,
                            showFolder: false
                        ),
                        status: agent.status,
                        modelName: agent.modelName
                    )
                }
            ))
        }
        return WidgetSnapshot(
            writtenAt: now,
            anyOnline: anyOnline,
            hideIdle: hideIdle,
            sessionNames: sessionNames,
            counts: encoded,
            groups: groups
        )
    }

    public static let widgetBundleID = "dev.herdr.herdr-bar.widget"

    /// Extra’s file under POSIX `~/.config/herdr/`. Inspectable; not what the
    /// sandboxed widget can read.
    public static var path: String {
        snapshot(under: realHome)
    }

    /// WidgetKit’s container. Extra (unsandboxed) copies the snapshot here so
    /// the widget can `Data(contentsOf:)` without a home-relative exception —
    /// those often fail in chronod even when `getpwuid` returns the real home.
    public static var widgetContainerPath: String {
        snapshot(under: realHome
            .appendingPathComponent("Library/Containers/\(widgetBundleID)/Data", isDirectory: true))
    }

    /// `homeDirectoryForCurrentUser`: container in the widget, POSIX in the extra.
    public static var processHomePath: String {
        snapshot(under: FileManager.default.homeDirectoryForCurrentUser)
    }

    /// POSIX home, not the App Sandbox container.
    public static var realHome: URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private static func snapshot(under home: URL) -> String {
        home.appendingPathComponent(".config/herdr/widget-snapshot.json").path
    }

    public static let widgetKind = "dev.herdr.herdr-bar.dashboard"
    public static let urlScheme = "herdr-bar"

    public static func load(from path: String? = nil) -> WidgetSnapshot? {
        let candidates: [String]
        if let path {
            candidates = [path]
        } else {
            var seen = Set<String>()
            candidates = [processHomePath, widgetContainerPath, Self.path]
                .filter { seen.insert($0).inserted }
        }
        for candidate in candidates {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: candidate)),
                  let snap = try? decoder.decode(WidgetSnapshot.self, from: data)
            else { continue }
            return snap
        }
        return nil
    }

    public func write(to path: String = path) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Self.encoder.encode(self).write(to: url, options: .atomic)
    }

    public static func focusURL(session: String, pane: String) -> URL {
        var parts = URLComponents()
        parts.scheme = urlScheme
        parts.host = "focus"
        parts.queryItems = [
            URLQueryItem(name: "session", value: session),
            URLQueryItem(name: "pane", value: pane),
        ]
        return parts.url!
    }

    public static func openURL() -> URL {
        var parts = URLComponents()
        parts.scheme = urlScheme
        parts.host = "open"
        return parts.url!
    }

    public struct DeepLink: Equatable, Sendable {
        public var session: String?
        public var paneId: String?

        public var focusesRow: Bool { session != nil && paneId != nil }
    }

    public static func parseURL(_ url: URL) -> DeepLink? {
        guard url.scheme == urlScheme else { return nil }
        let host = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if host == "open" { return DeepLink(session: nil, paneId: nil) }
        guard host == "focus" else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let session = items.first(where: { $0.name == "session" })?.value
        let pane = items.first(where: { $0.name == "pane" })?.value
        guard let session, let pane, !session.isEmpty, !pane.isEmpty else {
            return DeepLink(session: nil, paneId: nil)
        }
        return DeepLink(session: session, paneId: pane)
    }

    public func row(session: String, paneId: String) -> Row? {
        groups.lazy.flatMap(\.rows).first { $0.session == session && $0.paneId == paneId }
    }

    public var rows: [Row] { groups.flatMap(\.rows) }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
