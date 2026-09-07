import Foundation

/// Transcript extras for an agent pane.
///
/// `agent.list` has no wall-clock and no model. The honest source is the
/// Claude jsonl for `agent_session.value`, same files the CLI statusline
/// reads — HerdrBar just does not get that stdin JSON.
///
/// - `lastSessionAt`: file mtime (idle-space recency)
/// - `modelName`: latest assistant `message.model`
/// - `turnStartedAt`: latest **human** user-turn timestamp (`tool_result` ignored)
/// - `turnEndedAt`: that prompt's assistant `end_turn`; nil while the turn is open
/// - `lastActivityAt`: latest user (incl. tool_result) or assistant timestamp.
///   Working ticks from here so a long tool loop does not look like 45h.
public final class SessionTimeCache: @unchecked Sendable {
    public static let shared = SessionTimeCache()

    private let lock = NSLock()
    private var uuidToPath: [String: String?] = [:]
    private var pathToStamp: [String: Stamp] = [:]
    private let fileManager: FileManager
    private let projectsRoot: String

    struct Stamp {
        var mtime: Date?
        var lastSessionAt: Date?
        var modelName: String?
        var turnStartedAt: Date?
        var turnEndedAt: Date?
        var lastActivityAt: Date?
    }

    public init(
        projectsRoot: String? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.projectsRoot = projectsRoot
            ?? (fileManager.homeDirectoryForCurrentUser.path + "/.claude/projects")
    }

    /// First instant we saw this pane Working. Used when jsonl still has the
    /// previous prompt's `end_turn`. Keyed by Agent.id.
    private var workingFallback: [String: Date] = [:]

    public func enrich(_ agents: [Agent]) -> [Agent] {
        agents.map { agent in
            var copy = agent
            let details = details(
                id: copy.agentSessionId,
                cwd: copy.foregroundCwd ?? copy.cwd
            )
            if copy.lastSessionAt == nil { copy.lastSessionAt = details.lastSessionAt }
            if copy.modelName == nil { copy.modelName = details.modelName }
            applyTurn(&copy, from: details)
            return copy
        }
    }

    private func applyTurn(
        _ copy: inout Agent,
        from details: (lastSessionAt: Date?, modelName: String?, turnStartedAt: Date?, turnEndedAt: Date?, lastActivityAt: Date?)
    ) {
        let key = copy.id
        if copy.status == .working {
            // Pin the first Working instant. jsonl often still has the previous
            // end_turn; reusing that user timestamp looks like a running total.
            lock.lock()
            let firstSeen = workingFallback[key] ?? Date()
            workingFallback[key] = firstSeen
            lock.unlock()
            // Live chip = last jsonl write (tool_use / tool_result / user), not
            // the human prompt. That is what CLI `Churning (17s)` measures.
            if details.turnEndedAt == nil, let activity = details.lastActivityAt {
                copy.turnStartedAt = activity
            } else {
                copy.turnStartedAt = firstSeen
            }
            copy.turnEndedAt = nil
        } else {
            lock.lock()
            workingFallback.removeValue(forKey: key)
            lock.unlock()
            copy.turnStartedAt = details.turnStartedAt
            copy.turnEndedAt = details.turnEndedAt
        }
    }

    public func lastSession(id: String?, cwd: String?) -> Date? {
        details(id: id, cwd: cwd).lastSessionAt
    }

    public func details(id: String?, cwd: String?) -> (lastSessionAt: Date?, modelName: String?, turnStartedAt: Date?, turnEndedAt: Date?, lastActivityAt: Date?) {
        guard let id, !id.isEmpty else { return (nil, nil, nil, nil, nil) }
        guard let path = transcriptPath(id: id, cwd: cwd) else { return (nil, nil, nil, nil, nil) }
        let stamp = stamp(at: path)
        return (stamp?.lastSessionAt, stamp?.modelName, stamp?.turnStartedAt, stamp?.turnEndedAt, stamp?.lastActivityAt)
    }

    /// Claude project folder for a cwd: `/Users/me/repo` → `-Users-me-repo`.
    /// Only ASCII letters and digits survive; everything else becomes `-`.
    public static func projectSlug(_ path: String) -> String {
        String(path.map { char in
            char.isASCII && (char.isLetter || char.isNumber) ? char : "-"
        })
    }

