import ActivityKit
import CoreLocation
import CoreMotion
import EventKit
import MediaPlayer
import SwiftUI

// MARK: - Arrange presets

/// Drag presets into the order you want. New presets can land at the front instead of the back.
struct ArrangePresetsView: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        List {
            Section {
                Toggle("New presets go to the front", isOn: $manager.settings.newPresetsFirst)
                Button {
                    manager.putMineFirst()
                } label: {
                    Label("Put my presets first now", systemImage: "arrow.up.to.line")
                }
                Button(role: .destructive) {
                    manager.resetPresetOrder()
                } label: {
                    Label("Reset to the original order", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("This order is also used by the Next and Previous preset buttons, so they cycle through your favorites first.")
            }

            Section {
                ForEach(manager.allPresets) { preset in
                    HStack(spacing: 12) {
                        Image(systemName: preset.icon)
                            .frame(width: 26)
                        Text(preset.name)
                        Spacer()
                        if preset.id == manager.settings.defaultPresetID {
                            Image(systemName: "house.fill").foregroundStyle(.secondary)
                        }
                        if manager.isFavorite(preset.id) {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                        if manager.isLocked(preset.id) {
                            Image(systemName: "lock.fill").foregroundStyle(.secondary)
                        }
                        Button {
                            manager.moveToFront(preset.id)
                        } label: {
                            Image(systemName: "arrow.up.to.line")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .onMove { source, destination in
                    manager.movePresets(from: source, to: destination)
                }
            } header: {
                Text("Drag the handles to reorder")
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
        .navigationTitle("Arrange presets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Chip order

extension ChipKind {
    var icon: String {
        switch self {
        case .battery: return "battery.75"
        case .weather: return "cloud.sun.fill"
        case .steps: return "figure.walk"
        case .date: return "calendar"
        case .moon: return "moonphase.waxing.gibbous"
        case .counter: return "plus.circle.fill"
        case .crypto: return "bitcoinsign.circle.fill"
        case .countdown: return "hourglass"
        case .focus: return "timer"
        case .nextEvent: return "calendar.circle.fill"
        case .uv: return "sun.max.fill"
        case .rain: return "drop.fill"
        case .wind: return "wind"
        case .aqi: return "leaf.fill"
        case .network: return "wifi"
        case .storage: return "internaldrive.fill"
        case .streak: return "flame.fill"
        }
    }
}

/// Choose which chips show, and drag them into order.
struct ChipOrderView: View {
    @Binding var kinds: [String]

    private var unused: [ChipKind] {
        ChipKind.allCases.filter { !kinds.contains($0.rawValue) }
    }

    var body: some View {
        List {
            Section {
                ForEach(kinds, id: \.self) { raw in
                    if let kind = ChipKind(rawValue: raw) {
                        Label(kind.label, systemImage: kind.icon)
                    }
                }
                .onMove { source, destination in
                    kinds.move(fromOffsets: source, toOffset: destination)
                }
                .onDelete { offsets in
                    kinds.remove(atOffsets: offsets)
                }
            } header: {
                Text("Showing, in this order")
            } footer: {
                Text("Drag to reorder, swipe to remove. Four or fewer fit best.")
            }

            if !unused.isEmpty {
                Section("Add more") {
                    ForEach(unused) { kind in
                        Button {
                            kinds.append(kind.rawValue)
                        } label: {
                            Label(kind.label, systemImage: "plus.circle.fill")
                        }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(ThemeBackground())
        .navigationTitle("Chips")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Statuses

/// Edit your quick statuses.
struct StatusSettingsView: View {
    @EnvironmentObject var manager: IslandManager

    private let durations: [(label: String, hours: Int)] = [
        ("Until I clear it", 0), ("1 hour", 1), ("2 hours", 2), ("4 hours", 4), ("8 hours", 8)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card(title: "Clears itself", icon: "timer", tint: .orange,
                     footer: "A status can switch itself off after a while, so you never forget it's on.") {
                    HStack {
                        Text("Clear after")
                        Spacer()
                        Picker("Clear after", selection: $manager.settings.statusHours) {
                            ForEach(durations, id: \.hours) { item in
                                Text(item.label).tag(item.hours)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }

                ForEach($manager.settings.statuses) { $item in
                    Card(title: item.text.isEmpty ? "Status" : item.text, icon: "bubble.left.fill", tint: .green) {
                        HStack(spacing: 10) {
                            TextField("😀", text: $item.emoji)
                                .frame(width: 54)
                                .multilineTextAlignment(.center)
                                .cardField()
                                .onChange(of: item.emoji) { _, value in
                                    if value.count > 2 { item.emoji = String(value.prefix(2)) }
                                }
                            TextField("What it says", text: $item.text)
                                .cardField()
                                .onChange(of: item.text) { _, value in
                                    if value.count > 30 { item.text = String(value.prefix(30)) }
                                }
                        }
                        ColorField(title: "Color", hex: $item.hex)
                        Button(role: .destructive) {
                            manager.settings.statuses.removeAll { $0.id == item.id }
                        } label: {
                            Label("Delete", systemImage: "trash")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                HStack(spacing: 10) {
                    WideButton(title: "Add a status", icon: "plus") {
                        manager.settings.statuses.append(StatusItem(emoji: "✨", text: "New status"))
                    }
                    WideButton(title: "Restore originals", icon: "arrow.counterclockwise") {
                        manager.settings.statuses = StatusItem.defaults
                    }
                }
            }
            .padding(16)
        }
        .background(ThemeBackground())
        .navigationTitle("Statuses")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
    }
}

// MARK: - Health check

/// Shows what's working and what iOS has switched off, so problems are easy to spot.
struct HealthView: View {
    @EnvironmentObject var manager: IslandManager

    private func row(_ title: String, _ value: String, ok: Bool?) -> some View {
        HStack {
            Image(systemName: ok == nil ? "circle.dashed" : (ok == true ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"))
                .foregroundStyle(ok == nil ? Color.secondary : (ok == true ? Color.green : Color.orange))
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private var locationText: (String, Bool?) {
        switch CLLocationManager().authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return ("On", true)
        case .denied, .restricted: return ("Off", false)
        default: return ("Not asked yet", nil)
        }
    }

    private var motionText: (String, Bool?) {
        switch CMPedometer.authorizationStatus() {
        case .authorized: return ("On", true)
        case .denied, .restricted: return ("Off", false)
        default: return ("Not asked yet", nil)
        }
    }

    private var musicText: (String, Bool?) {
        switch MPMediaLibrary.authorizationStatus() {
        case .authorized: return ("On", true)
        case .denied, .restricted: return ("Off", false)
        default: return ("Not asked yet", nil)
        }
    }

    private var calendarText: (String, Bool?) {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return ("On", true)
        case .denied, .restricted, .writeOnly: return ("Off", false)
        default: return ("Not asked yet", nil)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card(title: "Battery", icon: "battery.75", tint: .green,
                     footer: manager.batteryIsExact
                        ? "Your battery is read exactly, one percent at a time."
                        : "iOS only shares the battery with apps in 5% steps on this iPhone, so 18% shows as 20%. The exact reader couldn't get through, so we show what iOS gives us.") {
                    row("Level", manager.batteryLevelNow >= 0 ? "\(manager.batteryLevelNow)%" : "Unknown", ok: nil)
                    RowDivider()
                    row("Precision", manager.batteryIsExact ? "Exact (every percent)" : "5% steps (iOS limit)",
                        ok: manager.batteryIsExact)
                }

                Card(title: "Island", icon: "capsule.fill", tint: .purple) {
                    row("Live Activities", ActivityAuthorizationInfo().areActivitiesEnabled ? "On" : "Off",
                        ok: ActivityAuthorizationInfo().areActivitiesEnabled)
                    RowDivider()
                    row("Island", manager.isRunning ? "Running" : "Stopped", ok: manager.isRunning)
                    RowDivider()
                    row("Keep running in background", manager.keepAlive ? "On" : "Off", ok: manager.keepAlive)
                }

                Card(title: "Live data", icon: "waveform.path.ecg", tint: .teal,
                     footer: "See the current value of every live source, and what's missing when one shows a dash.") {
                    NavigationLink {
                        LiveDataView()
                    } label: {
                        NavRowLabel(title: "Open live data", icon: "chart.bar.doc.horizontal.fill", color: .teal)
                    }
                    .buttonStyle(.plain)
                }

                Card(title: "Setup saving", icon: "checkmark.shield.fill", tint: .indigo,
                     footer: "If Secure copy says Not available, this signing doesn't allow the Keychain. Use Save to Files in Settings instead.") {
                    row("Auto-save", manager.settings.autoSave ? "On" : "Off", ok: manager.settings.autoSave)
                    RowDivider()
                    row("Secure copy",
                        manager.autoSaveOK == nil ? "Not saved yet" : (manager.autoSaveOK == true ? "Saved" : "Not available"),
                        ok: manager.autoSaveOK)
                    RowDivider()
                    row("Brought back on this launch", manager.restoredFromKeychain ? "Yes" : "No", ok: nil)
                }

                Card(title: "Permissions", icon: "hand.raised.fill", tint: .blue,
                     footer: "A permission only matters if you use a slot that needs it. Turn any of them on in iOS Settings.") {
                    row("Location (weather)", locationText.0, ok: locationText.1)
                    RowDivider()
                    row("Motion (steps)", motionText.0, ok: motionText.1)
                    RowDivider()
                    row("Music", musicText.0, ok: musicText.1)
                    RowDivider()
                    row("Calendar", calendarText.0, ok: calendarText.1)
                    RowDivider()
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open iOS Settings", systemImage: "gear")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding(16)
        }
        .background(ThemeBackground())
        .navigationTitle("Health check")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Four boxes for your reaction emojis.
struct ReactionEditor: View {
    @EnvironmentObject var manager: IslandManager

    private func binding(_ index: Int) -> Binding<String> {
        Binding(get: {
            index < manager.settings.reactionEmojis.count ? manager.settings.reactionEmojis[index] : ""
        }, set: { value in
            var list = manager.settings.reactionEmojis
            while list.count < 4 { list.append("") }
            list[index] = String(value.prefix(2))
            manager.settings.reactionEmojis = list
        })
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                TextField("🙂", text: binding(index))
                    .multilineTextAlignment(.center)
                    .cardField()
            }
        }
    }
}

// MARK: - Live data

/// The current value of every live source, so you can see exactly what's loading and what isn't.
struct LiveDataView: View {
    @EnvironmentObject var manager: IslandManager

    private func row(_ title: String, _ value: String?, hint: String? = nil) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: value == nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(value == nil ? Color.orange : Color.green)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if value == nil, let hint {
                    Text(hint).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(value ?? "--").foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    var body: some View {
        let info = manager.info
        let location = manager.settings.latitude == nil
            ? "Set your location in Settings → Live info."
            : "Waiting for the first refresh. It loads once a slot or chip uses it."
        ScrollView {
            VStack(spacing: 16) {
                Card(title: "Weather & air", icon: "cloud.sun.fill", tint: .blue,
                     footer: "These come from Open-Meteo and refresh every 15 minutes. They only load while a slot or chip is showing them.") {
                    row("Temperature", info.weatherTemp.map { "\($0)°" }, hint: location)
                    RowDivider()
                    row("UV index", info.uv.map { String(format: "%.0f", $0) }, hint: location)
                    RowDivider()
                    row("Chance of rain", info.rainChance.map { "\($0)%" }, hint: location)
                    RowDivider()
                    row("Wind", info.wind.map { "\($0)" }, hint: location)
                    RowDivider()
                    row("Air quality", info.aqi.map { "\($0)" }, hint: location)
                }

                Card(title: "Your iPhone", icon: "iphone", tint: .purple) {
                    row("Battery", manager.batteryLevelNow >= 0 ? "\(manager.batteryLevelNow)%" : nil)
                    RowDivider()
                    row("Free storage", info.storageGB >= 0 ? "\(info.storageGB) GB" : nil,
                        hint: "Loads once a storage slot or chip is showing.")
                    RowDivider()
                    row("Volume", "\(SystemReader.volumePercent)%")
                    RowDivider()
                    row("Brightness", "\(SystemReader.brightnessPercent)%")
                    RowDivider()
                    row("Low Power Mode", SystemReader.lowPower ? "On" : "Off")
                    RowDivider()
                    row("Network", manager.networkTypeNow == "wifi" ? "Wi-Fi" : (manager.networkTypeNow == "cell" ? "Cellular" : "Offline"))
                }

                Card(title: "Goals & calendar", icon: "target", tint: .orange) {
                    row("Steps today", info.steps >= 0 ? info.steps.formatted() : nil,
                        hint: "Needs Motion & Fitness access. Check the Health check screen.")
                    RowDivider()
                    row("Counter", "\(manager.settings.counter) of \(manager.settings.counterGoal)")
                    RowDivider()
                    row("Goal streak", "\(manager.settings.streak) days")
                    RowDivider()
                    row("Next event", info.nextEventTitle.isEmpty ? nil : info.nextEventTitle,
                        hint: "Needs calendar access and an upcoming event.")
                }

                WideButton(title: "Refresh everything now", icon: "arrow.clockwise") {
                    manager.refreshAllNow()
                }
            }
            .padding(16)
        }
        .background(ThemeBackground())
        .navigationTitle("Live data")
        .navigationBarTitleDisplayMode(.inline)
    }
}
