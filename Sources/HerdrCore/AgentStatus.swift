import Foundation

public enum AgentStatus: String, CaseIterable, Sendable, Codable {
    case blocked
    case done
    case working
    case unknown
    case idle

    public static let order: [AgentStatus] = [.blocked, .done, .working, .unknown, .idle]

    public var label: String {
        switch self {
        case .blocked: "Blocked"
        case .done: "Done"
        case .working: "Working"
        case .unknown: "Unknown"
        case .idle: "Idle"
        }
    }

    /// Nerd Font PUA glyphs. macOS San Francisco has no glyphs here.
    public var icon: String {
        switch self {
        case .blocked: "󰀦"
        case .done: "󰄬"
        case .working: "󰔟"
        case .unknown: "󰘥"
        case .idle: "󰒲"
        }
    }

    /// SF Symbols used by the macOS dashboard. These ship with the system font.
    public var symbolName: String {
        switch self {
        case .blocked: "exclamationmark.triangle.fill"
        case .done: "checkmark.circle.fill"
        case .working: "ellipsis.circle.fill"
        case .unknown: "questionmark.circle.fill"
        case .idle: "moon.zzz.fill"
        }
    }

    /// Tooltip is drawn with the system UI font, so keep this in BMP unicode.
    public var tooltipMark: String {
        switch self {
        case .blocked: "!"
        case .done: "✓"
        case .working: "…"
        case .unknown: "?"
        case .idle: "–"
        }
    }

    /// Resolved color: user override, else Claude Code tab-status defaults.
    public var hexColor: String {
        StatusPalette.shared.hex(for: self)
    }

    /// Built-in defaults: Claude Code tab-status for blocked / done / idle,
    /// Claude spinner terracotta for working (readable on a light popover).
    public var defaultHexColor: String {
        switch self {
        case .blocked: "#5F87FF" // waiting for you — Claude `waiting`
        case .done:    "#00D75F" // turn finished — Claude `idle` indicator
        case .working: "#CF7650" // Claude CLI spinner / "Bunning…" on light terminals
        case .unknown: "#C7A35A" // muted gold, distinct from orange
        case .idle:    "#888888" // Claude idle `statusColor`
        }
    }

    /// Waiting on you: blocked, a finished turn, or a state we cannot read.
    public var needsAttention: Bool {
        switch self {
        case .blocked, .done, .unknown: true
        case .working, .idle: false
        }
    }

    public var priority: Int {
        Self.order.firstIndex(of: self) ?? Self.order.firstIndex(of: .unknown)!
    }

    public static func normalize(_ raw: String?) -> AgentStatus {
        AgentStatus(rawValue: raw ?? "unknown") ?? .unknown
    }
}
