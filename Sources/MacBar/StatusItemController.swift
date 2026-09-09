import AppKit
import Combine
import HerdrCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let item: NSStatusItem
    private let popover = NSPopover()
    private let store = AgentAggregator()
    private let chrome = PopoverChrome()
    private let manager: SessionManager
    private var snapshotPublisher: WidgetSnapshotPublisher?
    private var pendingFocus: (session: String, pane: String)?
    private var buttonView: StatusItemView?
    /// Our own latch. `NSPopover.isShown` lags during activate / close animation,
    /// so a second hotkey in that window looks like another "open" and is dropped.
    private var presented = false
    private var openToken = 0
    private var lastToggleAt = Date.distantPast
    private static let toggleCooldown: TimeInterval = 0.16
    /// Settings uses `.applicationDefined` so NSColorPanel does not dismiss us.
    /// These monitors restore click-outside-to-close for that mode.
    private var outsideClickMonitors: [Any] = []

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        manager = SessionManager(store: store)
        super.init()

        popover.behavior = .transient
        popover.animates = false
        popover.contentSize = DashboardLayout.size
        popover.delegate = self
        let hosting = NSHostingController(
            rootView: DashboardView(
                store: store,
                chrome: chrome,
                onFocus: { [weak self] agent in
                    self?.focus(agent)
                },
                onFocusPriority: { [weak self] in
                    self?.focusPriority()
                },
                onClose: { [weak self] in
                    self?.closePopover()
                }
            )
        )
        hosting.sizingOptions = []
        hosting.preferredContentSize = DashboardLayout.size
        popover.contentViewController = hosting

        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            // Empty title/image so NSStatusBarButton still owns the Tahoe
            // press capsule. StatusItemView only paints marks on top.
            button.title = ""
            button.image = nil
            button.wantsLayer = false
            let view = StatusItemView(frame: .zero)
            view.translatesAutoresizingMaskIntoConstraints = false
            view.wantsLayer = false
            button.addSubview(view)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                view.topAnchor.constraint(equalTo: button.topAnchor),
                view.bottomAnchor.constraint(equalTo: button.bottomAnchor),
            ])
            buttonView = view
        }

        HotkeyCenter.shared.onPressed = { [weak self] in
            self?.togglePopover()
        }
        HotkeyCenter.shared.apply(AppPreferences.shared.dashboardHotkey)

        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (_: Void) in
                self?.render()
                self?.flushPendingFocus()
            }
            .store(in: &cancellables)

        // ColorPicker opens NSColorPanel, which dismisses a transient popover.
        // Stay applicationDefined in settings, and close ourselves on a click
        // that is not in the popover, the status item, or the color panel.
        chrome.$showingSettings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] showing in
                self?.applySettingsChrome(showing)
            }
            .store(in: &cancellables)

        chrome.$hideIdle
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.snapshotPublisher?.schedule()
            }
            .store(in: &cancellables)
    }

    private var cancellables: Set<AnyCancellable> = []

    func start() {
        manager.start()
        let publisher = WidgetSnapshotPublisher(store: store)
        snapshotPublisher = publisher
        publisher.start()
        render()
        flushPendingFocus()
    }

    func stop() {
        HotkeyCenter.shared.unregister()
        stopOutsideClickDismiss()
        snapshotPublisher?.stop()
        manager.stop()
    }

    func handleURL(_ url: URL) {
        guard let link = WidgetSnapshot.parseURL(url) else { return }
        if let session = link.session, let pane = link.paneId, link.focusesRow {
            pendingFocus = (session, pane)
            flushPendingFocus()
            return
        }
        openPopover()
    }

    private func applySettingsChrome(_ showing: Bool) {
        popover.behavior = showing ? .applicationDefined : .transient
        if showing {
            startOutsideClickDismiss()
        } else {
            stopOutsideClickDismiss()
            NSColorPanel.shared.close()
        }
    }

    private func startOutsideClickDismiss() {
        stopOutsideClickDismiss()
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.closeIfClickOutside(event)
        }) {
            outsideClickMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.closeIfClickOutside(event)
            return event
        }) {
            outsideClickMonitors.append(local)
        }
    }

    private func stopOutsideClickDismiss() {
        for monitor in outsideClickMonitors {
            NSEvent.removeMonitor(monitor)
        }
        outsideClickMonitors.removeAll()
    }

    private func closeIfClickOutside(_ event: NSEvent) {
        let work = { [weak self] in
            guard let self, self.presented, self.chrome.showingSettings else { return }
            guard !self.clickIsInsideProtectedChrome() else { return }
            self.closePopover(animated: false)
        }
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async { work() }
        }
        _ = event
    }

    /// Status item, dashboard, color panel, and its menus stay; everything else closes.
    private func clickIsInsideProtectedChrome() -> Bool {
        let point = NSEvent.mouseLocation
        if let button = item.button, let window = button.window {
            let rect = window.convertToScreen(button.convert(button.bounds, to: nil))
            if rect.contains(point) { return true }
        }
        for window in NSApp.windows where window.isVisible {
            guard window.frame.contains(point) else { continue }
            if window === popover.contentViewController?.view.window { return true }
            if window is NSColorPanel { return true }
            let name = window.className
            if name.contains("NSColor") || name.contains("NSMenu") { return true }
            if window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue { return true }
        }
        return false
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            manager.refreshAll()
            return
        }
        if event.modifierFlags.contains(.option) {
            focusPriority()
            return
        }
        togglePopover()
    }

    private func togglePopover() {
        let now = Date()
        guard now.timeIntervalSince(lastToggleAt) >= Self.toggleCooldown else { return }
        lastToggleAt = now
        if presented {
            closePopover(animated: false)
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = item.button else { return }
        presented = true
        openToken += 1
        let token = openToken
        popover.behavior = .applicationDefined
        let show: () -> Void = { [weak self] in
            guard let self, self.presented, token == self.openToken else { return }
            self.popover.contentSize = DashboardLayout.size
            self.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            self.popover.contentSize = DashboardLayout.size
            self.chrome.openTick += 1
            DispatchQueue.main.async { [weak self] in
                guard let self, token == self.openToken else { return }
                if !self.chrome.showingSettings {
                    self.popover.behavior = .transient
                }
            }
        }
        if NSApp.isActive {
            show()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { show() }
        }
    }

    private func closePopover(animated: Bool = false) {
        openToken += 1
        presented = false
        guard popover.isShown else { return }
        let previous = popover.animates
        popover.animates = animated
        popover.performClose(nil)
        popover.animates = previous
    }

    private func focus(_ agent: Agent) {
        closePopover(animated: false)
        do {
            try manager.focus(agent)
        } catch {
            NSSound.beep()
        }
    }

    private func focusPriority() {
        closePopover(animated: false)
        do {
            try manager.focusAttention()
        } catch {
            NSSound.beep()
        }
    }

    private func flushPendingFocus() {
        guard let pending = pendingFocus else { return }
        let match = store.agents.first {
            $0.sessionName == pending.session && $0.paneId == pending.pane
        }
        guard let match else { return }
        pendingFocus = nil
        focus(match)
    }

    private func render() {
        let counts = store.counts
        let width = MenuBarGlance.preferredWidth(counts: counts, online: store.anyOnline)
        item.length = width
        item.button?.layoutSubtreeIfNeeded()
        buttonView?.update(counts: counts, online: store.anyOnline)
        // Native NSStatusItem.toolTip is a second, unstyled hover card. The
        // popover already shows the same agents, so leave the bar quiet.
        item.button?.toolTip = nil
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        presented = false
        chrome.showingSettings = false
        chrome.session = nil
        chrome.selectedID = nil
        stopOutsideClickDismiss()
        popover.behavior = .transient
        NSColorPanel.shared.close()
    }
}
