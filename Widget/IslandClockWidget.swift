import AppIntents
import SwiftUI
import WidgetKit

// A home screen clock that borrows the island presets' looks.
// Widgets can't read the app's live settings without App Groups (which sideloading usually breaks),
// so each widget has its own look picker instead: long-press the widget → Edit Widget.

enum WidgetLook: String, AppEnum {
    case neon, sunset, mono, gold, ocean, cyber, vapor

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Look"

    static var caseDisplayRepresentations: [WidgetLook: DisplayRepresentation] = [
        .neon: DisplayRepresentation(title: "Neon"),
        .sunset: DisplayRepresentation(title: "Sunset"),
        .mono: DisplayRepresentation(title: "Mono"),
        .gold: DisplayRepresentation(title: "Gold"),
        .ocean: DisplayRepresentation(title: "Ocean"),
        .cyber: DisplayRepresentation(title: "Cyber"),
        .vapor: DisplayRepresentation(title: "Vaporwave")
    ]

    var accent: Color {
        switch self {
        case .neon: return Color(red: 0.0, green: 0.9, blue: 1.0)
        case .sunset: return Color(red: 1.0, green: 0.58, blue: 0.1)
        case .mono: return Color.white
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .ocean: return Color(red: 0.0, green: 0.78, blue: 1.0)
        case .cyber: return Color(red: 0.0, green: 1.0, blue: 0.61)
        case .vapor: return Color(red: 1.0, green: 0.44, blue: 0.81)
        }
    }

    var second: Color {
        switch self {
        case .neon: return Color(red: 0.37, green: 0.36, blue: 0.9)
        case .sunset: return Color(red: 1.0, green: 0.18, blue: 0.33)
        case .mono: return Color(white: 0.55)
        case .gold: return Color(red: 1.0, green: 0.65, blue: 0.0)
        case .ocean: return Color(red: 0.0, green: 0.45, blue: 1.0)
        case .cyber: return Color(red: 0.0, green: 0.6, blue: 0.4)
        case .vapor: return Color(red: 0.0, green: 0.8, blue: 1.0)
        }
    }

    var glows: Bool { self == .neon || self == .cyber || self == .vapor || self == .gold }

    var design: Font.Design {
        switch self {
        case .cyber: return .monospaced
        case .gold, .vapor: return .serif
        default: return .rounded
        }
    }
}

struct ClockLookIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Clock look"
    static var description: IntentDescription = IntentDescription("Pick a look for the clock.")

    @Parameter(title: "Look", default: .neon)
    var look: WidgetLook
}

struct ClockEntry: TimelineEntry {
    let date: Date
    let look: WidgetLook
}

struct ClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), look: .neon)
    }

    func snapshot(for configuration: ClockLookIntent, in context: Context) async -> ClockEntry {
        ClockEntry(date: Date(), look: configuration.look)
    }

    func timeline(for configuration: ClockLookIntent, in context: Context) async -> Timeline<ClockEntry> {
        let entry = ClockEntry(date: Date(), look: configuration.look)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
    }
}

struct ClockWidgetView: View {
    let entry: ClockEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.date, style: .time)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryCircular:
            Text(entry.date, style: .time)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
        case .accessoryInline:
            Text(entry.date, style: .time)
        default:
            home
        }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 4) {
            Spacer(minLength: 0)
            Text(entry.date, style: .time)
                .font(.system(size: 40, weight: .bold, design: entry.look.design))
                .foregroundStyle(LinearGradient(colors: [entry.look.accent, entry.look.second],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: entry.look.glows ? entry.look.accent.opacity(0.8) : Color.clear, radius: 8)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(entry.date, format: .dateTime.weekday(.wide).month().day())
                .font(.system(size: 14, weight: .semibold, design: entry.look.design))
                .foregroundStyle(Color.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IslandClockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "IslandClockWidget", intent: ClockLookIntent.self,
                               provider: ClockProvider()) { entry in
            ClockWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [entry.look.second.opacity(0.35), Color.black],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Island Clock")
        .description("A clock with the same looks as your island presets.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}
