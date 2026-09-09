import Foundation
import Testing
@testable import HerdrCore

@Suite("HerdrLogic matches Herdr.js")
struct HerdrLogicTests {
    let agents: [Agent] = [
        Agent(sessionName: "default", paneId: "idle", name: "idle-agent", agentStatusRaw: "idle", stateChangeSeq: 99),
        Agent(sessionName: "default", paneId: "done-old", name: "done-old", agentStatusRaw: "done", stateChangeSeq: 4),
        Agent(sessionName: "default", paneId: "blocked", name: "blocked-agent", agentStatusRaw: "blocked", stateChangeSeq: 1),
        Agent(sessionName: "default", paneId: "done-new", name: "done-new", agentStatusRaw: "done", stateChangeSeq: 8),
        Agent(sessionName: "default", paneId: "future", name: "future-agent", agentStatusRaw: "new-state", stateChangeSeq: 200),
    ]

    @Test func normalizeUnknownStatus() {
        #expect(agents[4].status == .unknown)
    }

    @Test func attentionStatusesNeedYou() {
        #expect(AgentStatus.blocked.needsAttention)
        #expect(AgentStatus.done.needsAttention)
        #expect(AgentStatus.unknown.needsAttention)
        #expect(!AgentStatus.working.needsAttention)
        #expect(!AgentStatus.idle.needsAttention)
    }

    @Test func countsMatchOracle() {
        let counts = HerdrLogic.counts(of: agents)
        #expect(counts[.blocked] == 1)
        #expect(counts[.done] == 2)
        #expect(counts[.working] == 0)
        #expect(counts[.unknown] == 1)
        #expect(counts[.idle] == 1)
    }

    @Test func attentionPrefersBlockedThenNewestSeq() {
        #expect(HerdrLogic.attentionAgent(in: agents)?.paneId == "blocked")
        let doneOnly = [agents[1], agents[3]]
        #expect(HerdrLogic.attentionAgent(in: doneOnly)?.paneId == "done-new")
    }

    @Test func sortedOrder() {
        let ids = HerdrLogic.sortedAgents(agents).map(\.paneId)
        #expect(ids == ["blocked", "done-new", "done-old", "future", "idle"])
    }

    @Test func targetPrefersName() {
        #expect(HerdrLogic.target(for: Agent(sessionName: "default", paneId: "pane", name: "named", agentStatusRaw: "idle")) == "named")
        #expect(HerdrLogic.target(for: Agent(sessionName: "default", paneId: "pane", agentStatusRaw: "idle")) == "pane")
    }

    @Test func shortenHomePath() {
        #expect(HerdrLogic.shortenPath("/home/user/Developer/project", home: "/home/user") == "~/Developer/project")
    }

    @Test func socketPathResolution() {
        #expect(HerdrLogic.socketPath(home: "/home/user", session: "default", explicitPath: "") == "/home/user/.config/herdr/herdr.sock")
        #expect(HerdrLogic.socketPath(home: "/home/user", session: "work", explicitPath: "") == "/home/user/.config/herdr/sessions/work/herdr.sock")
        #expect(HerdrLogic.socketPath(home: "/home/user", session: "work", explicitPath: "~/custom.sock") == "/home/user/custom.sock")
    }

