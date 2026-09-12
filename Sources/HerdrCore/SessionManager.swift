import Darwin
import Foundation

/// Discovers herdr sockets and keeps one `SessionWatcher` per live session.
@MainActor
public final class SessionManager {
    public let store: AgentAggregator
    private var watchers: [String: SessionWatcher] = [:]
    private var directoryMonitors: [DispatchSourceFileSystemObject] = []
    private var directoryFDs: [Int32] = []
    private var pollWork: DispatchWorkItem?
    private let home: String

    public init(store: AgentAggregator, home: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        self.store = store
        self.home = home
    }

    public func start() {
        StatusPalette.shared.startWatching { [weak self] in
            self?.store.objectWillChange.send()
        }
        reconcile()
        startDirectoryWatch()
    }

    public func stop() {
        StatusPalette.shared.stopWatching()
        pollWork?.cancel()
        directoryMonitors.forEach { $0.cancel() }
        directoryMonitors.removeAll()
        for fd in directoryFDs where fd >= 0 { Darwin.close(fd) }
        directoryFDs.removeAll()
        for watcher in watchers.values { watcher.stop() }
        watchers.removeAll()
    }

    public func refreshAll() {
        for watcher in watchers.values { watcher.refreshNow() }
        reconcile()
    }

    public func focus(_ agent: Agent) throws {
        guard let watcher = watchers[agent.sessionName] else {
            throw HerdrClient.ClientError.disconnected
        }
        // RPC first: Herdr 0.9 keeps TUI workspace/tab per client. Extra is an
        // API socket, so `agent.focus` often only marks seen. `tab.focus` /
        // `pane.focus` move the attached TUI. Raise after that so
        // `activateAllWindows` cannot cover a tab that has not switched yet.
        try watcher.focus(target: agent.target)
        // 0.9 follow-up: missing methods on 0.8 must not abort the raise.
        if let tabId = agent.tabId, !tabId.isEmpty {
            try? watcher.focusTab(id: tabId)
        }
        try? watcher.focusPane(id: agent.paneId)
        FocusRaiser.raiseHost(sessionName: watcher.name, socketPath: watcher.socketPath)
    }

    public func focusAttention() throws {
        guard let agent = store.attentionAgent else { return }
        try focus(agent)
    }

    /// Raise the TUI host for a named herdr session without focusing a pane.
    public func raiseSession(_ name: String) throws {
        guard let watcher = watchers[name] else {
            throw HerdrClient.ClientError.disconnected
        }
        FocusRaiser.raiseHost(sessionName: watcher.name, socketPath: watcher.socketPath)
    }

    private func reconcile() {
        let discovered = SessionDiscovery.discover(home: home)
        let discoveredNames = Set(discovered.map(\.name))

        for session in discovered where watchers[session.name] == nil {
            let watcher = SessionWatcher(name: session.name, socketPath: session.socketPath) { [weak self] snapshot in
                Task { @MainActor in
                    self?.store.apply(snapshot)
                }
            }
            watchers[session.name] = watcher
            watcher.start()
            FocusRaiser.warm(sessionName: session.name, socketPath: session.socketPath)
        }

        for name in watchers.keys where !discoveredNames.contains(name) {
            watchers[name]?.stop()
            watchers.removeValue(forKey: name)
            FocusRaiser.forget(sessionName: name)
            store.removeSession(named: name)
        }
    }

    /// Watch Herdr config dirs for sockets appearing/disappearing.
    /// This is filesystem invalidation, not `agent.list` polling.
    private func startDirectoryWatch() {
        let paths = [
            home + "/.config/herdr",
            home + "/.config/herdr/sessions",
        ]
        var started = false
        for path in paths {
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            directoryFDs.append(fd)
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .delete, .link],
                queue: .main
            )
            source.setEventHandler { [weak self] in
                self?.reconcile()
            }
            source.resume()
            directoryMonitors.append(source)
            started = true
        }
        if !started {
            scheduleReconcileFallback()
        }
    }

    /// If the config dir does not exist yet, retry discovery with reconnect backoff.
    private func scheduleReconcileFallback() {
        pollWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.reconcile()
            if self?.watchers.isEmpty == true {
                self?.scheduleReconcileFallback()
            } else {
                self?.startDirectoryWatch()
            }
        }
        pollWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
}
