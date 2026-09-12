import Foundation

public struct SessionSnapshot: Equatable, Sendable {
    public var name: String
    public var socketPath: String
    public var agents: [Agent]
    public var online: Bool

    public init(name: String, socketPath: String, agents: [Agent] = [], online: Bool = false) {
        self.name = name
        self.socketPath = socketPath
        self.agents = agents
        self.online = online
    }
}

/// One herdr session: command socket for list/focus, subscribe socket for events.
public final class SessionWatcher: @unchecked Sendable {
    public let name: String
    public let socketPath: String

    private let client: HerdrClient
    private let queue = DispatchQueue(label: "herdr.session.\(UUID().uuidString)")
    private let onChange: (SessionSnapshot) -> Void

    private var snapshot: SessionSnapshot
    private var refreshPending = false
    private var subscription: SubscribeHandle?
    private var subscribedPaneKey = ""
    private var reconnectDelay: TimeInterval = 1
    private var reconnectWork: DispatchWorkItem?
    private var stopped = false

    public init(name: String, socketPath: String, onChange: @escaping (SessionSnapshot) -> Void) {
        self.name = name
        self.socketPath = socketPath
        self.client = HerdrClient(socketPath: socketPath, sessionName: name)
        self.onChange = onChange
        self.snapshot = SessionSnapshot(name: name, socketPath: socketPath)
    }

    public func start() {
        queue.async { self.refresh() }
    }

    public func stop() {
        queue.async {
            self.stopped = true
            self.reconnectWork?.cancel()
            self.subscription?.cancel()
            self.subscription = nil
            self.snapshot = SessionSnapshot(name: self.name, socketPath: self.socketPath)
            self.emit()
        }
    }

    public func refreshNow() {
        queue.async { self.refresh() }
    }

    public func focus(target: String) throws {
        try client.focus(target: target)
    }

    public func focusTab(id: String) throws {
        try client.focusTab(id: id)
    }

    public func focusPane(id: String) throws {
        try client.focusPane(id: id)
    }

    private func refresh() {
        if stopped || refreshPending { return }
        refreshPending = true
        do {
            let agents = SessionTimeCache.shared.enrich(
                GitBranchCache.shared.enrich(try client.listAgents())
            )
            refreshPending = false
            reconnectDelay = 1
            reconnectWork?.cancel()
            snapshot = SessionSnapshot(name: name, socketPath: socketPath, agents: agents, online: true)
            emit()
            rebuildSubscription()
        } catch {
            refreshPending = false
            scheduleReconnect()
        }
    }

    private func rebuildSubscription() {
        let key = HerdrLogic.paneKey(of: snapshot.agents)
        if subscription != nil, key == subscribedPaneKey { return }
        subscribedPaneKey = key
        subscription?.cancel()
        let agents = snapshot.agents
        subscription = client.subscribe(
            agents: agents,
            onEvent: { [weak self] in
                guard let self else { return }
                self.queue.async { self.refresh() }
            },
            onError: { [weak self] _ in
                guard let self else { return }
                self.queue.async {
                    self.subscription?.cancel()
                    self.subscription = nil
                    self.subscribedPaneKey = ""
                    if self.snapshot.online {
                        self.queue.asyncAfter(deadline: .now() + 1) { self.rebuildSubscription() }
                    }
                }
            }
        )
    }

    private func scheduleReconnect() {
        subscription?.cancel()
        subscription = nil
        subscribedPaneKey = ""
        snapshot = SessionSnapshot(name: name, socketPath: socketPath, agents: [], online: false)
        emit()
        reconnectWork?.cancel()
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 30)
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        reconnectWork = work
        queue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func emit() {
        let copy = snapshot
        DispatchQueue.main.async { self.onChange(copy) }
    }
}