    @Test func subscriptionsAndPaneKey() {
        let statusChanged = HerdrLogic.subscriptions(for: agents).filter { $0["type"] == "pane.agent_status_changed" }
        #expect(statusChanged.count == 5)
        #expect(HerdrLogic.paneKey(of: [
            Agent(sessionName: "default", paneId: "b", agentStatusRaw: "idle"),
            Agent(sessionName: "default", paneId: "a", agentStatusRaw: "idle"),
        ]) == "a\nb")
    }

    @Test func tooltipCopy() {
        let blocked = [agents[2]]
        let text = HerdrLogic.tooltip(agents: blocked, online: true, home: "/home/user")
        #expect(text.contains("Blocked  blocked-agent"))
        #expect(text.contains("Left-click: open dashboard"))
        #expect(HerdrLogic.tooltip(agents: [], online: false, home: "/home/user").contains("offline"))
    }

    @Test func shortPaneDropsWorkspacePrefix() {
        #expect(HerdrLogic.shortPane("w2:p7") == "p7")
        #expect(HerdrLogic.shortPane("p7") == "p7")
    }

    @Test func subtitleAddsBranchAndModel() {
        let a = Agent(
            sessionName: "work",
            paneId: "w2:p7",
            name: "one",
            agentStatusRaw: "idle",
            cwd: "/home/user/repo",
            gitBranch: "feature/login"
        )
        let b = Agent(
            sessionName: "work",
            paneId: "w2:p8",
            name: "two",
            agentStatusRaw: "idle",
            cwd: "/home/user/repo",
            gitBranch: "feature/login"
        )
        let unique = Agent(
            sessionName: "work",
            paneId: "w2:p1",
            name: "solo",
            agentStatusRaw: "idle",
            cwd: "/home/user/other",
            gitBranch: "main"
        )
        let among = [a, b, unique]
        #expect(
            HerdrLogic.subtitle(for: a, among: among, home: "/home/user", showSession: true)
                == "work · repo · feature/login"
        )
        #expect(
            HerdrLogic.subtitle(for: unique, among: among, home: "/home/user", showSession: true)
                == "work · other · main"
        )
        #expect(HerdrLogic.folderName("/home/user/workspace/alpha") == "alpha")
        #expect(HerdrLogic.folderName("/home/user/workspace/alpha/") == "alpha")
        let withModel = Agent(
            sessionName: "work",
            paneId: "w2:p1",
            name: "solo",
            agentStatusRaw: "working",
            cwd: "/home/user/other",
            gitBranch: "main",
            modelName: "Grok 4.6"
        )
        #expect(
            HerdrLogic.subtitle(for: withModel, among: [withModel], home: "/home/user", showSession: true)
                == "work · other · main · Grok 4.6"
        )
    }

    @Test func filterBySessionGroupAndStatus() {
        let workAlpha = Agent(
            sessionName: "work",
            paneId: "p7",
            name: "worker",
            agentStatusRaw: "working",
            cwd: "/home/user/alpha"
        )
        let workMerge = Agent(
            sessionName: "work",
            paneId: "p1",
            name: "helper",
            agentStatusRaw: "idle",
            cwd: "/home/user/merge"
        )
        let defET = Agent(
            sessionName: "default",
            paneId: "p3",
            name: "builder",
            agentStatusRaw: "working",
            cwd: "/home/user/beta"
        )
        let all = [workAlpha, workMerge, defET]
        #expect(HerdrLogic.filtered(all, by: AgentFilter(session: "work")).map(\.paneId) == ["p7", "p1"])
        #expect(HerdrLogic.filtered(all, by: AgentFilter()).map(\.paneId) == ["p7", "p1", "p3"])
        #expect(AgentFilter().isActive == false)
        #expect(AgentFilter(session: "work").isActive)
        #expect(AgentFilter(session: "missing").matches(workAlpha) == false)
    }

    @Test func groupedIsSessionThenFolderThenStatus() {
        let defIdle = Agent(
            sessionName: "default",
            paneId: "p2",
            name: "notes",
            agentStatusRaw: "idle",
            stateChangeSeq: 1,
            cwd: "/home/user/notes"
        )
        let defWork = Agent(
            sessionName: "default",
            paneId: "p3",
            name: "builder",
            agentStatusRaw: "working",
            stateChangeSeq: 4,
            cwd: "/home/user/beta"
        )
        let workAlphaBusy = Agent(
            sessionName: "work",
            paneId: "p7",
            name: "worker",
            agentStatusRaw: "working",
            stateChangeSeq: 9,
            cwd: "/home/user/alpha"
        )
        let workAlphaIdle = Agent(
            sessionName: "work",
            paneId: "p1",
            name: "helper",
            agentStatusRaw: "idle",
            stateChangeSeq: 2,
            cwd: "/home/user/alpha"
        )
        let groups = HerdrLogic.grouped([workAlphaIdle, defIdle, workAlphaBusy, defWork])
        #expect(groups.map(\.folder) == ["alpha", "beta", "notes"])
        #expect(groups[0].agents.map(\.paneId) == ["p7", "p1"])
        #expect(groups[1].agents.map(\.paneId) == ["p3"])
        #expect(HerdrLogic.groupHeader(for: groups[0]) == "alpha")
    }

    @Test func idleGroupsSortByLastSession() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)
        let newest = Date(timeIntervalSince1970: 3_000)
        let merge = Agent(
            sessionName: "work",
            paneId: "p1",
            name: "helper",
            agentStatusRaw: "idle",
            stateChangeSeq: 99,
            cwd: "/home/user/merge",
            lastSessionAt: older
        )
        let notesLate = Agent(
            sessionName: "default",
            paneId: "p9",
            name: "zeta",
            agentStatusRaw: "idle",
            stateChangeSeq: 1,
            cwd: "/home/user/notes",
            lastSessionAt: newest
        )
        let notesEarly = Agent(
            sessionName: "work",
            paneId: "w2:p3",
            name: "alpha",
            agentStatusRaw: "idle",
            stateChangeSeq: 2,
            cwd: "/home/user/notes",
            lastSessionAt: newer
        )
        let et = Agent(
            sessionName: "default",
            paneId: "p4",
            name: "builder",
            agentStatusRaw: "idle",
            cwd: "/home/user/gamma",
            lastSessionAt: newer
        )
        let groups = HerdrLogic.grouped([merge, notesLate, notesEarly, et])
        #expect(groups.map(\.folder) == ["notes", "gamma", "merge"])
        #expect(groups[0].agents.map(\.paneId) == ["p9", "w2:p3"])
        #expect(HerdrLogic.sortedAgents([notesEarly, notesLate]).map(\.paneId) == ["p9", "w2:p3"])
    }

    @Test func sameStatusRowsPreferNewerSessionOverPane() {
        let older = Agent(
            sessionName: "default",
            paneId: "p1",
            name: "migrate",
            agentStatusRaw: "idle",
            cwd: "/home/user/handbook",
            lastSessionAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = Agent(
            sessionName: "default",
            paneId: "p3",
            name: "billing",
            agentStatusRaw: "idle",
            cwd: "/home/user/handbook",
            lastSessionAt: Date(timeIntervalSince1970: 2_000)
        )
        #expect(HerdrLogic.grouped([older, newer])[0].agents.map(\.paneId) == ["p3", "p1"])
        #expect(HerdrLogic.sortedAgents([older, newer]).map(\.paneId) == ["p3", "p1"])
    }

    @Test func paneNumberParsesTokens() {
        #expect(HerdrLogic.paneNumber("w2:p7") == 7)
        #expect(HerdrLogic.paneNumber("p1") == 1)
    }

    @Test func workingGroupsStayAboveNewerIdle() {
        let ancient = Date(timeIntervalSince1970: 10)
        let now = Date(timeIntervalSince1970: 9_999)
        let working = Agent(
            sessionName: "default",
            paneId: "p1",
            name: "guide",
            agentStatusRaw: "working",
            cwd: "/home/user/guide",
            lastSessionAt: ancient
        )
        let idle = Agent(
            sessionName: "work",
            paneId: "p2",
            name: "gamma",
            agentStatusRaw: "idle",
            cwd: "/home/user/gamma",
            lastSessionAt: now
        )
        #expect(HerdrLogic.grouped([idle, working]).map(\.folder) == ["guide", "gamma"])
    }

    @Test func idleWithoutSessionTimeSortsLast() {
        let dated = Agent(
            sessionName: "default",
            paneId: "p1",
            name: "gamma",
            agentStatusRaw: "idle",
            cwd: "/home/user/gamma",
            lastSessionAt: Date(timeIntervalSince1970: 50)
        )
        let undated = Agent(
            sessionName: "work",
            paneId: "p2",
            name: "notes",
            agentStatusRaw: "idle",
            cwd: "/home/user/notes"
        )
        #expect(HerdrLogic.grouped([undated, dated]).map(\.folder) == ["gamma", "notes"])
    }

    @Test func notificationModeHidesIdleInMixedGroups() {
        let working = Agent(
            sessionName: "work",
            paneId: "p6",
            name: "flow",
            agentStatusRaw: "working",
            cwd: "/home/user/alpha"
        )
        let idleA = Agent(
            sessionName: "work",
            paneId: "p1",
            name: "helper",
            agentStatusRaw: "idle",
            cwd: "/home/user/alpha"
        )
        let idleB = Agent(
            sessionName: "work",
            paneId: "p3",
            name: "parser",
            agentStatusRaw: "idle",
            cwd: "/home/user/alpha"
        )
        let quiet = Agent(
            sessionName: "default",
            paneId: "p2",
            name: "notes",
            agentStatusRaw: "idle",
            cwd: "/home/user/notes"
        )
        let groups = HerdrLogic.grouped([working, idleA, idleB, quiet])
        #expect(groups.map(\.folder) == ["alpha", "notes"])
        #expect(HerdrLogic.visibleAgents(in: groups[0], hideIdle: true).map(\.paneId) == ["p6"])
        #expect(HerdrLogic.hiddenIdleCount(in: groups[0], hideIdle: true) == 2)
        #expect(HerdrLogic.visibleAgents(in: groups[1], hideIdle: true).isEmpty)
        #expect(HerdrLogic.hiddenIdleCount(in: groups[1], hideIdle: true) == 0)
        #expect(HerdrLogic.visibleAgents(in: groups[0], hideIdle: false).map(\.paneId) == ["p6", "p1", "p3"])
    }
}

