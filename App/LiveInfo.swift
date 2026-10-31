import CoreLocation
import CoreMotion
import Foundation
import MediaPlayer
import UIKit

/// Latest live readings, cached by the manager and copied into the island state.
struct LiveInfo: Equatable {
    var musicTitle = ""
    var musicArtist = ""
    var musicPlaying = false
    var musicArt: Data? = nil
    var steps = -1
    var weatherTemp: Int? = nil
    var weatherSymbol = ""
    var cryptoPrice: Double? = nil
    var cryptoChange: Double? = nil
    var uv: Double? = nil
    var rainChance: Int? = nil
    var wind: Int? = nil
    var aqi: Int? = nil
    var nextEventTitle = ""
    var nextEventStart = Date()
    var nextEventInProgress = false
    var storageGB = -1
}

// MARK: - Music (built-in Music app only)

@MainActor
final class MusicWatcher {
    struct Snapshot {
        var title = ""
        var artist = ""
        var playing = false
        var art: Data? = nil
    }

    private var lastKey = ""
    private var cachedArt: Data?
    private var askedOnce = false

    static func togglePlayPause() {
        let player = MPMusicPlayerController.systemMusicPlayer
        if player.playbackState == .playing {
            player.pause()
        } else {
            player.play()
        }
    }

    static func next() {
        MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
    }

    static func previous() {
        MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
    }

    static func requestAccess() async -> Bool {
        await withCheckedContinuation { cont in
            MPMediaLibrary.requestAuthorization { @Sendable status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    /// Returns nil when access isn't granted.
    func poll(canPrompt: Bool) -> Snapshot? {
        let status = MPMediaLibrary.authorizationStatus()
        if status == .notDetermined {
            if canPrompt && !askedOnce {
                askedOnce = true
                MPMediaLibrary.requestAuthorization { @Sendable _ in }
            }
            return nil
        }
        guard status == .authorized else { return nil }

        let player = MPMusicPlayerController.systemMusicPlayer
        guard let item = player.nowPlayingItem else { return Snapshot() }
        let title = item.title ?? ""
        let artist = item.artist ?? ""
        let key = "\(item.persistentID)|\(title)|\(artist)"
        if key != lastKey {
            lastKey = key
            cachedArt = nil
            if let image = item.artwork?.image(at: CGSize(width: 96, height: 96)) {
                cachedArt = ImageCompressor.tinyJPEG(from: image, maxBytes: 800)
            }
        }
        return Snapshot(title: title, artist: artist, playing: player.playbackState == .playing, art: cachedArt)
    }
}

// MARK: - Steps

final class StepsWatcher {
    private let pedometer = CMPedometer()

    func todaySteps() async -> Int? {
        guard CMPedometer.isStepCountingAvailable() else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        return await withCheckedContinuation { cont in
            pedometer.queryPedometerData(from: start, to: Date()) { @Sendable data, _ in
                cont.resume(returning: data.map { $0.numberOfSteps.intValue })
            }
        }
    }
}

// MARK: - Location (one-shot, for weather)

@MainActor
final class LocationFetcher: NSObject, CLLocationManagerDelegate {
    private var clManager: CLLocationManager?
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    private func locationManager() -> CLLocationManager {
        if let existing = clManager { return existing }
        let created = CLLocationManager()
        created.delegate = self
        created.desiredAccuracy = kCLLocationAccuracyKilometer
        clManager = created
        return created
    }

    func current() async -> CLLocation? {
        guard continuation == nil else { return nil }
        let manager = locationManager()
        return await withCheckedContinuation { cont in
            continuation = cont
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                finish(nil)
            }
        }
    }

    private func finish(_ location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }

    private func handleAuthorization(_ status: CLAuthorizationStatus) {
        guard continuation != nil else { return }
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            clManager?.requestLocation()
        case .notDetermined:
            break
        default:
            finish(nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.handleAuthorization(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        Task { @MainActor in
            self.finish(coordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) })
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}

// MARK: - Weather (Open-Meteo, free, no key)

struct WeatherReading {
    let temp: Int
    let symbol: String
}

enum WeatherService {
    private struct Response: Decodable {
        struct Current: Decodable {
            let temperature_2m: Double
            let weather_code: Int
            let is_day: Int
        }
        let current: Current
    }

    static func fetch(lat: Double, lon: Double, fahrenheit: Bool) async -> WeatherReading? {
        guard var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast") else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.3f", lat)),
            URLQueryItem(name: "longitude", value: String(format: "%.3f", lon)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: fahrenheit ? "fahrenheit" : "celsius")
        ]
        guard let url = comps.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let current = try JSONDecoder().decode(Response.self, from: data).current
            return WeatherReading(temp: Int(current.temperature_2m.rounded()),
                                  symbol: symbol(code: current.weather_code, isDay: current.is_day == 1))
        } catch {
            return nil
        }
    }

    /// Maps WMO weather codes to SF Symbols.
    static func symbol(code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...57: return "cloud.drizzle.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 61...67, 80...82: return "cloud.rain.fill"
        case 71...77, 85, 86: return "cloud.snow.fill"
        case 95...99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }
}

// MARK: - Crypto (CoinGecko, free, no key)

enum CryptoService {
    static let ids: [String: String] = [
        "BTC": "bitcoin", "ETH": "ethereum", "SOL": "solana", "DOGE": "dogecoin",
        "XRP": "ripple", "LTC": "litecoin", "ADA": "cardano", "BNB": "binancecoin"
    ]

    static var symbols: [String] { ids.keys.sorted() }

    struct Reading {
        let price: Double
        let change: Double
    }

    static func fetch(symbol: String) async -> Reading? {
        guard let id = ids[symbol],
              let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(id)&vs_currencies=usd&include_24hr_change=true") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let coin = root[id] as? [String: Any],
                  let price = coin["usd"] as? Double else { return nil }
            let change = coin["usd_24h_change"] as? Double ?? 0
            return Reading(price: price, change: change)
        } catch {
            return nil
        }
    }
}
