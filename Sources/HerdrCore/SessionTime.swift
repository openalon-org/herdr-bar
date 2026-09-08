import Foundation

/// Transcript extras for an agent pane.
///
/// `agent.list` has no model and no idle-space recency. The source is the
/// Claude jsonl for `agent_session.value`.
///
/// - `lastSessionAt`: file mtime (idle-space recency)
/// - `modelName`: latest assistant `message.model`
///
/// Duration and token chips are not shown — jsonl is not Claude statusline
/// stdin, so those numbers would not match the CLI footer.
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
    }

    public init(
        projectsRoot: String? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.projectsRoot = projectsRoot
            ?? (fileManager.homeDirectoryForCurrentUser.path + "/.claude/projects")
    }

    public func enrich(_ agents: [Agent]) -> [Agent] {
        agents.map { agent in
            var copy = agent
            let details = details(
                id: copy.agentSessionId,
                cwd: copy.foregroundCwd ?? copy.cwd
            )
            if copy.lastSessionAt == nil { copy.lastSessionAt = details.lastSessionAt }
            if copy.modelName == nil { copy.modelName = details.modelName }
            return copy
        }
    }

    public func lastSession(id: String?, cwd: String?) -> Date? {
        details(id: id, cwd: cwd).lastSessionAt
    }

    public func details(id: String?, cwd: String?) -> (lastSessionAt: Date?, modelName: String?) {
        guard let id, !id.isEmpty else { return (nil, nil) }
        guard let path = transcriptPath(id: id, cwd: cwd) else { return (nil, nil) }
        let stamp = stamp(at: path)
        return (stamp?.lastSessionAt, stamp?.modelName)
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
            modelName: parsed
        )
        lock.lock()
        pathToStamp[path] = snapshot
        lock.unlock()
        return snapshot
    }

    /// Tail-scan for the latest assistant `message.model`. Caps at 512 KiB.
    static func parseTranscript(at path: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        let size = (try? handle.seekToEnd()) ?? 0
        let window: UInt64 = 512 * 1024
        let start = size > window ? size - window : 0
        do {
            try handle.seek(toOffset: start)
            guard let data = try handle.readToEnd(), !data.isEmpty else { return nil }
            return parseTranscriptTail(data, startedMidLine: start > 0)
        } catch {
            return nil
        }
    }

    static func parseTranscriptTail(_ data: Data, startedMidLine: Bool) -> String? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if startedMidLine, !lines.isEmpty { lines.removeFirst() }
        var modelName: String?
        for line in lines {
            guard let obj = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                continue
            }
            if let name = model(from: obj) {
                modelName = shortModel(name)
            }
        }
        return modelName
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
}
