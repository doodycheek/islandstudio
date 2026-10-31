import AppIntents
import SwiftUI
import UIKit
import WidgetKit

// More home screen and Lock Screen widgets, in the same looks as your island presets.
// Widgets can't read the app's live settings (that needs App Groups, which sideloading usually breaks),
// so each one has its own look picker: long-press the widget, then Edit Widget.

private func widgetBackground(_ look: WidgetLook) -> some View {
    LinearGradient(colors: [look.second.opacity(0.35), Color.black], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Battery

struct BatteryEntry: TimelineEntry {
    let date: Date
    let level: Int
    let charging: Bool
    let look: WidgetLook
}

struct BatteryProvider: AppIntentTimelineProvider {
    private func read(look: WidgetLook) async -> BatteryEntry {
        await MainActor.run {
            let device = UIDevice.current
            device.isBatteryMonitoringEnabled = true
            let level = device.batteryLevel
            let charging = device.batteryState == .charging || device.batteryState == .full
            return BatteryEntry(date: Date(), level: level < 0 ? -1 : Int((level * 100).rounded()),
                                charging: charging, look: look)
        }
    }

    func placeholder(in context: Context) -> BatteryEntry {
        BatteryEntry(date: Date(), level: 80, charging: false, look: .neon)
    }

    func snapshot(for configuration: ClockLookIntent, in context: Context) async -> BatteryEntry {
        await read(look: configuration.look)
    }

    func timeline(for configuration: ClockLookIntent, in context: Context) async -> Timeline<BatteryEntry> {
        let entry = await read(look: configuration.look)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(900)))
    }
}

struct BatteryWidgetView: View {
    let entry: BatteryEntry
    @Environment(\.widgetFamily) private var family

    private var color: Color {
        BatteryGlyph.autoColor(level: entry.level, charging: entry.charging, normal: entry.look.accent)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(max(entry.level, 0)) / 100) {
                Image(systemName: entry.charging ? "bolt.fill" : "battery.50")
            } currentValueLabel: {
                Text(entry.level >= 0 ? "\(entry.level)" : "--")
            }
            .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            HStack(spacing: 8) {
                BatteryGlyph(level: entry.level, charging: entry.charging, color: Color.white, size: 30)
                Text(entry.level >= 0 ? "\(entry.level)%" : "--")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
            }
        case .accessoryInline:
            Text(entry.level >= 0 ? "Battery \(entry.level)%" : "Battery")
        default:
            VStack(alignment: .leading, spacing: 6) {
                Spacer(minLength: 0)
                BatteryGlyph(level: entry.level, charging: entry.charging, color: color, size: 52)
                    .shadow(color: entry.look.glows ? color.opacity(0.7) : Color.clear, radius: 8)
                Text(entry.level >= 0 ? "\(entry.level)%" : "--")
                    .font(.system(size: 38, weight: .bold, design: entry.look.design))
                    .foregroundStyle(color)
                Text(entry.charging ? "Charging" : "Battery")
                    .font(.system(size: 13, weight: .semibold, design: entry.look.design))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct IslandBatteryWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "IslandBatteryWidget", intent: ClockLookIntent.self,
                               provider: BatteryProvider()) { entry in
            BatteryWidgetView(entry: entry)
                .containerBackground(for: .widget) { widgetBackground(entry.look) }
        }
        .configurationDisplayName("Island Battery")
        .description("Your battery in the same look as your island.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Days counter

struct DaysIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Days counter"
    static var description: IntentDescription = IntentDescription("Count the days since a date.")

    // Date parameters with a default only exist on iOS 18, so the date is three simple number fields.
    @Parameter(title: "Year", default: 2024)
    var year: Int

    @Parameter(title: "Month (1-12)", default: 1)
    var month: Int

    @Parameter(title: "Day (1-31)", default: 1)
    var day: Int

    @Parameter(title: "Emoji", default: "💜")
    var emoji: String

    @Parameter(title: "Look", default: .neon)
    var look: WidgetLook

    var since: Date {
        var parts = DateComponents()
        parts.year = min(max(year, 1970), 2100)
        parts.month = min(max(month, 1), 12)
        parts.day = min(max(day, 1), 31)
        return Calendar.current.date(from: parts) ?? Date()
    }
}

struct DaysEntry: TimelineEntry {
    let date: Date
    let since: Date
    let emoji: String
    let look: WidgetLook