@Suite("Git HEAD parsing")
struct GitBranchTests {
    @Test func parseSymbolicAndDetachedHEAD() {
        #expect(GitBranchCache.parseHEAD("ref: refs/heads/feature/login\n") == "feature/login")
        #expect(GitBranchCache.parseHEAD("ref: refs/heads/main") == "main")
        #expect(GitBranchCache.parseHEAD("a1b2c3d4e5f6a7b8c9d0\n") == "a1b2c3d")
        #expect(GitBranchCache.parseHEAD("") == nil)
    }

    @Test func readsWorktreePointerAndHEAD() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("herdr-git-\(UUID().uuidString)")
        let repo = root.appendingPathComponent("repo")
        let git = repo.appendingPathComponent(".git")
        let worktree = root.appendingPathComponent("wt")
        try FileManager.default.createDirectory(at: git, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)
        try "ref: refs/heads/feature/login\n".write(to: git.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        try "gitdir: \(git.path)\n".write(to: worktree.appendingPathComponent(".git"), atomically: true, encoding: .utf8)
        let cache = GitBranchCache()
        #expect(cache.branch(for: repo.path) == "feature/login")
        #expect(cache.branch(for: worktree.path) == "feature/login")
        try? FileManager.default.removeItem(at: root)
    }
}

