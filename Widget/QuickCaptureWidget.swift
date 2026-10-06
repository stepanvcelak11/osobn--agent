import WidgetKit
import SwiftUI

/// Widget nezobrazuje žádná data – jen tlačítko, které otevře aplikaci na rychlý záznam.
/// (Data jsou šifrovaná a widget k nim záměrně nemá přístup.)
struct CaptureEntry: TimelineEntry { let date: Date }

struct CaptureProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaptureEntry { CaptureEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (CaptureEntry) -> Void) { completion(CaptureEntry(date: Date())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<CaptureEntry>) -> Void) {
        completion(Timeline(entries: [CaptureEntry(date: Date())], policy: .never))
    }
}

struct CaptureWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill").font(.title2.weight(.semibold))
            }
            .widgetAccentable()
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: "mic.circle.fill").font(.title2)
                VStack(alignment: .leading) {
                    Text("Rychlý záznam").font(.headline)
                    Text("Klepni a mluv").font(.caption)
                }
            }
            .widgetAccentable()
        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(red: 0.37, green: 0.79, blue: 0.75))
                Spacer()
                Text("Rychlý záznam").font(.headline)
                Text("Nadiktuj myšlenku").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

@main
struct QuickCaptureWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuickCapture", provider: CaptureProvider()) { _ in
            CaptureWidgetView()
                .widgetURL(URL(string: "osobniagent://capture"))
                .containerBackground(for: .widget) { Color(red: 0.06, green: 0.09, blue: 0.16) }
        }
        .configurationDisplayName("Rychlý záznam")
        .description("Jedním klepnutím nadiktuj poznámku, úkol nebo připomínku.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}