    var days: Int {
        max(0, Calendar.current.dateComponents([.day], from: since, to: date).day ?? 0)
    }
}

struct DaysProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DaysEntry {
        DaysEntry(date: Date(), since: Date().addingTimeInterval(-100 * 86_400), emoji: "💜", look: .neon)
    }

    func snapshot(for configuration: DaysIntent, in context: Context) async -> DaysEntry {
        DaysEntry(date: Date(), since: configuration.since, emoji: configuration.emoji, look: configuration.look)
    }

    func timeline(for configuration: DaysIntent, in context: Context) async -> Timeline<DaysEntry> {
        let entry = DaysEntry(date: Date(), since: configuration.since, emoji: configuration.emoji, look: configuration.look)
        let midnight = Calendar.current.startOfDay(for: Date()).addingTimeInterval(86_400 + 60)
        return Timeline(entries: [entry], policy: .after(midnight))
    }
}

struct DaysWidgetView: View {
    let entry: DaysEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Text(entry.emoji).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(entry.days)").font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("days").font(.caption)
                }
            }
        case .accessoryCircular:
            VStack(spacing: 0) {
                Text(entry.emoji).font(.system(size: 16))
                Text("\(entry.days)").font(.system(size: 18, weight: .bold, design: .rounded))
            }
        case .accessoryInline:
            Text("\(entry.emoji) \(entry.days) days")
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.emoji).font(.system(size: 30))
                Spacer(minLength: 0)
                Text("\(entry.days)")
                    .font(.system(size: 52, weight: .heavy, design: entry.look.design))
                    .foregroundStyle(LinearGradient(colors: [entry.look.accent, entry.look.second],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: entry.look.glows ? entry.look.accent.opacity(0.7) : Color.clear, radius: 8)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("days")
                    .font(.system(size: 14, weight: .semibold, design: entry.look.design))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct IslandDaysWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "IslandDaysWidget", intent: DaysIntent.self,
                               provider: DaysProvider()) { entry in
            DaysWidgetView(entry: entry)
                .containerBackground(for: .widget) { widgetBackground(entry.look) }
        }
        .configurationDisplayName("Days Counter")
        .description("Days together, days sober, days since anything. Pick the date and an emoji.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Moon

struct MoonEntry: TimelineEntry {
    let date: Date
    let look: WidgetLook
}

struct MoonProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MoonEntry {
        MoonEntry(date: Date(), look: .neon)
    }

    func snapshot(for configuration: ClockLookIntent, in context: Context) async -> MoonEntry {
        MoonEntry(date: Date(), look: configuration.look)
    }

    func timeline(for configuration: ClockLookIntent, in context: Context) async -> Timeline<MoonEntry> {
        let entry = MoonEntry(date: Date(), look: configuration.look)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
    }
}

struct MoonWidgetView: View {
    let entry: MoonEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let phase = MoonPhase.info(for: entry.date)
        switch family {
        case .accessoryCircular:
            VStack(spacing: 0) {
                Image(systemName: phase.symbol).font(.system(size: 20))
                Text("\(phase.percent)%").font(.system(size: 12, weight: .semibold))
            }
        case .accessoryRectangular:
            HStack(spacing: 8) {
                Image(systemName: phase.symbol).font(.system(size: 26))
                VStack(alignment: .leading, spacing: 0) {
                    Text(phase.name).font(.system(size: 14, weight: .semibold))
                    Text("\(phase.percent)% lit").font(.caption)
                }
            }
        case .accessoryInline:
            Label(phase.name, systemImage: phase.symbol)
        default:
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: phase.symbol)
                    .font(.system(size: 46))
                    .foregroundStyle(LinearGradient(colors: [entry.look.accent, entry.look.second],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: entry.look.glows ? entry.look.accent.opacity(0.7) : Color.clear, radius: 8)
                Spacer(minLength: 0)
                Text(phase.name)
                    .font(.system(size: 17, weight: .bold, design: entry.look.design))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("\(phase.percent)% lit")
                    .font(.system(size: 13, weight: .semibold, design: entry.look.design))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct IslandMoonWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "IslandMoonWidget", intent: ClockLookIntent.self,
                               provider: MoonProvider()) { entry in
            MoonWidgetView(entry: entry)
                .containerBackground(for: .widget) { widgetBackground(entry.look) }
        }
        .configurationDisplayName("Moon Phase")
        .description("Tonight's moon, in your island's look.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