@Suite("Session transcript time")
struct SessionTimeTests {
    @Test func projectSlugMatchesClaude() {
        #expect(SessionTimeCache.projectSlug("/Users/me/Projects/alpha") == "-Users-me-Projects-alpha")
        #expect(SessionTimeCache.projectSlug("/Users/me/workspace/app.local") == "-Users-me-workspace-app-local")
        #expect(SessionTimeCache.projectSlug("/Users/我/项目") == "-Users-----")
    }

    @Test func lastSessionReadsJsonlMtime() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("herdr-session-\(UUID().uuidString)")
        let project = root.appendingPathComponent("-Users-me-gamma")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        let jsonl = project.appendingPathComponent("\(id).jsonl")
        try "x\n".write(to: jsonl, atomically: true, encoding: .utf8)
        let then = Date(timeIntervalSince1970: 1_700_000_000)
        try FileManager.default.setAttributes([.modificationDate: then], ofItemAtPath: jsonl.path)
        let cache = SessionTimeCache(projectsRoot: root.path)
        #expect(cache.lastSession(id: id, cwd: "/Users/me/gamma") == then)
        let misplaced = Agent(
            sessionName: "default",
            paneId: "p1",
            agentStatusRaw: "idle",
            cwd: "/Users/me/other",
            agentSessionId: id
        )
        #expect(cache.enrich([misplaced]).first?.lastSessionAt == then)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func missingTranscriptIsNotCached() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("herdr-session-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let id = "bbbbbbbb-cccc-dddd-eeee-ffffffffffff"
        let cache = SessionTimeCache(projectsRoot: root.path)
        #expect(cache.lastSession(id: id, cwd: "/Users/me/gamma") == nil)
        let project = root.appendingPathComponent("-Users-me-gamma")
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let jsonl = project.appendingPathComponent("\(id).jsonl")
        try "x\n".write(to: jsonl, atomically: true, encoding: .utf8)
        #expect(cache.lastSession(id: id, cwd: "/Users/me/gamma") != nil)
        try? FileManager.default.removeItem(at: root)
    }

    @Test func shortModel() {
        #expect(SessionTimeCache.shortModel("x-ai-grok/grok-4.6") == "Grok 4.6")
        #expect(SessionTimeCache.shortModel("claude-opus-4-6") == "Opus 4.6")
        #expect(SessionTimeCache.shortModel("anthropic-claude/claude-sonnet-5") == "Sonnet 5")
    }

    @Test func parseTranscriptTailReadsLatestModel() {
        let user = #"{"type":"user","timestamp":"2026-09-06T06:00:00.000Z"}"#
        let first = #"{"type":"assistant","message":{"model":"claude-sonnet-5","role":"assistant"}}"#
        let last = #"{"type":"assistant","timestamp":"2026-09-06T06:01:00.000Z","message":{"model":"x-ai-grok/grok-4.6","role":"assistant"}}"#
        let data = Data((user + "\n" + first + "\n" + last + "\n").utf8)
        #expect(SessionTimeCache.parseTranscriptTail(data, startedMidLine: false) == "Grok 4.6")
    }

    @Test func enrichCopiesModelFromTranscript() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("herdr-model-\(UUID().uuidString)")
        let cwd = "/Users/me/repo"
        let slug = SessionTimeCache.projectSlug(cwd)
        let project = root.appendingPathComponent(slug)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        let id = UUID().uuidString
        let jsonl = project.appendingPathComponent("\(id).jsonl")
        let body = """
        {"type":"assistant","message":{"model":"x-ai-grok/grok-4.6"}}
        """
        try body.write(to: jsonl, atomically: true, encoding: .utf8)
        let cache = SessionTimeCache(projectsRoot: root.path)
        let working = Agent(
            sessionName: "default",
            paneId: "p3",
            agentStatusRaw: "working",
            cwd: cwd,
            agentSessionId: id
        )
        #expect(cache.enrich([working])[0].modelName == "Grok 4.6")
        try? FileManager.default.removeItem(at: root)
    }
}

