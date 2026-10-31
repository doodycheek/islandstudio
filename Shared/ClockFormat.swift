import Foundation

/// Time formatting that can force 12-hour or 24-hour, or follow your iPhone's setting.
enum ClockFormat {
    private static var formatters: [String: DateFormatter] = [:]

    static func string(_ date: Date, tz: TimeZone = TimeZone.current, seconds: Bool, hour12: Bool?) -> String {
        let mode = hour12.map { $0 ? "12" : "24" } ?? "sys"
        let key = mode + "|" + (seconds ? "s" : "m") + "|" + tz.identifier
        let formatter: DateFormatter
        if let cached = formatters[key] {
            formatter = cached
        } else {
            let made = DateFormatter()
            made.timeZone = tz
            if let hour12 {
                made.locale = Locale(identifier: "en_US_POSIX")
                if hour12 {
                    made.dateFormat = seconds ? "h:mm:ss a" : "h:mm a"
                } else {
                    made.dateFormat = seconds ? "HH:mm:ss" : "HH:mm"
                }
            } else {
                made.locale = Locale.current
                made.setLocalizedDateFormatFromTemplate(seconds ? "jmmss" : "jmm")
            }
            formatters[key] = made
            formatter = made
        }
        return formatter.string(from: date)
    }

    /// "4:07" or "1:04:07".
    static func duration(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }
}

extension IslandState {
    /// nil follows the system, true is 12-hour, false is 24-hour.
    var hour12: Bool? {
        switch clockMode {
        case "12": return true
        case "24": return false
        default: return nil
        }
    }

    /// "12m", "3h", "Now" for the next calendar event.
    var nextEventCountdown: String {
        let seconds = nextEventStart.timeIntervalSince(now)
        if seconds <= 0 { return "Now" }
        let minutes = Int(ceil(seconds / 60))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        if hours < 48 { return "\(hours)h" }
        return "\(hours / 24)d"
    }

    var nextEventLine: String {
        if nextEventTitle.isEmpty { return "No events" }
        return "\(String(nextEventTitle.prefix(14))) \(nextEventCountdown)"
    }
}

/// Lets any text box on the island fill itself in live, like {battery} or {time}.
enum TextVars {
    static let help = "{battery} {time} {date} {steps} {temp} {counter} {goal} {streak} {song} {artist} {next}"

    static func resolve(_ text: String, state: IslandState) -> String {
        guard text.contains("{") else { return text }
        var out = text
        let values: [String: String] = [
            "battery": state.battery >= 0 ? "\(state.battery)%" : "--",
            "time": ClockFormat.string(state.now, seconds: false, hour12: state.hour12),
            "date": state.now.formatted(.dateTime.month(.abbreviated).day()),
            "day": state.now.formatted(.dateTime.weekday(.wide)),
            "steps": state.steps >= 0 ? state.steps.formatted() : "--",
            "temp": state.weatherTemp.map { "\($0)°" } ?? "--",
            "counter": "\(state.counter)",
            "goal": "\(state.counterGoal)",
            "streak": "\(state.streak)",
            "song": state.musicTitle.isEmpty ? "Nothing playing" : state.musicTitle,
            "artist": state.musicArtist,
            "next": state.nextEventLine
        ]
        for (key, value) in values {
            out = out.replacingOccurrences(of: "{" + key + "}", with: value)
        }
        return out
    }
}
