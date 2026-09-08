import Combine
import Foundation

@MainActor
public final class AgentAggregator: ObservableObject {
    @Published public private(set) var snapshots: [String: SessionSnapshot] = [:]
    @Published public private(set) var agents: [Agent] = []
    @Published public private(set) var anyOnline = false

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
    }
}