@Suite("Status palette")
struct StatusPaletteTests {
    @Test func defaultHexMatchesClaudeTabStatus() {
        #expect(AgentStatus.blocked.defaultHexColor == "#5F87FF")
        #expect(AgentStatus.done.defaultHexColor == "#00D75F")
        #expect(AgentStatus.working.defaultHexColor == "#CF7650")
        #expect(AgentStatus.unknown.defaultHexColor == "#C7A35A")
        #expect(AgentStatus.idle.defaultHexColor == "#888888")
    }

    @Test func normalizesHex() {
        #expect(StatusPalette.normalize("#ff9500") == "#FF9500")
        #expect(StatusPalette.normalize("5F87FF") == "#5F87FF")
        #expect(StatusPalette.normalize("#f80") == "#FF8800")
        #expect(StatusPalette.normalize("not-a-color") == nil)
        #expect(StatusPalette.normalize("#gg0000") == nil)
    }

    @Test func loadsColorsObject() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("palette-\(UUID().uuidString).json")
        try """
        { "colors": { "working": "#112233", "done": "00aa00", "idle": "not-hex" } }
        """.write(to: file, atomically: true, encoding: .utf8)
        let loaded = StatusPalette.load(from: file.path)
        #expect(loaded[.working] == "#112233")
        #expect(loaded[.done] == "#00AA00")
        #expect(loaded[.idle] == nil)
        try? FileManager.default.removeItem(at: file)
    }

    @Test func loadIgnoresDefaultHex() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("palette-\(UUID().uuidString).json")
        try """
        { "colors": { "working": "#CF7650", "blocked": "#112233" } }
        """.write(to: file, atomically: true, encoding: .utf8)
        let loaded = StatusPalette.load(from: file.path)
        #expect(loaded[.working] == nil)
        #expect(loaded[.blocked] == "#112233")
        try? FileManager.default.removeItem(at: file)
    }

    @Test func persistDeletesEmptyFile() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("palette-\(UUID().uuidString).json")
        try """
        { "colors": { "idle": "#111111" } }
        """.write(to: file, atomically: true, encoding: .utf8)
        try StatusPalette.persist([:], to: file.path)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func persistDropsEmptyAndKeepsOtherKeys() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("palette-\(UUID().uuidString).json")
        try """
        { "keep": true, "colors": { "idle": "#111111" } }
        """.write(to: file, atomically: true, encoding: .utf8)
        try StatusPalette.persist([.working: "#FF9500"], to: file.path)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(json?["keep"] as? Bool == true)
        let colors = json?["colors"] as? [String: String]
        #expect(colors?["working"] == "#FF9500")
        #expect(colors?["idle"] == nil)
        try StatusPalette.persist([:], to: file.path)
        let emptied = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(emptied?["keep"] as? Bool == true)
        #expect(emptied?["colors"] == nil)
        try? FileManager.default.removeItem(at: file)
    }
}

