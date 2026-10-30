import ActivityKit
import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class IslandManager: ObservableObject {
    @Published var config: IslandState {
        didSet {
            save()
            if isRunning { Task { await self.pushUpdate() } }
        }
    }
    @Published var keepAlive: Bool {
        didSet {
            UserDefaults.standard.set(keepAlive, forKey: Keys.keepAlive)
            applyKeepAlive()
        }
    }
    /// Seconds between animation frames sent to the island.
    @Published var frameInterval: Double {
        didSet { UserDefaults.standard.set(frameInterval, forKey: Keys.frameInterval) }
    }
    /// Seconds for one sweep of the looping ring / bar.
    @Published var cycleLength: Double {
        didSet { UserDefaults.standard.set(cycleLength, forKey: Keys.cycleLength) }
    }
    @Published private(set) var isRunning = false
    @Published var status = ""

    private var activity: Activity<IslandAttributes>?
    private var loopTask: Task<Void, Never>?
    private var activityStart = Date()
    private var cycleStart = Date()
    private var frame = 0
    private var waitingForForeground = false

    private enum Keys {
        static let config = "islandConfig"
        static let keepAlive = "keepAlive"
        static let frameInterval = "frameInterval"
        static let cycleLength = "cycleLength"
        static let wantsRunning = "wantsRunning"
    }

    init() {
        let d = UserDefaults.standard
        if let data = d.data(forKey: Keys.config),
           let saved = try? JSONDecoder().decode(IslandState.self, from: data) {
            config = saved
        } else {
            config = IslandState()
        }
        keepAlive = d.object(forKey: Keys.keepAlive) as? Bool ?? true
        let fi = d.double(forKey: Keys.frameInterval)
        frameInterval = fi > 0 ? fi : 1.0
        let cl = d.double(forKey: Keys.cycleLength)
        cycleLength = cl > 0 ? cl : 3.0
        UIDevice.current.isBatteryMonitoringEnabled = true
        reattach()
    }

    // MARK: - Public controls

    func start() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            status = "Live Activities are off: Settings → Island Studio → Live Activities."
            return
        }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        await endAllActivities()
        activityStart = Date()
        cycleStart = activityStart
        frame = 0
        do {
            activity = try Activity.request(
                attributes: IslandAttributes(name: "Island"),
                content: ActivityContent(state: liveState(), staleDate: nil),
                pushType: nil)
            isRunning = true
            waitingForForeground = false
            UserDefaults.standard.set(true, forKey: Keys.wantsRunning)
            status = "Island is live"
            applyKeepAlive()
            startLoop()
        } catch {
            status = "Couldn't start: \(error.localizedDescription)"
        }
    }

    func stop() async {
        loopTask?.cancel()
        loopTask = nil
        await endAllActivities()
        isRunning = false
        UserDefaults.standard.set(false, forKey: Keys.wantsRunning)
        applyKeepAlive()
        status = "Island stopped"
    }

    func appBecameActive() {
        guard UserDefaults.standard.bool(forKey: Keys.wantsRunning) else { return }
        let alive = activity.map { $0.activityState == .active } ?? false
        if !alive || waitingForForeground {
            Task { await start() }
        }
    }

    /// Simulated state for the in-app preview.
    func previewState(at date: Date) -> IslandState {
        var s = config
        let step = max(0.5, frameInterval)
        s.frame = Int(date.timeIntervalSince1970 / step)
        let len = max(1, cycleLength)
        let start = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / len) * len)
        s.cycleStart = start
        s.cycleEnd = start.addingTimeInterval(len)
        s.sessionStart = isRunning ? activityStart : date
        s.now = date
        let b = batteryInfo()
        s.battery = b.level
        s.charging = b.charging
        return s
    }

    // MARK: - Internals

    private func reattach() {
        guard let existing = Activity<IslandAttributes>.activities.first(where: { $0.activityState == .active }) else { return }
        activity = existing
        activityStart = existing.content.state.sessionStart
        isRunning = true
        applyKeepAlive()
        startLoop()
    }

    private func applyKeepAlive() {
        if keepAlive && isRunning {
            KeepAlive.shared.start()
        } else {
            KeepAlive.shared.stop()
        }
    }

    private func batteryInfo() -> (level: Int, charging: Bool) {
        let level = UIDevice.current.batteryLevel
        let st = UIDevice.current.batteryState
        return (level < 0 ? -1 : Int((level * 100).rounded()), st == .charging || st == .full)
    }

    private func liveState(now: Date = Date()) -> IslandState {
        var s = config
        s.frame = frame
        s.cycleStart = cycleStart
        s.cycleEnd = cycleStart.addingTimeInterval(max(1, cycleLength))
        s.sessionStart = activityStart
        s.now = now
        let b = batteryInfo()
        s.battery = b.level
        s.charging = b.charging
        return s
    }

    /// The heartbeat: while the app is alive (foreground or kept alive in background),
    /// this steps frame animations, re-loops rings/bars, refreshes clock & battery,
    /// and replaces the activity before iOS's 8-hour cutoff.
    private func startLoop() {
        loopTask?.cancel()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick()
                let seconds = max(0.5, self.frameInterval)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    private func tick() async {
        guard isRunning, !waitingForForeground, let current = activity else { return }
        if current.activityState != .active || Date().timeIntervalSince(activityStart) > 7.75 * 3600 {
            await replaceActivity()
            return
        }
        frame &+= 1
        let now = Date()
        if now >= cycleStart.addingTimeInterval(max(1, cycleLength)) {
            cycleStart = now
        }
        await current.update(ActivityContent(state: liveState(now: now), staleDate: nil))
    }

    private func pushUpdate() async {
        guard let current = activity, current.activityState == .active else { return }
        await current.update(ActivityContent(state: liveState(), staleDate: nil))
    }

    private func replaceActivity() async {
        let old = activity
        activityStart = Date()
        cycleStart = activityStart
        frame = 0
        do {
            activity = try Activity.request(
                attributes: IslandAttributes(name: "Island"),
                content: ActivityContent(state: liveState(), staleDate: nil),
                pushType: nil)
            await old?.end(nil, dismissalPolicy: .immediate)
        } catch {
            // iOS may refuse to start a new activity while the app is in the background.
            waitingForForeground = true
            status = "iOS paused the island. Opening the app restarts it."
            notifyRestartNeeded()
        }
    }

    private func notifyRestartNeeded() {
        let content = UNMutableNotificationContent()
        content.title = "Dynamic Island paused"
        content.body = "Tap to bring your island back."
        let request = UNNotificationRequest(identifier: "island.restart", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func endAllActivities() async {
        for a in Activity<IslandAttributes>.activities {
            await a.end(nil, dismissalPolicy: .immediate)
        }
        activity = nil
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Keys.config)
        }
    }
}
