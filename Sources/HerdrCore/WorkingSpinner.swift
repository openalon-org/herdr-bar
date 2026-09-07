import Foundation

/// Claude Code 2.1.263 working mark (`src` spinner `st` / `_le()`).
///
/// Darwin frames: `· ✢ ✳ ✶ ✻ ✽`, then the same array reversed (hold the
/// extremes for two ticks). Index is `floor(ms / 120) % 12` — 1.44s loop.
public enum WorkingSpinner {
    public static let characters = ["·", "✢", "✳", "✶", "✻", "✽"]
    /// Parked frame for idle / done / blocked / unknown — Claude's rest mark.
    public static let restGlyph = "✻"
    public static let frameDuration: TimeInterval = 0.12

    public static let frames: [String] = characters + characters.reversed()

    public static func frame(at date: Date = Date()) -> String {
        frames[frameIndex(at: date)]
    }

    public static func frameIndex(at date: Date) -> Int {
        // Claude: `Math.floor(timeMs / 120) % frames.length`
        let steps = Int((date.timeIntervalSinceReferenceDate * 1000) / 120)
        let count = frames.count
        guard count > 0 else { return 0 }
        return ((steps % count) + count) % count
    }
}
