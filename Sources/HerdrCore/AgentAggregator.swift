import Combine
import Foundation

@MainActor
public final class AgentAggregator: ObservableObject {
    @Published public private(set) var snapshots: [String: SessionSnapshot] = [:]
    @Published public private(set) var agents: [Agent] = []
    @Published public private(set) var anyOnline = false
    /// While Working, Herdr may emit no events. Re-read jsonl every 1s; never poll agent.list.
    private var jsonlTick: Timer?

    public init() {}

    public var counts: [AgentStatus: Int] { HerdrLogic.counts(of: agents) }
    public var sortedAgents: [Agent] { HerdrLogic.sortedAgents(agents) }
    public var attentionAgent: Agent? { HerdrLogic.attentionAgent(in: agents) }
    public var onlineSessionNames: [String] {
        snapshots.values.filter(\.online).map(\.name).sorted()
    }

    public var multipleSessionsOnline: Bool { onlineSessionNames.count > 1 }

    public func apply(_ snapshot: SessionSnapshot) {
        snapshots[snapshot.name] = snapshot
        rebuild()
    }

    public func removeSession(named name: String) {
        snapshots.removeValue(forKey: name)
        rebuild()
    }

    public func tooltip(home: String) -> String {
        if !anyOnline {
            return HerdrLogic.tooltip(agents: [], online: false, home: home)
        }
        return HerdrLogic.tooltip(agents: agents, online: true, home: home)
    }

    private func rebuild() {
        let online = snapshots.values.filter(\.online)
        anyOnline = !online.isEmpty
        agents = online.flatMap(\.agents)
        syncJsonlTick()
    }

    private func syncJsonlTick() {
        let working = agents.contains { $0.status == .working }
        if working, jsonlTick == nil {
            jsonlTick = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshWorkingTranscripts()
                }
            }
        } else if !working {
            jsonlTick?.invalidate()
            jsonlTick = nil
        }
    }

    private func refreshWorkingTranscripts() {
        guard agents.contains(where: { $0.status == .working }) else {
            jsonlTick?.invalidate()
            jsonlTick = nil
            return
        }
        agents = SessionTimeCache.shared.enrich(agents)
    }
}
