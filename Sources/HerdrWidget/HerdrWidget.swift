import HerdrCore
import SwiftUI
import WidgetKit

@main
struct HerdrWidgetBundle: WidgetBundle {
    var body: some Widget {
        HerdrDashboardWidget()
    }
}

struct HerdrDashboardWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.widgetKind, provider: Provider()) { entry in
            DashboardWidgetView(entry: entry)
        }
        .configurationDisplayName("Herdr")
        .description("The extra’s agent list on the desktop. Tap a row to focus that pane.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snapshot: WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: Date(), snapshot: WidgetSnapshot.load())
        let next = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct DashboardWidgetView: View {
    var entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        // WidgetKit optically centers a shorter ideal-height root.
        GeometryReader { geo in
            Group {
                if let snap = entry.snapshot {
                    live(snap)
                } else {
                    placeholder("Open HerdrBar", detail: "The extra writes this list.")
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .widgetURL(WidgetSnapshot.openURL())
        .widgetSurface()
    }

    @ViewBuilder
    private func live(_ snap: WidgetSnapshot) -> some View {
        if !snap.anyOnline {
            placeholder("Start Herdr", detail: "The extra reconnects on its own.")
        } else if snap.rows.isEmpty {
            placeholder("Nothing needs you", detail: snap.hideIdle ? "Idle agents stay in the extra." : "No agents yet.")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                header(snap)
                rows(snap)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private func header(_ snap: WidgetSnapshot) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Herdr")
                .font(.headline)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                ForEach(AgentStatus.order, id: \.self) { status in
                    let count = snap.counts[status.rawValue] ?? 0
                    if count > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: status.symbolName)
                                .font(.caption2)
                            Text("\(count)")
                                .font(.caption.monospacedDigit().weight(.medium))
                        }
                        .foregroundStyle(status.widgetColor)
                    }
                }
            }
        }
        .foregroundStyle(.primary)
    }

    private func rows(_ snap: WidgetSnapshot) -> some View {
        let budget = family == .systemLarge ? 10 : 4
        var remaining = budget
        return VStack(alignment: .leading, spacing: 10) {
            ForEach(visible(snap.groups, budget: &remaining), id: \.folder) { group in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(group.folder.uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(0.4)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("\(group.rows.count)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        if group.hiddenIdle > 0 {
                            Text("+\(group.hiddenIdle)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.quaternary)
                        }
                    }
                    ForEach(group.rows) { row in
                        Link(destination: WidgetSnapshot.focusURL(session: row.session, pane: row.paneId)) {
                            rowView(row)
                        }
                    }
                }
            }
        }
    }

    private func rowView(_ row: WidgetSnapshot.Row) -> some View {
        let ink = row.status.widgetColor
        return HStack(spacing: 8) {
            Text(WorkingSpinner.restGlyph)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ink)
                .frame(width: 14, alignment: .center)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                if !row.subtitle.isEmpty {
                    Text(row.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text(row.status.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(ink.opacity(0.14))
        )
        .overlay {
            if row.status.needsAttention {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ink.opacity(0.45), lineWidth: 1)
            }
        }
    }

    private func placeholder(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Herdr")
                .font(.headline)
            Text(title)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private func visible(_ groups: [WidgetSnapshot.Group], budget: inout Int) -> [WidgetSnapshot.Group] {
        var out: [WidgetSnapshot.Group] = []
        for group in groups {
            guard budget > 0 else { break }
            let take = Array(group.rows.prefix(budget))
            budget -= take.count
            out.append(WidgetSnapshot.Group(folder: group.folder, hiddenIdle: group.hiddenIdle, rows: take))
        }
        return out
    }
}

private extension View {
    /// WidgetKit warns without a container background. Tahoe still draws glass.
    @ViewBuilder
    func widgetSurface() -> some View {
        if #available(macOS 14.0, *) {
            containerBackground(.clear, for: .widget)
        } else {
            self
        }
    }
}

private extension AgentStatus {
    /// Literal RGB — WidgetKit often drops `Color(hex:)` Scanner colors to white.
    var widgetColor: Color {
        switch self {
        case .blocked: Color(red: 0.373, green: 0.529, blue: 1.0)
        case .done:    Color(red: 0.0, green: 0.843, blue: 0.373)
        case .working: Color(red: 0.812, green: 0.463, blue: 0.314)
        case .unknown: Color(red: 0.780, green: 0.639, blue: 0.353)
        case .idle:    Color(red: 0.533, green: 0.533, blue: 0.533)
        }
    }
}
