import Foundation
import Testing
@testable import HerdrCore

@Suite("Session discovery")
struct SessionDiscoveryTests {
    @Test func discoversDefaultAndNamedSockets() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("herdr-discover-\(UUID().uuidString)")
        let config = root.appendingPathComponent(".config/herdr")
        let sessions = config.appendingPathComponent("sessions/work")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: config.appendingPathComponent("herdr.sock").path, contents: Data())
        FileManager.default.createFile(atPath: sessions.appendingPathComponent("herdr.sock").path, contents: Data())

        let found = SessionDiscovery.discover(home: root.path, extraSockets: [])
        #expect(found.map(\.name) == ["default", "work"])
        try? FileManager.default.removeItem(at: root)
    }

    @Test func pinnedSocketWins() {
        let found = SessionDiscovery.discover(home: "/unused", extraSockets: ["/tmp/herdr-demo.sock"])
        #expect(found == [DiscoveredSession(name: "demo", socketPath: "/tmp/herdr-demo.sock")])
    }
}

@Suite("Aggregator")
struct AggregatorTests {
    @Test @MainActor func mergesSessionsAndPriority() {
        let store = AgentAggregator()
        store.apply(SessionSnapshot(
            name: "default",
            socketPath: "/tmp/a",
            agents: [
                Agent(sessionName: "default", paneId: "p1", name: "idle-one", agentStatusRaw: "idle", stateChangeSeq: 1),
            ],
            online: true
        ))
        store.apply(SessionSnapshot(
            name: "work",
            socketPath: "/tmp/b",
            agents: [
                Agent(sessionName: "work", paneId: "p9", name: "blocked-one", agentStatusRaw: "blocked", stateChangeSeq: 3),
                Agent(sessionName: "work", paneId: "p8", name: "done-one", agentStatusRaw: "done", stateChangeSeq: 9),
            ],
            online: true
        ))
        #expect(store.agents.count == 3)
        #expect(store.counts[.blocked] == 1)
        #expect(store.counts[.done] == 1)
        #expect(store.attentionAgent?.sessionName == "work")
        #expect(store.attentionAgent?.paneId == "p9")
        #expect(store.multipleSessionsOnline)
        store.apply(SessionSnapshot(name: "work", socketPath: "/tmp/b", agents: [], online: false))
        #expect(store.agents.count == 1)
        #expect(!store.multipleSessionsOnline)
    }
}
