import AVFoundation
import EventKit
import Foundation
import Network
import UIKit

// MARK: - Wi-Fi / cellular

final class NetworkWatcher {
    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var current = "none"

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let type: String
            if path.status != .satisfied {
                type = "none"
            } else if path.usesInterfaceType(.cellular) && !path.usesInterfaceType(.wifi) {
                type = "cell"
            } else {
                type = "wifi"
            }
            self?.set(type)
        }
        monitor.start(queue: DispatchQueue(label: "island.network"))
    }

    var type: String {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    private func set(_ value: String) {
        lock.lock()
        current = value
        lock.unlock()
    }
}

// MARK: - Calendar

final class CalendarWatcher {
    struct Upcoming {
        let title: String
        let start: Date
        let end: Date
        let inProgress: Bool
    }

    private let store = EKEventStore()

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var needsPrompt: Bool {
        EKEventStore.authorizationStatus(for: .event) == .notDetermined
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// The event happening now, or the next one in the coming 36 hours.
    func upcoming(now: Date) -> Upcoming? {
        guard hasAccess else { return nil }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-6 * 3600),
                                                 end: now.addingTimeInterval(36 * 3600), calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.endDate > now }
            .sorted { $0.startDate < $1.startDate }
        guard let event = events.first else { return nil }
        return Upcoming(title: event.title ?? "Event", start: event.startDate, end: event.endDate,
                        inProgress: event.startDate <= now)
    }
}

// MARK: - Small system readings

@MainActor
enum SystemReader {
    static var lowPower: Bool { ProcessInfo.processInfo.isLowPowerModeEnabled }

    static var volumePercent: Int {
        Int((AVAudioSession.sharedInstance().outputVolume * 100).rounded())
    }

    static var brightnessPercent: Int {
        Int((UIScreen.main.brightness * 100).rounded())
    }

    static func freeStorageGB() -> Int? {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
              let bytes = values.volumeAvailableCapacityForImportantUsage else { return nil }
        return Int(bytes / 1_000_000_000)
    }
}

// MARK: - More weather: UV, rain chance, wind, air quality

struct WeatherExtras {
    let uv: Double?
    let rainChance: Int?
    let wind: Int?
}

extension WeatherService {
    private struct ExtrasResponse: Decodable {
        struct Current: Decodable {
            let wind_speed_10m: Double?
        }
        struct Hourly: Decodable {
            let uv_index: [Double?]?
            let precipitation_probability: [Double?]?
        }
        let utc_offset_seconds: Int?
        let current: Current?
        let hourly: Hourly?
    }

    static func fetchExtras(lat: Double, lon: Double, fahrenheit: Bool) async -> WeatherExtras? {
        guard var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", lon)),
            URLQueryItem(name: "current", value: "wind_speed_10m"),
            URLQueryItem(name: "hourly", value: "uv_index,precipitation_probability"),
            URLQueryItem(name: "forecast_days", value: "1"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "wind_speed_unit", value: fahrenheit ? "mph" : "kmh")
        ]
        guard let url = comps.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(ExtrasResponse.self, from: data)
            let offset = decoded.utc_offset_seconds ?? 0
            let local = Date().addingTimeInterval(TimeInterval(offset))
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? TimeZone.current
            let hour = calendar.component(.hour, from: local)

            func pick(_ values: [Double?]?) -> Double? {
                guard let values, hour < values.count else { return nil }
                return values[hour]
            }

            return WeatherExtras(uv: pick(decoded.hourly?.uv_index),
                                 rainChance: pick(decoded.hourly?.precipitation_probability).map { Int($0.rounded()) },
                                 wind: decoded.current?.wind_speed_10m.map { Int($0.rounded()) })
        } catch {
            return nil
        }
    }
}

enum AirQualityService {
    private struct Response: Decodable {
        struct Current: Decodable {
            let us_aqi: Double?
        }
        let current: Current?
    }

    static func fetch(lat: Double, lon: Double) async -> Int? {
        guard var comps = URLComponents(string: "https://air-quality-api.open-meteo.com/v1/air-quality") else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", lon)),
            URLQueryItem(name: "current", value: "us_aqi")
        ]
        guard let url = comps.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            return decoded.current?.us_aqi.map { Int($0.rounded()) }
        } catch {
            return nil
        }
    }
}
