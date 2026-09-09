import AppKit
import HerdrCore
import SwiftUI

/// Fixed dashboard chrome. The eye filters the list; the popover itself
/// stays this size so hiding idle cannot shrink the window and refuse to
/// grow back (NSPopover keeps the last measured height).
enum DashboardLayout {
    static let size = CGSize(width: 372, height: 480)
}

/// Popover chrome that lives outside `@State` so closing the popover can
/// pop settings without remounting the dashboard.
/// pop settings without remounting the dashboard.
@MainActor
final class PopoverChrome: ObservableObject {
    @Published var showingSettings = false
    /// Optional session scope. Folders and statuses live in the list, not as extra chips.
    @Published var session: String?
    /// Notification mode: hide idle rows. Default on; persisted in herdr-bar.json.
    @Published var hideIdle: Bool = AppPreferences.shared.hidesIdle
    /// Keyboard highlight in the current filter. Nil until the popover seeds it.
    @Published var selectedID: String?
    /// Bumped each time the popover opens so the list can re-seed the highlight.
    @Published var openTick = 0
}

/// Keyboard-only reveal. Mouse fling must not be yanked to the selected row.
private struct ScrollRequest: Equatable {
    var id: String
    var nonce: UInt
}

struct DashboardView: View {
    @ObservedObject var store: AgentAggregator
    @ObservedObject var chrome: PopoverChrome
    var onFocus: (Agent) -> Void
    var onFocusPriority: () -> Void
    var onClose: () -> Void
    @State private var scrollRequest: ScrollRequest?

