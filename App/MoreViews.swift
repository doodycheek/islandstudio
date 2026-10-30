import SwiftUI

// MARK: - Live info

struct LiveInfoSettingsView: View {
    @EnvironmentObject var manager: IslandManager

    private var weatherText: String {
        if let temp = manager.info.weatherTemp { return "\(temp)°" }
        return manager.settings.latitude == nil ? "Location not set" : "Loading…"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card(title: "Weather", icon: "cloud.sun.fill", tint: .blue,
                     footer: "From Open-Meteo (free, no account). Refreshes every 15 minutes while weather is showing. Your location is only used to look up the forecast.") {
                    ToggleRow(title: "Fahrenheit", icon: "thermometer.medium", color: .orange,
                              isOn: $manager.settings.useFahrenheit)
                    RowDivider()
                    Button {
                        Task { await manager.updateLocation() }
                    } label: {
                        Label(manager.settings.latitude == nil ? "Set my location" : "Update my location",
                              systemImage: "location.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    RowDivider()
                    Button {
                        manager.refreshWeatherNow()
                    } label: {
                        Label("Refresh weather now", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                    }
                    RowDivider()
                    HStack {
                        Text("Right now")
                        Spacer()
                        if !manager.info.weatherSymbol.isEmpty {
                            Image(systemName: manager.info.weatherSymbol)
                        }
                        Text(weatherText).foregroundStyle(.secondary)
                    }
                }

                Card(title: "Countdown", icon: "hourglass", tint: .orange,
                     footer: "Shows days and hours, then switches to a live ticking timer in the final 24 hours.") {
                    DatePicker("Count down to", selection: $manager.settings.countdownTarget,
                               displayedComponents: [.date, .hourAndMinute])
                }

                Card(title: "Music", icon: "music.note", tint: .pink,
                     footer: "Only the built-in Music app shares song details with other apps. Spotify, YouTube and others won't show a title, but the music bars still react to them.") {
                    Button {
                        manager.requestMusicAccess()
                    } label: {
                        Label("Allow Apple Music access", systemImage: "music.note")
                            .font(.subheadline.weight(.semibold))
                    }
                    RowDivider()
                    HStack {
                        Text("Now playing")
                        Spacer()
                        Text(manager.info.musicTitle.isEmpty ? "Nothing" : manager.info.musicTitle)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Card(title: "Steps", icon: "figure.walk", tint: .green,
                     footer: "The first refresh asks for Motion & Fitness access.") {
                    Button {
                        manager.refreshStepsNow()
                    } label: {
                        Label("Refresh steps", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                    }
                    RowDivider()
                    HStack {
                        Text("Today")
                        Spacer()
                        Text(manager.info.steps >= 0 ? "\(manager.info.steps)" : "--")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
        }
        .background(ThemeBackground())
        .navigationTitle("Live info")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
    }
}

// MARK: - Auto schedule

struct ScheduleView: View {
    @EnvironmentObject var manager: IslandManager

    private var allPresets: [SavedPreset] { PresetStore.builtIns + manager.savedPresets }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card(title: "Auto schedule", icon: "clock.badge.checkmark", tint: .green,
                     footer: "Switches presets automatically at the times below. Needs background mode on, or the app open, to switch on time.") {
                    ToggleRow(title: "Switch presets by time of day", icon: "calendar.badge.clock", color: .green,
                              isOn: $manager.settings.schedule.enabled)
                }

                ForEach(manager.settings.schedule.blocks.indices, id: \.self) { i in
                    Card(title: manager.settings.schedule.blocks[i].name,
                         icon: i == 0 ? "sunrise.fill" : (i == 1 ? "sun.max.fill" : "moon.stars.fill"),
                         tint: i == 0 ? .orange : (i == 1 ? .yellow : .indigo)) {
                        DatePicker("Starts at", selection: startBinding(i), displayedComponents: .hourAndMinute)
                        RowDivider()
                        HStack {
                            Text("Preset")
                            Spacer()
                            Picker("Preset", selection: $manager.settings.schedule.blocks[i].presetID) {
                                ForEach(allPresets) { preset in
                                    Text(preset.name).tag(preset.id)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                    }
                    .opacity(manager.settings.schedule.enabled ? 1 : 0.5)
                    .disabled(!manager.settings.schedule.enabled)
                }
            }
            .padding(16)
        }
        .background(ThemeBackground())
        .navigationTitle("Auto schedule")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
    }

    private func startBinding(_ i: Int) -> Binding<Date> {
        Binding(
            get: {
                let minute = manager.settings.schedule.blocks[i].startMinute
                return Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(minute * 60))
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                manager.settings.schedule.blocks[i].startMinute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            }
        )
    }
}
