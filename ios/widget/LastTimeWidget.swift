import AppIntents
import SwiftUI
import WidgetKit

struct LogLastTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Did it again"
    static var openAppWhenRun = false
    @Parameter(title: "Counter") var itemID: Int
    @Parameter(title: "Occurrence") var eventID: String

    init() {}
    init(itemID: Int, eventID: String) { self.itemID = itemID; self.eventID = eventID }

    func perform() async throws -> some IntentResult {
        try LastTimeStore.log(itemID: itemID, eventID: eventID)
        WidgetCenter.shared.reloadTimelines(ofKind: "com.aayushmau5.bnana.last-time")
        return .result()
    }
}

struct UndoLastTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Undo Last time log"
    static var openAppWhenRun = false
    @Parameter(title: "Counter") var itemID: Int
    @Parameter(title: "Occurrence") var eventID: String

    init() {}
    init(itemID: Int, eventID: String) { self.itemID = itemID; self.eventID = eventID }

    func perform() async throws -> some IntentResult {
        try LastTimeStore.undo(itemID: itemID, eventID: eventID)
        WidgetCenter.shared.reloadTimelines(ofKind: "com.aayushmau5.bnana.last-time")
        return .result()
    }
}

private struct LastTimeEntry: TimelineEntry {
    let date: Date
    let items: [LastTimeItem]
    var error: String? = nil
    let actionID = UUID().uuidString
}

private struct LastTimeProvider: TimelineProvider {
    func placeholder(in context: Context) -> LastTimeEntry {
        LastTimeEntry(date: .now, items: [
            LastTimeItem(id: 1, name: "Watered plants", interval: 7,
                         lastOn: LastTimeStore.dayFormatter.string(from: Calendar.current.date(byAdding: .day, value: -4, to: .now)!),
                         latestEventID: nil, recordedAt: nil)
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (LastTimeEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LastTimeEntry>) -> Void) {
        let entry = load()
        // Precompute calendar-day changes so elapsed labels don't depend on a midnight refresh.
        let midnight = Calendar.current.startOfDay(for: entry.date)
        var entries = [entry]
        for day in 1...7 {
            if let date = Calendar.current.date(byAdding: .day, value: day, to: midnight) {
                entries.append(LastTimeEntry(date: date, items: entry.items, error: entry.error))
            }
        }
        completion(Timeline(entries: entries, policy: .after(entry.date.addingTimeInterval(3600))))
    }

    private func load() -> LastTimeEntry {
        do { return LastTimeEntry(date: .now, items: try LastTimeStore.items()) }
        catch { return LastTimeEntry(date: .now, items: [], error: error.localizedDescription) }
    }
}

private struct LastTimeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LastTimeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LAST TIME")
                .font(.custom("ShareTechMono-Regular", size: 11))
                .tracking(1.3)
                .foregroundStyle(BnanaColor.secondary)
            if entry.items.isEmpty {
                Spacer(minLength: 0)
                Text(entry.error ?? "Pin a few favourites in bnana.")
                    .font(.custom("PlayfairDisplay-Regular", size: 18))
                    .foregroundStyle(BnanaColor.text)
                Text("a little memory for everyday life.")
                    .font(.system(size: 11))
                    .foregroundStyle(BnanaColor.muted)
            } else if family == .systemSmall, let item = entry.items.first {
                smallCard(item)
            } else {
                ForEach(entry.items.prefix(3)) { item in
                    row(item)
                }
            }
            Spacer(minLength: 0)
        }
        .containerBackground(for: .widget) { BnanaColor.surface }
        .widgetURL(URL(string: "bnana://last-time"))
    }

    private func smallCard(_ item: LastTimeItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name)
                .font(.custom("PlayfairDisplay-Regular", size: 20))
                .foregroundStyle(BnanaColor.text)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(item.elapsed(on: entry.date))
                .font(.custom("ShareTechMono-Regular", size: 12))
                .foregroundStyle(item.isDue(on: entry.date) ? BnanaColor.secondary : BnanaColor.muted)
            Spacer(minLength: 0)
            actions(item, showLabel: true)
        }
    }

    private func actions(_ item: LastTimeItem, showLabel: Bool = false) -> some View {
        HStack(spacing: 0) {
            Button(intent: LogLastTimeIntent(itemID: item.id, eventID: "\(entry.actionID)-\(item.id)")) {
                Group {
                    if showLabel {
                        Text("Did it again")
                            .font(.custom("ShareTechMono-Regular", size: 12))
                            .padding(.horizontal, 8)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 32)
                    }
                }
                .frame(height: 32)
                .background(BnanaColor.primary.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .foregroundStyle(BnanaColor.primary)
            .accessibilityLabel("Did it again: \(item.name)")
            if let eventID = item.latestEventID,
               let recorded = item.recordedAt,
               Int64(entry.date.timeIntervalSince1970 * 1_000_000) - recorded < 300_000_000 {
                Button(intent: UndoLastTimeIntent(itemID: item.id, eventID: eventID)) {
                    Image(systemName: "arrow.uturn.backward")
                        .frame(width: 28, height: 32)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .foregroundStyle(BnanaColor.muted)
                .accessibilityLabel("Undo last log for \(item.name)")
            }
        }
    }

    private func row(_ item: LastTimeItem) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name)
                    .font(.custom("PlayfairDisplay-Regular", size: 14))
                    .foregroundStyle(BnanaColor.text)
                    .lineLimit(1)
                Text(item.elapsed(on: entry.date) + (item.isDue(on: entry.date) ? " · due again" : ""))
                    .font(.custom("ShareTechMono-Regular", size: 10))
                    .foregroundStyle(item.isDue(on: entry.date) ? BnanaColor.secondary : BnanaColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
            actions(item)
        }
    }
}

struct LastTimeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.aayushmau5.bnana.last-time", provider: LastTimeProvider()) { entry in
            LastTimeWidgetView(entry: entry)
        }
        .configurationDisplayName("Last time")
        .description("A little memory for everyday life. Pin up to three favourites in bnana.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
