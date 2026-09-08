import Foundation

/// Optional session scope. Folders are list sections, not a second filter.
public struct AgentFilter: Equatable, Sendable {
    public var session: String?

    public init(session: String? = nil) {
        self.session = session
    }

    public var isActive: Bool { session != nil }

    public func matches(_ agent: Agent) -> Bool {
        if let session, agent.sessionName != session { return false }
        return true
    }
}

public struct AgentGroup: Equatable, Identifiable, Sendable {
    public let folder: String
    public let agents: [Agent]

    public var id: String { folder }

    public init(folder: String, agents: [Agent]) {
        self.folder = folder
        self.agents = agents
    }
}

public enum HerdrLogic {
    public static func filtered(_ agents: [Agent], by filter: AgentFilter) -> [Agent] {
        guard filter.isActive else { return agents }
        return agents.filter { filter.matches($0) }
    }

    /// Folder buckets. Session is a filter, not a sort key.
    /// Active groups (any non-idle) sort by herdr status, then folder name.
    /// Idle-only groups sort by the newest conversation time in that space.
    public static func grouped(_ agents: [Agent]) -> [AgentGroup] {
        var buckets: [String: [Agent]] = [:]
        for agent in agents {
            buckets[folderName(agent.foregroundCwd ?? agent.cwd), default: []].append(agent)
        }
        return buckets.keys.sorted { lhs, rhs in
            groupRank(buckets[lhs] ?? [], folder: lhs) < groupRank(buckets[rhs] ?? [], folder: rhs)
        }.map { key in
            AgentGroup(folder: key, agents: sortedAgents(buckets[key] ?? []))
        }
    }

    public static func groupHeader(for group: AgentGroup) -> String {
        group.folder.isEmpty ? "—" : group.folder
    }

    /// Notification mode: hide idle rows when the space still has something to
    /// look at. Idle-only spaces stay listed as a compact header.
    public static func visibleAgents(in group: AgentGroup, hideIdle: Bool) -> [Agent] {
        guard hideIdle else { return group.agents }
        let active = group.agents.filter { $0.status != .idle }
        return active.isEmpty ? [] : active
    }

    public static func hiddenIdleCount(in group: AgentGroup, hideIdle: Bool) -> Int {
        guard hideIdle else { return 0 }
        let idle = group.agents.filter { $0.status == .idle }.count
        let hasActive = group.agents.contains { $0.status != .idle }
        return hasActive ? idle : 0
    }

    /// Active: status priority, then folder name.
    /// Idle-only: newest `lastSessionAt` in the space first; missing times last.
    private static func groupRank(_ agents: [Agent], folder: String) -> (Int, TimeInterval, String) {
        let head = attentionAgent(in: agents)
        let status = head?.status ?? .idle
        guard status == .idle else {
            return (status.priority, 0, folder.lowercased())
        }
        let newest = agents.compactMap(\.lastSessionAt).map(\.timeIntervalSince1970).max()
        let recency = newest.map { -$0 } ?? TimeInterval.infinity
        return (status.priority, recency, folder.lowercased())
    }

    public static func counts(of agents: [Agent]) -> [AgentStatus: Int] {
        var result: [AgentStatus: Int] = [
            .blocked: 0, .done: 0, .working: 0, .unknown: 0, .idle: 0,
        ]
        for agent in agents {
            result[agent.status, default: 0] += 1
        }
        return result
    }

    public static func sortedAgents(_ agents: [Agent]) -> [Agent] {
        agents.sorted { a, b in
            let statusDelta = a.status.priority - b.status.priority
            if statusDelta != 0 { return statusDelta < 0 }
            switch recencyOrder(a.lastSessionAt, b.lastSessionAt) {
            case .orderedAscending: return true
            case .orderedDescending: return false
            case .orderedSame: break
            }
            let paneDelta = paneNumber(a.paneId) - paneNumber(b.paneId)
            if paneDelta != 0 { return paneDelta < 0 }
            return agentLabel(a).localizedCaseInsensitiveCompare(agentLabel(b)) == .orderedAscending
        }
    }

