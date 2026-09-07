import Foundation

public struct Agent: Equatable, Sendable, Identifiable {
    public var sessionName: String
    public var paneId: String
    public var name: String?
    public var displayAgent: String?
    public var agentKind: String?
    public var agentStatusRaw: String
    public var stateChangeSeq: Int
    public var cwd: String?
    public var foregroundCwd: String?
    public var terminalTitle: String?
    /// Git branch of `foregroundCwd`/`cwd`. Not a herdr field — filled from `.git/HEAD`.
    public var gitBranch: String?
    /// Claude (or other harness) conversation id from `agent_session.value`.
    public var agentSessionId: String?
    /// Last write to that conversation's transcript. Not a herdr field.
    public var lastSessionAt: Date?
    /// Short model label from the latest assistant `message.model` in the transcript.
    public var modelName: String?
    /// Latest **human** user-turn timestamp (`tool_result` is also `type=user` and is ignored).
    /// Done freezes `turnEndedAt − this`. Working overwrites this with last jsonl
    /// activity (assistant / tool_result) so the chip matches CLI `Churning`.
    public var turnStartedAt: Date?
    /// Assistant `end_turn` of that same prompt. Nil while Working.
    public var turnEndedAt: Date?

    public init(
        sessionName: String,
        paneId: String,
        name: String? = nil,
        displayAgent: String? = nil,
        agentKind: String? = nil,
        agentStatusRaw: String,
        stateChangeSeq: Int = 0,
        cwd: String? = nil,
        foregroundCwd: String? = nil,
        terminalTitle: String? = nil,
        gitBranch: String? = nil,
        agentSessionId: String? = nil,
        lastSessionAt: Date? = nil,
        modelName: String? = nil,
        turnStartedAt: Date? = nil,
        turnEndedAt: Date? = nil
    ) {
        self.sessionName = sessionName
        self.paneId = paneId
        self.name = name
        self.displayAgent = displayAgent
        self.agentKind = agentKind
        self.agentStatusRaw = agentStatusRaw
        self.stateChangeSeq = stateChangeSeq
        self.cwd = cwd
        self.foregroundCwd = foregroundCwd
        self.terminalTitle = terminalTitle
        self.gitBranch = gitBranch
        self.agentSessionId = agentSessionId
        self.lastSessionAt = lastSessionAt
        self.modelName = modelName
        self.turnStartedAt = turnStartedAt
        self.turnEndedAt = turnEndedAt
    }

    public var id: String { "\(sessionName)::\(paneId)" }

    public var status: AgentStatus { AgentStatus.normalize(agentStatusRaw) }

    public var target: String { HerdrLogic.target(for: self) }
}

struct AgentDTO: Decodable {
    var paneId: String?
    var name: String?
    var displayAgent: String?
    var agent: String?
    var agentStatus: String?
    var stateChangeSeq: Int?
    var cwd: String?
    var foregroundCwd: String?
    var terminalTitle: String?
    var terminalTitleStripped: String?
    var agentSession: AgentSessionDTO?

    enum CodingKeys: String, CodingKey {
        case paneId = "pane_id"
        case name
        case displayAgent = "display_agent"
        case agent
        case agentStatus = "agent_status"
        case stateChangeSeq = "state_change_seq"
        case cwd
        case foregroundCwd = "foreground_cwd"
        case terminalTitle = "terminal_title"
        case terminalTitleStripped = "terminal_title_stripped"
        case agentSession = "agent_session"
    }

    func asAgent(sessionName: String) -> Agent? {
        guard let paneId, !paneId.isEmpty else { return nil }
        return Agent(
            sessionName: sessionName,
            paneId: paneId,
            name: name,
            displayAgent: displayAgent,
            agentKind: agent,
            agentStatusRaw: agentStatus ?? "unknown",
            stateChangeSeq: stateChangeSeq ?? 0,
            cwd: cwd,
            foregroundCwd: foregroundCwd,
            terminalTitle: terminalTitleStripped ?? terminalTitle,
            agentSessionId: agentSession?.value
        )
    }
}

struct AgentSessionDTO: Decodable {
    var value: String?
}