@Suite("App preferences")
struct AppPreferencesTests {
    @Test func hideIdleDefaultsTrueAndOmitsFromDisk() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("prefs-\(UUID().uuidString).json")
        #expect(AppPreferences.loadHideIdle(from: file.path) == true)
        try AppPreferences.persistHideIdle(false, to: file.path)
        #expect(AppPreferences.loadHideIdle(from: file.path) == false)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(json?["hideIdle"] as? Bool == false)
        try AppPreferences.persistHideIdle(true, to: file.path)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        try? FileManager.default.removeItem(at: file)
    }

    @Test func hideIdleKeepsColorOverrides() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("prefs-\(UUID().uuidString).json")
        try """
        { "colors": { "working": "#112233" } }
        """.write(to: file, atomically: true, encoding: .utf8)
        try AppPreferences.persistHideIdle(false, to: file.path)
        let shown = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(shown?["hideIdle"] as? Bool == false)
        #expect((shown?["colors"] as? [String: String])?["working"] == "#112233")
        try AppPreferences.persistHideIdle(true, to: file.path)
        let hidden = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        #expect(hidden?["hideIdle"] == nil)
        #expect((hidden?["colors"] as? [String: String])?["working"] == "#112233")
        try? FileManager.default.removeItem(at: file)
    }

    @Test func hotkeyRoundTripAndDisplay() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("prefs-\(UUID().uuidString).json")
        #expect(AppPreferences.loadHotkey(from: file.path) == nil)
        let spec = HotkeySpec(keyCode: 4, command: true, option: true, control: false, shift: false)
        #expect(spec.display == "⌥⌘H")
        #expect(spec.carbonModifiers == (1 << 8) | (1 << 11))
        try AppPreferences.persistHotkey(spec, to: file.path)
        let loaded = AppPreferences.loadHotkey(from: file.path)
        #expect(loaded == spec)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        let obj = json?["hotkey"] as? [String: Any]
        #expect(obj?["keyCode"] as? Int == 4)
        #expect(obj?["command"] as? Bool == true)
        #expect(obj?["option"] as? Bool == true)
        #expect(obj?["shift"] == nil)
        try AppPreferences.persistHotkey(nil, to: file.path)
        #expect(AppPreferences.loadHotkey(from: file.path) == nil)
        try? FileManager.default.removeItem(at: file)
    }
}

