import Foundation

/// Keyboard navigation for the dashboard popover.
///
/// Up / down walk the visible task list of the current filter and wrap.
/// Left / right move the session chips when more than one herdr session is
/// online; otherwise they hop folder groups.
public enum DashboardNav {
    /// `[nil, "default", "work", …]` when 2+ sessions are online; empty otherwise.
    public static func sessionOptions(_ online: [String]) -> [String?] {
        online.count > 1 ? [nil] + online : []
    }

    public static func stepSession(current: String?, online: [String], by delta: Int) -> String? {
        let options = sessionOptions(online)
        guard !options.isEmpty else { return current }
        let idx = options.firstIndex(where: { $0 == current }) ?? 0
        return options[wrap(idx + delta, count: options.count)]
    }

    public static func visibleIDs(in groups: [AgentGroup], hideIdle: Bool) -> [[String]] {
        groups.map { HerdrLogic.visibleAgents(in: $0, hideIdle: hideIdle).map(\.id) }
            .filter { !$0.isEmpty }
    }

    /// Next / previous visible row in the current filter. Walks every folder
    /// on screen and wraps. No selection: down picks the first row, up the last.
    public static func stepRow(
        groups: [AgentGroup],
        hideIdle: Bool,
        selected: String?,
        by delta: Int
    ) -> String? {
        let ids = visibleIDs(in: groups, hideIdle: hideIdle).flatMap { $0 }
        guard !ids.isEmpty else { return nil }
        if let selected, let idx = ids.firstIndex(of: selected) {
            return ids[wrap(idx + delta, count: ids.count)]
        }
        return delta >= 0 ? ids.first : ids.last
    }

    /// First visible row of the next / previous folder.
    public static func stepGroup(
        groups: [AgentGroup],
        hideIdle: Bool,
        selected: String?,
        by delta: Int
    ) -> String? {
        let buckets = visibleIDs(in: groups, hideIdle: hideIdle)
        guard !buckets.isEmpty else { return nil }
        let idx: Int
        if let selected, let found = buckets.firstIndex(where: { $0.contains(selected) }) {
            idx = found
        } else {
            idx = 0
        }
        return buckets[wrap(idx + delta, count: buckets.count)].first
    }

    public static func clampSelection(
        groups: [AgentGroup],
        hideIdle: Bool,
        selected: String?,
        preferred: String?
    ) -> String? {
        let ids = visibleIDs(in: groups, hideIdle: hideIdle).flatMap { $0 }
        if let selected, ids.contains(selected) { return selected }
        if let preferred, ids.contains(preferred) { return preferred }
        return ids.first
    }

    static func wrap(_ value: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let remainder = value % count
        return remainder >= 0 ? remainder : remainder + count
    }
}
