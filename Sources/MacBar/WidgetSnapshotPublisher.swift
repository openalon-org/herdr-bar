import Combine
import Foundation
import HerdrCore
import WidgetKit

/// Extra → disk → WidgetKit. Debounced so a burst of `agent.list` does not hammer the file.
@MainActor
final class WidgetSnapshotPublisher {
    private let store: AgentAggregator
    private let hideIdle: () -> Bool
    private let path: String
    private var work: DispatchWorkItem?
    private var cancellables: Set<AnyCancellable> = []
    private static let delay: TimeInterval = 0.25

    init(
        store: AgentAggregator,
        hideIdle: @escaping () -> Bool = { AppPreferences.shared.hidesIdle },
        path: String = WidgetSnapshot.path
    ) {
        self.store = store
        self.hideIdle = hideIdle
        self.path = path
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.schedule() }
            .store(in: &cancellables)
    }

    func start() {
        publish()
    }

    func stop() {
        work?.cancel()
        work = nil
    }

    func schedule() {
        work?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.publish()
        }
        work = item
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.delay, execute: item)
    }

    private func publish() {
        let snap = WidgetSnapshot.make(
            agents: store.agents,
            anyOnline: store.anyOnline,
            hideIdle: hideIdle(),
            sessionNames: store.onlineSessionNames,
            home: FileManager.default.homeDirectoryForCurrentUser.path
        )
        do {
            try snap.write(to: path)
            try snap.write(to: WidgetSnapshot.widgetContainerPath)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        } catch {
            // Widget stays on the last good file. Extra glance is unaffected.
        }
    }
}
