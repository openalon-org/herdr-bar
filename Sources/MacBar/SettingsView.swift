import AppKit
import HerdrCore
import SwiftUI

/// Color and keyboard settings live behind the header gear, not in the agent list.
struct SettingsView: View {
    var onBack: () -> Void
    @State private var revision = 0
    @State private var headerTick = 0

    var body: some View {
        let _ = headerTick
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                        Text("Agents")
                            .font(.body.weight(.semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Back to agents")
                Spacer()
                if StatusPalette.shared.hasOverrides {
                    Button("Reset") {
                        StatusPalette.shared.resetAll()
                        revision += 1
                        headerTick += 1
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption.weight(.semibold))
                    .help("Restore Claude Code tab colors")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            // Same gutter as the agent list: overlay scroller on the trailing
            // edge, groups inset so the thumb does not sit on the color wells.
            SteadyScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsGroup(
                        title: "Status colors",
                        footer: "Claude Code’s tab palette. Click a well to override one status."
                    ) {
                        ForEach(Array(AgentStatus.order.enumerated()), id: \.element) { index, status in
                            ColorRow(status: status, onChange: { headerTick += 1 })
                                .id("\(status.rawValue)-\(revision)")
                            if index < AgentStatus.order.count - 1 {
                                SettingsDivider(leading: 32)
                            }
                        }
                    }

                    HotkeySection()
                }
                .padding(.leading, 16)
                .padding(.trailing, 14)
                .padding(.bottom, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )
            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }
}

private struct SettingsDivider: View {
    var leading: CGFloat = 12

    var body: some View {
        Divider()
            .padding(.leading, leading)
            .opacity(0.7)
    }
}

private struct HotkeySection: View {
    @StateObject private var recorder = HotkeyRecorder()

    var body: some View {
        SettingsGroup(title: "Keyboard", footer: footer) {
            HStack(spacing: 10) {
                Text("Open dashboard")
                    .font(.body)
                Spacer(minLength: 8)
                Button {
                    recorder.toggle()
                } label: {
                    Text(recorder.recording ? "Press keys…" : currentLabel)
                        .font(.callout.monospaced())
                        .foregroundStyle(recorder.recording ? Color.primary : Color.primary.opacity(0.9))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(ShortcutWell(active: recorder.recording))
                }
                .buttonStyle(.plain)
                .help("Click, then hold ⌘, ⌥, or ⌃ and a key")
                if AppPreferences.shared.dashboardHotkey != nil, !recorder.recording {
                    Button("Clear") { recorder.clear() }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            SettingsDivider()

            ShortcutHintRow(title: "Move selection", keys: ["↑", "↓"])
            SettingsDivider()
            ShortcutHintRow(title: "Session or folder", keys: ["←", "→"])
            SettingsDivider()
            ShortcutHintRow(title: "Focus pane", keys: ["↩"])
        }
        .onDisappear { recorder.stop() }
    }

    private var currentLabel: String {
        AppPreferences.shared.dashboardHotkey?.display ?? "None"
    }

    private var footer: String {
        if recorder.failed {
            return "That shortcut is already taken. Try another."
        }
        return "Opener is system-wide. Arrows and Return work while this window is open."
    }
}

private struct ShortcutHintRow: View {
    let title: String
    let keys: [String]

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.body)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(keys.joined(separator: "  "))
                .font(.callout.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(keys.joined(separator: " "))")
    }
}

/// Inset control chrome — reads as a well you can press, unlike the hint glyphs.
private struct ShortcutWell: View {
    var active: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.primary.opacity(active ? 0.14 : 0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.primary.opacity(active ? 0.38 : 0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(active ? 0.18 : 0.12), radius: 0, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.5)
                    .padding(0.5)
                    .blendMode(.plusLighter)
            )
    }
}

@MainActor
private final class HotkeyRecorder: ObservableObject {
    @Published var recording = false
    @Published var failed = false
    private var monitor: Any?

    func toggle() {
        if recording { stop() } else { start() }
    }

    func start() {
        stop()
        failed = false
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        recording = false
    }

    func clear() {
        AppPreferences.shared.setDashboardHotkey(nil)
        HotkeyCenter.shared.unregister()
        failed = false
        objectWillChange.send()
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.isARepeat { return nil }
        if event.keyCode == 53 {
            stop()
            return nil
        }
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = modifiers.contains(.command)
        let option = modifiers.contains(.option)
        let control = modifiers.contains(.control)
        let shift = modifiers.contains(.shift)
        guard command || option || control else { return nil }
        let spec = HotkeySpec(
            keyCode: UInt32(event.keyCode),
            command: command,
            option: option,
            control: control,
            shift: shift
        )
        stop()
        let ok = HotkeyCenter.shared.register(spec)
        failed = !ok
        AppPreferences.shared.setDashboardHotkey(ok ? spec : nil)
        if !ok { HotkeyCenter.shared.unregister() }
        objectWillChange.send()
        return nil
    }
}

private struct ColorRow: View {
    let status: AgentStatus
    var onChange: () -> Void
    @State private var color: Color
    @State private var ready = false

    init(status: AgentStatus, onChange: @escaping () -> Void) {
        self.status = status
        self.onChange = onChange
        _color = State(initialValue: Color(hex: status.hexColor))
    }

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(status.label)
                .font(.body)
            Spacer(minLength: 8)
            if StatusPalette.shared.isOverridden(status) {
                Text("Custom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ColorPicker("", selection: $color, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 36, height: 22)
                .onChange(of: color) { newValue in
                    guard ready, let hex = newValue.hexString, hex != status.hexColor else { return }
                    StatusPalette.shared.set(status, hex: hex)
                    onChange()
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            DispatchQueue.main.async { ready = true }
        }
    }
}

extension Color {
    var hexString: String? {
        let ns = NSColor(self)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return nil }
        let r = Int((rgb.redComponent * 255).rounded())
        let g = Int((rgb.greenComponent * 255).rounded())
        let b = Int((rgb.blueComponent * 255).rounded())
        return String(
            format: "#%02X%02X%02X",
            max(0, min(255, r)),
            max(0, min(255, g)),
            max(0, min(255, b))
        )
    }
}
