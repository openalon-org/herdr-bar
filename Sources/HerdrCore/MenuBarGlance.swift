import Foundation

/// Layout math for the menu-bar extra. The extra is a glance, not inventory:
/// idle never appears, done/working are the online skeleton, blocked/unknown
/// join only when they need you. Width hugs that cluster.
///
/// Drawing stays in MacBar. This type exists so the product line can be tested
/// without spinning up `NSStatusItem`.
public enum MenuBarGlance {
    /// Fixed slot so cycling `·` / `✽` does not shove the count sideways.
    public static let workingMarkWidth: CGFloat = 12
    public static let dotSize: CGFloat = 6
    /// Optical gap from a mark (dot or flower) to its digits. Same for every chip.
    public static let markGap: CGFloat = 4
    /// Extra leading room so an attention halo does not steal the previous
    /// chip's gap. Geometric chipGap then reads even.
    public static let haloLeading: CGFloat = 3
    /// Gap between chips, measured to the next mark's visual edge.
    public static let chipGap: CGFloat = 6
    /// Air inside the extra. Keep this small so the gap to the next menu extra
    /// matches WeChat / Stats; the halo overflows into this, not a second pad.
    public static let inset: CGFloat = 4
    /// Empty extra: just the offline / no-agent dot.
    public static let emptyWidth: CGFloat = 22
    /// Monospaced digit width at 11pt bold (matches MacBar `draw`).
    public static let digitWidth: CGFloat = 8

    /// Menu bar is a glance, not inventory. Idle lives behind the dashboard eye.
    /// Done and working stay on the extra while Herdr is online so the housing
    /// does not jump; blocked / unknown join only when they need you.
    public static func glanceableStatuses(
        _ counts: [AgentStatus: Int],
        online: Bool
    ) -> [AgentStatus] {
        guard online else { return [] }
        return AgentStatus.order.filter { status in
            switch status {
            case .idle: false
            case .done, .working: true
            case .blocked, .unknown: (counts[status] ?? 0) > 0
            }
        }
    }

    public static func preferredWidth(counts: [AgentStatus: Int], online: Bool) -> CGFloat {
        if glanceableStatuses(counts, online: online).isEmpty {
            return emptyWidth
        }
        return max(housingWidth(counts, online: online), emptyWidth)
    }

    public static func housingWidth(_ counts: [AgentStatus: Int], online: Bool = true) -> CGFloat {
        clusterWidth(counts, online: online) + inset * 2
    }

    public static func clusterWidth(_ counts: [AgentStatus: Int], online: Bool = true) -> CGFloat {
        let visible = glanceableStatuses(counts, online: online)
        guard !visible.isEmpty else { return 0 }
        let chips = visible.reduce(CGFloat(0)) { $0 + chipInnerWidth(status: $1, count: counts[$1] ?? 0) }
        return chips + chipGap * CGFloat(visible.count - 1)
    }

    public static func chipInnerWidth(status: AgentStatus, count: Int) -> CGFloat {
        let digits = max(1, String(count).count)
        let mark: CGFloat = status == .working ? workingMarkWidth : dotSize
        let leading: CGFloat = status.needsAttention ? haloLeading : 0
        return leading + mark + markGap + CGFloat(digits) * digitWidth
    }
}