@Suite("Login item")
struct LoginItemTests {
    @Test func packedAppIsABundleNotABareBinary() {
        #expect(LoginItem.isPackedApp(bundlePath: "/Applications/HerdrBar.app"))
        #expect(LoginItem.isPackedApp(bundlePath: "/tmp/HerdrBar.app/"))
        #expect(!LoginItem.isPackedApp(bundlePath: "/tmp/.build/release/MacBar"))
        #expect(!LoginItem.isPackedApp(bundlePath: "/usr/bin/MacBar"))
    }

    @Test func switchStaysOnUntilApprovalOrUnregister() {
        #expect(LoginItem.isOn(.enabled))
        #expect(LoginItem.isOn(.requiresApproval))
        #expect(!LoginItem.isOn(.notRegistered))
        #expect(!LoginItem.isOn(.notFound))
    }

    @Test func footerExplainsUnpackagedAndApproval() {
        #expect(LoginItem.footer(packed: false, status: .notRegistered, error: nil).contains("swift run"))
        #expect(LoginItem.footer(packed: true, status: .requiresApproval, error: nil).contains("Login Items"))
        #expect(LoginItem.footer(packed: true, status: .notFound, error: nil).contains("packed app"))
        #expect(LoginItem.footer(packed: true, status: .enabled, error: "denied").contains("denied"))
        #expect(LoginItem.footer(packed: true, status: .enabled, error: nil).contains("log in"))
    }
}

@Suite("Working spinner")
struct WorkingSpinnerTests {
    @Test func darwinPingPongFrames() {
        #expect(WorkingSpinner.characters == ["·", "✢", "✳", "✶", "✻", "✽"])
        #expect(WorkingSpinner.restGlyph == "✻")
        #expect(WorkingSpinner.frames.count == 12)
        #expect(WorkingSpinner.frames[5] == "✽")
        #expect(WorkingSpinner.frames[6] == "✽")
        #expect(WorkingSpinner.frames.last == "·")
        #expect(WorkingSpinner.frameDuration == 0.12)
        let t0 = Date(timeIntervalSinceReferenceDate: 0)
        #expect(WorkingSpinner.frameIndex(at: t0) == 0)
        #expect(WorkingSpinner.frame(at: t0) == "·")
        let t1 = Date(timeIntervalSinceReferenceDate: 0.125)
        #expect(WorkingSpinner.frameIndex(at: t1) == 1)
        #expect(WorkingSpinner.frame(at: t1) == "✢")
        let wrap = Date(timeIntervalSinceReferenceDate: 1.44)
        #expect(WorkingSpinner.frameIndex(at: wrap) == 0)
    }
}

@Suite("Dashboard keyboard nav")
struct DashboardNavTests {
    private func agent(_ session: String, _ pane: String, _ status: String, cwd: String) -> Agent {
        Agent(sessionName: session, paneId: pane, name: pane, agentStatusRaw: status, cwd: cwd)
    }

    @Test func sessionChipsIncludeAllThenNames() {
        #expect(DashboardNav.sessionOptions(["default"]) == [])
        #expect(DashboardNav.sessionOptions(["default", "work"]) == [nil, "default", "work"])
        #expect(DashboardNav.stepSession(current: nil, online: ["default", "work"], by: 1) == "default")
        #expect(DashboardNav.stepSession(current: "work", online: ["default", "work"], by: 1) == nil)
        #expect(DashboardNav.stepSession(current: nil, online: ["default", "work"], by: -1) == "work")
        #expect(DashboardNav.stepSession(current: "default", online: ["default"], by: 1) == "default")
    }

