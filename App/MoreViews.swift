import SwiftUI

// MARK: - Live info

struct LiveInfoSettingsView: View {
    @EnvironmentObject var manager: IslandManager

    private var weatherText: String {
        if let temp = manager.info.weatherTemp { return "\(temp)°" }
        return manager.settings.latitude == nil ? "Location not set" : "Loading…"
    }

    var body: some View {
        Form {
            Section {
                Toggle("Fahrenheit", isOn: $manager.settings.useFahrenheit)
                Button {
                    Task { await manager.updateLocation() }
                } label: {
                    Label(manager.settings.latitude == nil ? "Set my location" : "Update my location",
                          systemImage: "location.fill")
                }
                HStack {
                    Text("Current")
                    Spacer()
                    if !manager.info.weatherSymbol.isEmpty {
                        Image(systemName: manager.info.weatherSymbol)
                    }
                    Text(weatherText).foregroundStyle(.secondary)
                }
            } header: {
                Text("Weather")
            } footer: {
                Text("From Open-Meteo (free, no account). Refreshes every 15 minutes while a weather slot is showing. Your location is only used to look up the forecast.")
            }

            Section {
                DatePicker("Count down to", selection: $manager.settings.countdownTarget,
                           displayedComponents: [.date, .hourAndMinute])
            } header: {
                Text("Countdown")
            } footer: {
                Text("Shows days and hours, then switches to a live ticking timer in the final 24 hours.")
            }

            Section {
                Button {
                    manager.requestMusicAccess()
                } label: {
                    Label("Allow Apple Music access", systemImage: "music.note")
                }
                HStack {
                    Text("Now playing")
                    Spacer()
                    Text(manager.info.musicTitle.isEmpty ? "Nothing" : manager.info.musicTitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } header: {
                Text("Music")
            } footer: {
                Text("Only the built-in Music app can be read by other apps. Spotify, YouTube and others won't show.")
            }

            Section {
                Button {
                    manager.refreshStepsNow()
                } label: {
                    Label("Refresh steps", systemImage: "figure.walk")
                }
                HStack {
                    Text("Today")
                    Spacer()
                    Text(manager.info.steps >= 0 ? "\(manager.info.steps)" : "--")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Steps")
            } footer: {
                Text("The first refresh asks for Motion & Fitness access.")
            }

        }
        .navigationTitle("Live info")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
    }
}

// MARK: - Pop-outs, charging, buttons, Shortcuts

struct ExtrasView: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        Form {
            Section {
                Toggle("Charging mode", isOn: $manager.settings.chargingMode)
            } header: {
                Text("Charging")
            } footer: {
                Text("When you plug in, the island pops out with your battery level and switches to a charging animation until you unplug.")
            }

            Section {
                Toggle("Hourly pop-out", isOn: $manager.settings.hourlyPopOut)
                Toggle("Play sound with pop-outs", isOn: $manager.settings.chimeSound)
                Button {
                    Task { await manager.testPopOut() }
                } label: {
                    Label("Test pop-out", systemImage: "rectangle.expand.vertical")
                }
            } header: {
                Text("Pop-outs")
            } footer: {
                Text("The island briefly expands at the top of every hour. After tapping Test, swipe home within 5 seconds to see it.")
            }

            Section {
                Toggle("Buttons in long-press view", isOn: $manager.settings.showIslandButtons)
            } header: {
                Text("Island buttons")
            } footer: {
                Text("Long-press the island for previous preset, pause/resume, and next preset buttons.")
            }

            Section {
                Text("Open the Shortcuts app and search Island Studio to find Start Island, Stop Island, Set Island Preset, Next and Previous Preset, and Pause or Resume. Use them in Automations, for example: When CarPlay connects → Set Island Preset.")
                    .font(.callout)
            } header: {
                Text("Shortcuts")
            }
        }
        .navigationTitle("Pop-outs & extras")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
    }
}

// MARK: - Auto schedule

struct ScheduleView: View {
    @EnvironmentObject var manager: IslandManager

    private var allPresets: [SavedPreset] { PresetStore.builtIns + manager.savedPresets }

    var body: some View {
        Form {
            Section {
                Toggle("Auto schedule", isOn: $manager.settings.schedule.enabled)
            } footer: {
                Text("Switches presets automatically at the times below. Needs background mode on, or the app open, to switch on time.")
            }

            ForEach(manager.settings.schedule.blocks.indices, id: \.self) { i in
                Section(manager.settings.schedule.blocks[i].name) {
                    DatePicker("Starts at", selection: startBinding(i), displayedComponents: .hourAndMinute)
                    Picker("Preset", selection: $manager.settings.schedule.blocks[i].presetID) {
                        ForEach(allPresets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                }
                .disabled(!manager.settings.schedule.enabled)
            }
        }
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

// MARK: - Saved presets & sharing

struct SavedPresetsView: View {
    @EnvironmentObject var manager: IslandManager
    @State private var showSave = false
    @State private var newName = ""
    @State private var showRename = false
    @State private var renameID = ""
    @State private var renameText = ""

    var body: some View {
        Form {
            Section {
                Button {
                    newName = ""
                    showSave = true
                } label: {
                    Label("Save current style", systemImage: "square.and.arrow.down")
                }
                Button {
                    manager.importPresetFromClipboard()
                } label: {
                    Label("Paste a shared preset code", systemImage: "doc.on.clipboard")
                }
            } footer: {
                Text("Press and hold a saved preset to copy its share code. Anyone with Island Studio can paste it to get your exact style.")
            }

            Section("My presets") {
                if manager.savedPresets.isEmpty {
                    Text("No saved presets yet").foregroundStyle(.secondary)
                }
                ForEach(manager.savedPresets) { preset in
                    HStack {
                        Image(systemName: preset.icon)
                        Text(preset.name)
                        Spacer()
                        if preset.id == manager.settings.currentPresetID {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { manager.apply(preset) }
                    .contextMenu {
                        Button {
                            manager.copyShareCode(preset)
                        } label: {
                            Label("Copy share code", systemImage: "doc.on.doc")
                        }
                        Button {
                            renameID = preset.id
                            renameText = preset.name
                            showRename = true
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            manager.deletePreset(id: preset.id)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onDelete { offsets in
                    manager.savedPresets.remove(atOffsets: offsets)
                }
            }
        }
        .navigationTitle("Saved presets")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
        .alert("Save preset", isPresented: $showSave) {
            TextField("Name", text: $newName)
            Button("Save") { manager.saveCurrentAsPreset(named: newName) }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename preset", isPresented: $showRename) {
            TextField("Name", text: $renameText)
            Button("Save") { manager.renamePreset(id: renameID, to: renameText) }
            Button("Cancel", role: .cancel) {}
        }
    }
}