    /// Newest conversation first. Missing times sort last so a just-finished
    /// turn stays above an older idle pane in the same folder.
    private static func recencyOrder(_ lhs: Date?, _ rhs: Date?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (l?, r?):
            if l > r { return .orderedAscending }
            if l < r { return .orderedDescending }
            return .orderedSame
        case (_?, nil): return .orderedAscending
        case (nil, _?): return .orderedDescending
        case (nil, nil): return .orderedSame
        }
    }

    /// Numeric pane index from `w2:p7` / `p7`. Unknown tokens sort last.
    public static func paneNumber(_ paneId: String) -> Int {
        let token = shortPane(paneId)
        let digits = token.drop { $0 != "p" && !$0.isNumber }.drop { $0 == "p" }
        return Int(digits) ?? Int.max
    }

    public static func attentionAgent(in agents: [Agent]) -> Agent? {
        agents.max { a, b in
            let statusDelta = a.status.priority - b.status.priority
            if statusDelta != 0 { return statusDelta > 0 }
            return a.stateChangeSeq < b.stateChangeSeq
        }
    }

    public static func target(for agent: Agent) -> String {
        if let name = agent.name, !name.isEmpty { return name }
        return agent.paneId
    }

    public static func agentLabel(_ agent: Agent, maxLength: Int = 32) -> String {
        let text = agent.name
            ?? agent.displayAgent
            ?? agent.terminalTitle
            ?? agent.agentKind
            ?? agent.paneId
        if text.isEmpty { return "agent" }
        if text.count <= maxLength { return text }
        return String(text.prefix(maxLength - 1)) + "…"
    }

    /// Short herdr pane token: `w2:p7` → `p7`. Matches the number in the herdr sidebar.
    public static func shortPane(_ paneId: String) -> String {
        if let colon = paneId.lastIndex(of: ":") {
            let tail = String(paneId[paneId.index(after: colon)...])
            return tail.isEmpty ? paneId : tail
        }
        return paneId
    }

    /// Last path component: `/Users/me/workspace/alpha` → `alpha`.
    public static func folderName(_ rawPath: String?) -> String {
        guard let rawPath, !rawPath.isEmpty else { return "" }
        var path = rawPath
        while path.count > 1, path.hasSuffix("/") { path.removeLast() }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    /// `work · repo · feature/login`. Titles already identify the pane.
    public static func subtitle(
        for agent: Agent,
        among agents: [Agent],
        home: String,
        showSession: Bool,
        showFolder: Bool = true
    ) -> String {
        _ = home
        _ = agents
        var parts: [String] = []
        if showSession { parts.append(agent.sessionName) }
        if showFolder {
            let folder = folderName(agent.foregroundCwd ?? agent.cwd)
            if !folder.isEmpty { parts.append(folder) }
        }
        if let branch = agent.gitBranch, !branch.isEmpty {
            parts.append(shortenBranch(branch))
        }
        if let model = agent.modelName, !model.isEmpty {
            parts.append(model)
        }
        return parts.joined(separator: " · ")
    }

    public static func shortenBranch(_ name: String, maxLength: Int = 28) -> String {
        if name.count <= maxLength { return name }
        return String(name.prefix(maxLength - 1)) + "…"
    }

    public static func shortenPath(_ rawPath: String?, home: String, maxLength: Int = 48) -> String {
        guard var path = rawPath, !path.isEmpty else { return "" }
        if !home.isEmpty, path.hasPrefix(home) {
            path = "~" + path.dropFirst(home.count)
        }
        if path.count <= maxLength { return path }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        return "…/" + parts.suffix(2).joined(separator: "/")
    }

    public static func paneKey(of agents: [Agent]) -> String {
        agents.map(\.paneId).filter { !$0.isEmpty }.sorted().joined(separator: "\n")
    }

    public static func socketPath(home: String, session: String, explicitPath: String) -> String {
        let explicit = explicitPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty {
            if explicit.hasPrefix("~/") {
                return home + String(explicit.dropFirst(1))
            }
            return explicit
        }
        let name = session.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "default" {
            return home + "/.config/herdr/herdr.sock"
        }
        return home + "/.config/herdr/sessions/" + name + "/herdr.sock"
    }

    public static func subscriptions(for agents: [Agent]) -> [[String: String]] {
        var list: [[String: String]] = [
            ["type": "pane.agent_detected"],
            ["type": "pane.closed"],
            ["type": "pane.exited"],
            ["type": "pane.moved"],
        ]
        for agent in agents where !agent.paneId.isEmpty {
            list.append(["type": "pane.agent_status_changed", "pane_id": agent.paneId])
        }
        return list
    }

    public static func tooltip(agents: [Agent], online: Bool, home: String) -> String {
        if !online { return "Herdr is offline · waiting to reconnect" }
        let rows = sortedAgents(agents)
        if rows.isEmpty { return "Herdr · no active agents" }
        var lines: [String] = [
            "Herdr · \(rows.count) agent\(rows.count == 1 ? "" : "s")",
            "",
        ]
        for row in rows {
            let status = row.status
            let detail = subtitle(for: row, among: rows, home: home, showSession: false)
            lines.append("\(status.tooltipMark)  \(status.label)  \(agentLabel(row))")
            if !detail.isEmpty { lines.append("    \(detail)") }
        }
        lines.append("")
        lines.append("Left-click: open dashboard · Option-click: focus priority · Right-click: refresh")
        return lines.joined(separator: "\n")
    }
}