    /// `x-ai-grok/grok-4.6` → `Grok 4.6`. Bare `claude-opus-4-6` → `Opus 4.6`.
    public static func shortModel(_ raw: String?) -> String? {
        guard var id = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
            return nil
        }
        if let slash = id.lastIndex(of: "/") {
            id = String(id[id.index(after: slash)...])
        }
        if id.lowercased().hasPrefix("claude-") {
            id = String(id.dropFirst("claude-".count))
        }
        let parts = id.split(separator: "-").map(String.init)
        guard !parts.isEmpty else { return nil }
        var words: [String] = []
        var version: [String] = []
        func flushVersion() {
            if !version.isEmpty {
                words.append(version.joined(separator: "."))
                version.removeAll()
            }
        }
        for part in parts {
            if part.allSatisfy(\.isNumber) || part.contains(".") {
                version.append(part)
            } else {
                flushVersion()
                words.append(part.prefix(1).uppercased() + part.dropFirst())
            }
        }
        flushVersion()
        return words.joined(separator: " ")
    }

    public static func formatElapsed(_ interval: TimeInterval) -> String {
        let seconds = max(Int(interval), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 { return "\(hours)h\(String(format: "%02d", minutes))m" }
        if minutes > 0 { return "\(minutes)m\(String(format: "%02d", secs))s" }
        return "\(secs)s"
    }

    private func transcriptPath(id: String, cwd: String?) -> String? {
        lock.lock()
        if let cached = uuidToPath[id] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let found = locateTranscript(id: id, cwd: cwd)
        if let found {
            lock.lock()
            uuidToPath[id] = found
            lock.unlock()
        }
        return found
    }

    private func locateTranscript(id: String, cwd: String?) -> String? {
        if let cwd, !cwd.isEmpty {
            let direct = projectsRoot + "/" + Self.projectSlug(cwd) + "/" + id + ".jsonl"
            if fileManager.fileExists(atPath: direct) { return direct }
        }
        guard let dirs = try? fileManager.contentsOfDirectory(atPath: projectsRoot) else {
            return nil
        }
        for dir in dirs {
            let candidate = projectsRoot + "/" + dir + "/" + id + ".jsonl"
            if fileManager.fileExists(atPath: candidate) { return candidate }
        }
        return nil
    }

    private func stamp(at path: String) -> Stamp? {
        let mtime = (try? fileManager.attributesOfItem(atPath: path)[.modificationDate]) as? Date
        lock.lock()
        if let cached = pathToStamp[path], cached.mtime == mtime {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let parsed = Self.parseTranscript(at: path)
        let snapshot = Stamp(
            mtime: mtime,
            lastSessionAt: mtime,
            modelName: parsed.modelName,
            turnStartedAt: parsed.turnStartedAt,
            turnEndedAt: parsed.turnEndedAt,
            lastActivityAt: parsed.lastActivityAt
        )
        lock.lock()
        pathToStamp[path] = snapshot
        lock.unlock()
        return snapshot
    }

    /// Tail-scan: last assistant model, last human user timestamp, optional end_turn.
    /// Caps at 512 KiB.
    static func parseTranscript(at path: String) -> (modelName: String?, turnStartedAt: Date?, turnEndedAt: Date?, lastActivityAt: Date?) {
        guard let handle = FileHandle(forReadingAtPath: path) else { return (nil, nil, nil, nil) }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let window: UInt64 = 512 * 1024
        let start = size > window ? size - window : 0
        do {
            try handle.seek(toOffset: start)
            guard let data = try handle.readToEnd(), !data.isEmpty else { return (nil, nil, nil, nil) }
            return parseTranscriptTail(data, startedMidLine: start > 0)
        } catch {
            return (nil, nil, nil, nil)
        }
    }

    static func parseTranscriptTail(_ data: Data, startedMidLine: Bool) -> (modelName: String?, turnStartedAt: Date?, turnEndedAt: Date?, lastActivityAt: Date?) {
        guard let text = String(data: data, encoding: .utf8) else { return (nil, nil, nil, nil) }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if startedMidLine, !lines.isEmpty { lines.removeFirst() }
        var modelName: String?
        var startedAt: Date?
        var endedAt: Date?
        var lastActivityAt: Date?
        for line in lines {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                continue
            }
            if let name = model(from: obj) {
                modelName = shortModel(name)
            }
            let kind = obj["type"] as? String
            let ts = parseISO(obj["timestamp"] as? String)
            if kind == "user" || kind == "assistant", let ts {
                lastActivityAt = ts
            }
            if kind == "user" {
                if isToolResult(obj) {
                    endedAt = nil
                    continue
                }
                if let ts { startedAt = ts }
                endedAt = nil
            } else if kind == "assistant" {
                let message = obj["message"] as? [String: Any]
                let stop = message?["stop_reason"] as? String
                if stop == "end_turn" || stop == "stop_sequence" || stop == "max_tokens" {
                    endedAt = ts
                } else {
                    endedAt = nil
                }
            }
        }
        return (modelName, startedAt, endedAt, lastActivityAt)
    }

    private static func model(from obj: [String: Any]) -> String? {
        if let message = obj["message"] as? [String: Any],
           let model = message["model"] as? String,
           !model.isEmpty
        {
            return model
        }
        if obj["type"] as? String == "assistant",
           let model = obj["model"] as? String,
           !model.isEmpty
        {
            return model
        }
        return nil
    }

    /// jsonl writes tool_result as type=user; that must not start a new turn.
    private static func isToolResult(_ obj: [String: Any]) -> Bool {
        if obj["toolUseResult"] != nil { return true }
        let message = obj["message"] as? [String: Any]
        let content = message?["content"] as? [[String: Any]]
        return content?.contains { $0["type"] as? String == "tool_result" } == true
    }

    static func parseISO(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFrac.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}