    @Test func arrowsWalkVisibleRowsAndWrap() {
        let working = agent("work", "p6", "working", cwd: "/home/user/alpha")
        let idleA = agent("work", "p1", "idle", cwd: "/home/user/alpha")
        let notes = agent("default", "p2", "working", cwd: "/home/user/notes")
        let groups = HerdrLogic.grouped([working, idleA, notes])
        let ids = DashboardNav.visibleIDs(in: groups, hideIdle: true).flatMap { $0 }
        #expect(ids.count == 2)
        #expect(!ids.contains(idleA.id))
        let first = DashboardNav.stepRow(groups: groups, hideIdle: true, selected: nil, by: 1)
        #expect(first == ids[0])
        let next = DashboardNav.stepRow(groups: groups, hideIdle: true, selected: ids[0], by: 1)
        #expect(next == ids[1])
        let wrap = DashboardNav.stepRow(groups: groups, hideIdle: true, selected: ids[1], by: 1)
        #expect(wrap == ids[0])
        let back = DashboardNav.stepRow(groups: groups, hideIdle: true, selected: ids[0], by: -1)
        #expect(back == ids[1])
    }

    @Test func leftRightHopFoldersWhenNoSessionChips() {
        let a = agent("default", "p1", "working", cwd: "/home/user/guide")
        let b = agent("default", "p2", "working", cwd: "/home/user/gamma")
        let groups = HerdrLogic.grouped([a, b])
        let next = DashboardNav.stepGroup(groups: groups, hideIdle: true, selected: a.id, by: 1)
        #expect(next == b.id)
        let wrap = DashboardNav.stepGroup(groups: groups, hideIdle: true, selected: b.id, by: 1)
        #expect(wrap == a.id)
    }

    @Test func clampKeepsSelectionThenFallsBack() {
        let a = agent("default", "p1", "working", cwd: "/home/user/guide")
        let b = agent("default", "p2", "idle", cwd: "/home/user/guide")
        let groups = HerdrLogic.grouped([a, b])
        #expect(DashboardNav.clampSelection(groups: groups, hideIdle: true, selected: a.id, preferred: b.id) == a.id)
        #expect(DashboardNav.clampSelection(groups: groups, hideIdle: true, selected: "gone", preferred: a.id) == a.id)
        #expect(DashboardNav.clampSelection(groups: groups, hideIdle: true, selected: nil, preferred: nil) == a.id)
    }

    @Test func firstInSessionIsNamedSessionListHead() {
        let idleOnly = agent("work", "p9", "idle", cwd: "/home/user/notes")
        let blocked = agent("default", "p1", "blocked", cwd: "/home/user/gamma")
        let working = agent("work", "p2", "working", cwd: "/home/user/alpha")
        let idleMixed = agent("work", "p3", "idle", cwd: "/home/user/alpha")
        let agents = [idleOnly, blocked, working, idleMixed]
        // work: alpha (working) ranks above idle-only notes.
        #expect(DashboardNav.firstInSession(in: agents, session: "work")?.id == working.id)
        #expect(DashboardNav.firstInSession(in: agents, session: "default")?.id == blocked.id)
        // Idle-only session still has a first task — the chip arrow ignores the eye.
        #expect(DashboardNav.firstInSession(in: [idleOnly], session: "work")?.id == idleOnly.id)
        #expect(DashboardNav.firstInSession(in: agents, session: "missing") == nil)

        let done = agent("work", "p4", "done", cwd: "/home/user/beta")
        let blockedWork = agent("work", "p5", "blocked", cwd: "/home/user/gamma")
        let withDone = [idleOnly, working, idleMixed, done]
        // Arrow = list head. Done ranks above working / idle; blocked still ranks above done.
        #expect(DashboardNav.firstInSession(in: withDone, session: "work")?.id == done.id)
        #expect(DashboardNav.firstInSession(in: withDone + [blockedWork], session: "work")?.id == blockedWork.id)
    }
}
