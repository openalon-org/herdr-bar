import Foundation

/// Reads the current branch from `.git/HEAD` without spawning `git`.
/// Herdr's `agent.list` has no branch field; the title is a conversation summary.
public final class GitBranchCache: @unchecked Sendable {
    public static let shared = GitBranchCache()

    private let lock = NSLock()
    private var cwdToGitDir: [String: String?] = [:]
    private var gitDirToHead: [String: HeadSnapshot] = [:]
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func branch(for cwd: String?) -> String? {
        guard let cwd, !cwd.isEmpty else { return nil }
        guard let gitDir = gitDirectory(for: cwd) else { return nil }
        return head(in: gitDir)?.branch
    }

    public func enrich(_ agents: [Agent]) -> [Agent] {
        agents.map { agent in
            var copy = agent
            if copy.gitBranch == nil {
                copy.gitBranch = branch(for: copy.foregroundCwd ?? copy.cwd)
            }
            return copy
        }
    }

    // MARK: - HEAD

    struct HeadSnapshot {
        var branch: String?
        var mtime: Date?
    }

    func head(in gitDir: String) -> HeadSnapshot? {
        let headPath = gitDir + "/HEAD"
        let mtime = (try? fileManager.attributesOfItem(atPath: headPath)[.modificationDate]) as? Date
        lock.lock()
        if let cached = gitDirToHead[gitDir], cached.mtime == mtime {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let text = (try? String(contentsOfFile: headPath, encoding: .utf8)) ?? ""
        let snapshot = HeadSnapshot(branch: Self.parseHEAD(text), mtime: mtime)
        lock.lock()
        gitDirToHead[gitDir] = snapshot
        lock.unlock()
        return snapshot
    }

    /// `ref: refs/heads/feature/login` → `feature/login`. Detached SHA → first 7 hex chars.
    public static func parseHEAD(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("ref:") {
            let ref = text.dropFirst(4).trimmingCharacters(in: .whitespacesAndNewlines)
            if ref.hasPrefix("refs/heads/") {
                let name = String(ref.dropFirst("refs/heads/".count))
                return name.isEmpty ? nil : name
            }
            if let slash = ref.lastIndex(of: "/") {
                let name = String(ref[ref.index(after: slash)...])
                return name.isEmpty ? nil : name
            }
            return ref.isEmpty ? nil : ref
        }
        let hex = text.filter(\.isHexDigit)
        guard hex.count >= 7, hex.count == text.count else { return nil }
        return String(hex.prefix(7))
    }

    // MARK: - Discover .git

    func gitDirectory(for cwd: String) -> String? {
        lock.lock()
        if let cached = cwdToGitDir[cwd] {
            lock.unlock()
            return cached
        }
        lock.unlock()
        let found = locateGitDirectory(startingAt: cwd)
        lock.lock()
        cwdToGitDir[cwd] = found
        lock.unlock()
        return found
    }

    private func locateGitDirectory(startingAt cwd: String) -> String? {
        var dir = URL(fileURLWithPath: cwd, isDirectory: true)
        var seen = Set<String>()
        while seen.insert(dir.path).inserted {
            let git = dir.appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: git.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue { return git.path }
                if let pointed = gitdirPointer(at: git.path) { return pointed }
            }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    /// Worktree `.git` files: `gitdir: /repo/.git/worktrees/foo`
    private func gitdirPointer(at path: String) -> String? {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return nil }
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("gitdir:") {
                let value = trimmed.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
                if value.isEmpty { return nil }
                if value.hasPrefix("/") { return value }
                return URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent(value).path
            }
        }
        return nil
    }
}
