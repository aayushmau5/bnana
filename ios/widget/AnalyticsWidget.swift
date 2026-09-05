import SwiftUI
import WidgetKit

private let appGroup = "group.com.aayushmau5.bnana"
private let widgetKind = "com.aayushmau5.bnana.analytics"

enum BnanaColor {
    static let surface = Color(red: 24 / 255, green: 24 / 255, blue: 24 / 255)
    static let border = Color(red: 47 / 255, green: 54 / 255, blue: 61 / 255)
    static let primary = Color(red: 77 / 255, green: 147 / 255, blue: 117 / 255)
    static let secondary = Color(red: 230 / 255, green: 204 / 255, blue: 119 / 255)
    static let text = Color(red: 219 / 255, green: 215 / 255, blue: 202 / 255)
    static let muted = Color(red: 149 / 255, green: 147 / 255, blue: 140 / 255)
}

private extension Font {
    static func bnanaDisplay(_ size: CGFloat) -> Font {
        .custom("PlayfairDisplay-Regular", size: size)
    }

    static func bnanaMono(_ size: CGFloat) -> Font {
        .custom("ShareTechMono-Regular", size: size)
    }
}

private struct AnalyticsSnapshot: Codable {
    let updatedAt: Date
    let totalViews: Int
    let todayViews: Int
    let dailyViews: [Int]

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case totalViews = "total_views"
        case todayViews = "today_views"
        case dailyViews = "daily_views"
    }
}

private struct AnalyticsEntry: TimelineEntry {
    let date: Date
    let snapshot: AnalyticsSnapshot?
}

private struct AnalyticsProvider: TimelineProvider {
    func placeholder(in context: Context) -> AnalyticsEntry {
        AnalyticsEntry(date: .now, snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (AnalyticsEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<AnalyticsEntry>) -> Void
    ) {
        completion(Timeline(entries: [loadEntry()], policy: .never))
    }

    private func loadEntry() -> AnalyticsEntry {
        guard
            let directory = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: appGroup
            ),
            let data = try? Data(contentsOf: directory.appendingPathComponent("analytics.json"))
        else {
            return AnalyticsEntry(date: .now, snapshot: nil)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return AnalyticsEntry(
            date: .now,
            snapshot: try? decoder.decode(AnalyticsSnapshot.self, from: data)
        )
    }
}

private struct AnalyticsWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: AnalyticsEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium:
                    MediumAnalyticsView(snapshot: snapshot)
                default:
                    SmallAnalyticsView(snapshot: snapshot)
                }
            } else {
                EmptyAnalyticsView()
            }
        }
        .containerBackground(for: .widget) {
            BnanaColor.surface
        }
    }
}

private struct SmallAnalyticsView: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("TOTALS")
                .font(.bnanaMono(11))
                .tracking(1.3)
                .foregroundStyle(BnanaColor.secondary)
            Spacer()
            Text(snapshot.totalViews.formatted())
                .font(.bnanaDisplay(36).weight(.bold))
                .minimumScaleFactor(0.7)
                .foregroundStyle(BnanaColor.text)
            Text("site views")
                .font(.bnanaMono(12))
                .textCase(.uppercase)
                .foregroundStyle(BnanaColor.muted)
            Text("Last updated \(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.bnanaMono(10))
                .foregroundStyle(BnanaColor.muted)
        }
    }
}

private struct MediumAnalyticsView: View {
    let snapshot: AnalyticsSnapshot

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("TODAY")
                    .font(.bnanaMono(11))
                    .tracking(1.3)
                    .foregroundStyle(BnanaColor.secondary)
                Text(snapshot.todayViews.formatted())
                    .font(.bnanaDisplay(38).weight(.bold))
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(BnanaColor.text)
                Text("VIEWS")
                    .font(.bnanaMono(11))
                    .foregroundStyle(BnanaColor.muted)
                Spacer()
                Text("Last updated \(snapshot.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.bnanaMono(10))
                    .foregroundStyle(BnanaColor.muted)
            }
            .frame(maxWidth: 90, alignment: .leading)

            VStack(alignment: .leading, spacing: 9) {
                Text("DAILY MOVEMENT")
                    .font(.bnanaMono(11))
                    .tracking(1.1)
                    .foregroundStyle(BnanaColor.secondary)
                MovementChart(values: snapshot.dailyViews)
                Text("LAST 7 DAYS")
                    .font(.bnanaMono(10))
                    .foregroundStyle(BnanaColor.muted)
            }
        }
    }
}

private struct MovementChart: View {
    let values: [Int]

    var body: some View {
        GeometryReader { geometry in
            let points = chartPoints(in: geometry.size)

            ZStack {
                VStack(spacing: 0) {
                    Divider().overlay(BnanaColor.border)
                    Spacer()
                    Divider().overlay(BnanaColor.border)
                    Spacer()
                    Divider().overlay(BnanaColor.border)
                }

                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(
                        BnanaColor.primary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                }

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(BnanaColor.secondary)
                        .frame(width: 5, height: 5)
                        .position(point)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }

        let maximum = CGFloat(max(values.max() ?? 0, 1))
        let denominator = CGFloat(max(values.count - 1, 1))
        let verticalPadding: CGFloat = 3

        return values.enumerated().map { index, value in
            CGPoint(
                x: CGFloat(index) / denominator * size.width,
                y: size.height - verticalPadding
                    - CGFloat(value) / maximum * max(size.height - verticalPadding * 2, 1)
            )
        }
    }
}

private struct EmptyAnalyticsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("bnana.")
                .font(.bnanaDisplay(24).weight(.bold))
                .foregroundStyle(BnanaColor.text)
            Spacer()
            Text("Open bnana to load analytics.")
                .font(.bnanaMono(11))
                .foregroundStyle(BnanaColor.muted)
        }
    }
}

struct BnanaAnalyticsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: widgetKind, provider: AnalyticsProvider()) { entry in
            AnalyticsWidgetView(entry: entry)
        }
        .configurationDisplayName("Bnana Analytics")
        .description("The latest analytics cached by bnana.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct BnanaWidgets: WidgetBundle {
    var body: some Widget {
        BnanaAnalyticsWidget()
        LastTimeWidget()
    }
}