    private var home: String {
        FileManager.default.homeDirectoryForCurrentUser.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if chrome.showingSettings {
                SettingsView(onBack: { chrome.showingSettings = false })
            } else {
                agentDashboard
            }
        }
        .padding(.vertical, 12)
        .frame(width: DashboardLayout.size.width, height: DashboardLayout.size.height, alignment: .topLeading)
        .onExitCommand(perform: handleEscape)
        .background(
            KeyboardCatcher(
                onReturn: handleReturn,
                onEscape: handleEscape,
                onArrow: handleArrow,
                captureArrows: !chrome.showingSettings
            )
        )
    }

    private var agentDashboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
                .padding(.horizontal, 16)
            if store.anyOnline && !store.agents.isEmpty {
                scopeRow
                    .padding(.horizontal, 16)
                if displayedGroups.isEmpty {
                    Spacer(minLength: 0)
                    filterEmpty
                        .padding(.horizontal, 16)
                    Spacer(minLength: 0)
                } else {
                    agentList
                }
            } else if store.anyOnline {
                Spacer()
                emptyState
                    .padding(.horizontal, 16)
                Spacer()
            } else {
                Spacer()
                offlineState
                    .padding(.horizontal, 16)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: store.agents) { _ in
            pruneSession()
            syncSelection()
        }
        .onChange(of: chrome.hideIdle) { _ in syncSelection() }
        .onChange(of: chrome.session) { _ in syncSelection() }
        .onChange(of: chrome.openTick) { _ in
            syncSelection()
            revealSelection()
        }
        .onAppear { syncSelection() }
    }

    private var scopedAgents: [Agent] {
        HerdrLogic.filtered(store.agents, by: AgentFilter(session: chrome.session))
    }

    private var groups: [AgentGroup] { HerdrLogic.grouped(scopedAgents) }

    /// Groups that still have a row after notification-mode idle hiding.
    private var displayedGroups: [AgentGroup] {
        groups.filter { !HerdrLogic.visibleAgents(in: $0, hideIdle: chrome.hideIdle).isEmpty }
    }

    private var showSessionOnRow: Bool {
        store.multipleSessionsOnline && chrome.session == nil
    }

    private func handleEscape() {
        if chrome.showingSettings {
            chrome.showingSettings = false
        } else {
            onClose()
        }
    }

    private func handleReturn() {
        guard !chrome.showingSettings else { return }
        if let agent = selectedAgent {
            onFocus(agent)
            return
        }
        onFocusPriority()
    }

    private func handleArrow(_ keyCode: UInt16) {
        guard !chrome.showingSettings, store.anyOnline else { return }
        switch keyCode {
        case 126: moveRow(-1)
        case 125: moveRow(1)
        case 123: moveFilter(-1)
        case 124: moveFilter(1)
        default: break
        }
    }

    private func moveRow(_ delta: Int) {
        chrome.selectedID = DashboardNav.stepRow(
            groups: displayedGroups,
            hideIdle: chrome.hideIdle,
            selected: chrome.selectedID,
            by: delta
        )
        revealSelection()
    }

    private func moveFilter(_ delta: Int) {
        if store.multipleSessionsOnline {
            selectSession(
                DashboardNav.stepSession(
                    current: chrome.session,
                    online: store.onlineSessionNames,
                    by: delta
                )
            )
            DispatchQueue.main.async { revealSelection() }
            return
        }
        chrome.selectedID = DashboardNav.stepGroup(
            groups: displayedGroups,
            hideIdle: chrome.hideIdle,
            selected: chrome.selectedID,
            by: delta
        )
        revealSelection()
    }

    private func revealSelection() {
        guard let id = chrome.selectedID else { return }
        scrollRequest = ScrollRequest(id: id, nonce: (scrollRequest?.nonce ?? 0) &+ 1)
    }

    private var selectedAgent: Agent? {
        guard let id = chrome.selectedID else { return nil }
        return scopedAgents.first { $0.id == id }
    }

    private func syncSelection() {
        chrome.selectedID = DashboardNav.clampSelection(
            groups: displayedGroups,
            hideIdle: chrome.hideIdle,
            selected: chrome.selectedID,
            preferred: HerdrLogic.attentionAgent(in: scopedAgents)?.id
        )
    }

    private func pruneSession() {
        if let session = chrome.session, !store.onlineSessionNames.contains(session) {
            chrome.session = nil
        }
    }

    private func selectSession(_ name: String?) {
        chrome.session = name
    }

    private var header: some View {
        HStack(spacing: 10) {
            BrandMark(style: .chrome, opacity: store.anyOnline ? 1 : 0.45)
            VStack(alignment: .leading, spacing: 2) {
                Text("Herdr")
                    .font(.headline)
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                chrome.hideIdle.toggle()
                AppPreferences.shared.setHidesIdle(chrome.hideIdle)
            } label: {
                Image(systemName: chrome.hideIdle ? "eye.slash" : "eye")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(chrome.hideIdle ? "Show idle agents" : "Hide idle agents")
            Button {
                chrome.showingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Colors and keyboard")
        }
    }

    private var meta: String {
        if !store.anyOnline {
            return "Waiting for the Herdr socket"
        }
        let scoped = scopedAgents.count
        let total = store.agents.count
        if let session = chrome.session {
            return "\(session) · \(scoped) of \(total)"
        }
        return "\(total) active coding agent\(total == 1 ? "" : "s")"
    }

    /// Session scope + status summary on one row. All is selected by default.
    private var scopeRow: some View {
        HStack(spacing: 5) {
            if store.multipleSessionsOnline {
                sessionChip(title: "All", selected: chrome.session == nil, help: "Every session") {
                    selectSession(nil)
                }
                ForEach(store.onlineSessionNames, id: \.self) { name in
                    sessionChip(title: name, selected: chrome.session == name, help: "Only \(name)") {
                        selectSession(name)
                    }
                }
            }
            Spacer(minLength: 4)
            ForEach(AgentStatus.order, id: \.self) { status in
                let count = HerdrLogic.counts(of: scopedAgents)[status] ?? 0
                if count > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: status.symbolName)
                            .font(.caption2.weight(.semibold))
                            .imageScale(.small)
                        Text("\(count)")
                            .font(.caption2.bold())
                    }
                    .foregroundStyle(Color(hex: status.hexColor))
                    .id(status.hexColor)
                }
            }
        }
    }

    private func sessionChip(title: String, selected: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .foregroundStyle(selected ? Color.primary : Color.secondary)
                .background(
                    Capsule().fill(Color.primary.opacity(selected ? 0.12 : 0.045))
                )
                .overlay(
                    Capsule().stroke(Color.primary.opacity(selected ? 0.35 : 0.12), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var filterEmpty: some View {
        Text(emptyCopy)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    private var emptyCopy: String {
        if chrome.session != nil, scopedAgents.isEmpty {
            return "Nothing in this session."
        }
        if chrome.hideIdle {
            return "Nothing needs you. The eye shows idle agents."
        }
        return "Nothing in this session."
    }

    private var agentList: some View {
        // Overlay scroller sits on the trailing edge. Inset the cards so the
        // thumb lives in a gutter beside them, not on Idle labels.
        SteadyScrollView(scrollToID: scrollRequest?.id, scrollNonce: scrollRequest?.nonce ?? 0) {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(displayedGroups) { group in
                    let rows = HerdrLogic.visibleAgents(in: group, hideIdle: chrome.hideIdle)
                    let hidden = HerdrLogic.hiddenIdleCount(in: group, hideIdle: chrome.hideIdle)
                    VStack(alignment: .leading, spacing: 4) {
                        GroupHeader(
                            title: HerdrLogic.groupHeader(for: group),
                            count: rows.count,
                            hiddenIdle: hidden
                        )
                        VStack(spacing: 5) {
                            ForEach(rows) { agent in
                                Button {
                                    chrome.selectedID = agent.id
                                    onFocus(agent)
                                } label: {
                                    AgentRow(
                                        agent: agent,
                                        among: store.sortedAgents,
                                        showSession: showSessionOnRow,
                                        showFolder: false,
                                        home: home,
                                        selected: chrome.selectedID == agent.id
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(agent.id)
                            }
                        }
                    }
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("All quiet.")
                .font(.title3.bold())
            Text("Agents appear here as soon as Herdr detects them.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var offlineState: some View {
        Text("Start Herdr to reconnect automatically.")
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
    }
}

private struct GroupHeader: View {
    let title: String
    let count: Int
    var hiddenIdle: Int = 0

    var body: some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary.opacity(0.65))
            if hiddenIdle > 0 {
                Text("+\(hiddenIdle)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary.opacity(0.45))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AgentRow: View {
    let agent: Agent
    let among: [Agent]
    let showSession: Bool
    var showFolder: Bool = true
    let home: String
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            leadingMark
                .frame(width: 14, alignment: .center)
            VStack(alignment: .leading, spacing: 3) {
                Text(HerdrLogic.agentLabel(agent, maxLength: 40))
                    .font(.body.bold())
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(agent.status.label)
                .font(.caption.bold())
                .foregroundStyle(Color(hex: agent.status.hexColor))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(selected ? 0.10 : 0.045))
        )
        .overlay {
            if agent.status.needsAttention {
                AttentionHalo(color: Color(hex: agent.status.hexColor))
            }
            if selected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.28), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leadingMark: some View {
        if agent.status == .working {
            WorkingFlower(color: Color(hex: agent.status.hexColor))
        } else {
            StatusFlower(glyph: WorkingSpinner.restGlyph, color: Color(hex: agent.status.hexColor))
        }
    }

    private var subtitle: String {
        HerdrLogic.subtitle(
            for: agent,
            among: among,
            home: home,
            showSession: showSession,
            showFolder: showFolder
        )
    }
}

/// Parked Claude flower. Same slot as the working spinner so idle rows line up.
private struct StatusFlower: View {
    var glyph: String
    var color: Color

    var body: some View {
        Text(glyph)
            .font(.system(size: 13, weight: .medium, design: .default))
            .foregroundStyle(color)
            .frame(width: 14, alignment: .center)
            .accessibilityHidden(true)
    }
}

/// Claude Code 2.1.263 Darwin spinner: `·✢✳✶✻✽` ping-pong, 120ms per frame.
private struct WorkingFlower: View {
    var color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: WorkingSpinner.frameDuration)) { timeline in
            StatusFlower(glyph: WorkingSpinner.frame(at: timeline.date), color: color)
        }
    }
}

/// Same 1.6s sine breath as the menu-bar attention halo, drawn around the card.
private struct AttentionHalo: View {
    var color: Color
    var cornerRadius: CGFloat = 8

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = (sin(timeline.date.timeIntervalSinceReferenceDate * (.pi * 2 / 1.6)) + 1) * 0.5
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color.opacity(0.30 + 0.60 * t), lineWidth: 1.2 + 0.8 * t)
                .shadow(color: color.opacity(0.18 + 0.42 * t), radius: 3 + 5 * t)
        }
        .allowsHitTesting(false)
    }
}

private struct KeyboardCatcher: NSViewRepresentable {
    var onReturn: () -> Void
    var onEscape: () -> Void
    var onArrow: (UInt16) -> Void
    var captureArrows: Bool = true

    func makeNSView(context: Context) -> NSView {
        let view = CatcherView()
        view.onReturn = onReturn
        view.onEscape = onEscape
        view.onArrow = onArrow
        view.captureArrows = captureArrows
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let view = nsView as? CatcherView {
            view.onReturn = onReturn
            view.onEscape = onEscape
            view.onArrow = onArrow
            view.captureArrows = captureArrows
            if captureArrows, view.window?.firstResponder !== view {
                view.window?.makeFirstResponder(view)
            }
        }
    }

    final class CatcherView: NSView {
        var onReturn: (() -> Void)?
        var onEscape: (() -> Void)?
        var onArrow: ((UInt16) -> Void)?
        var captureArrows = true

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 36, 76: onReturn?()
            case 53: onEscape?()
            case 123, 124, 125, 126:
                if captureArrows { onArrow?(event.keyCode) }
                else { super.keyDown(with: event) }
            default: super.keyDown(with: event)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        var int: UInt64 = 0
        Scanner(string: value).scanHexInt64(&int)
        self.init(
            .sRGB,
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255,
            opacity: 1
        )
    }
}
