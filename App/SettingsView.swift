import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: IslandManager
    @AppStorage("themeMode") private var themeMode = ThemeMode.system.rawValue
    @AppStorage("accentChoice") private var accentChoice = AccentChoice.purple.rawValue

    private var scheduleSummary: String {
        manager.settings.schedule.enabled ? "On" : "Off"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Card(title: "Appearance", icon: "paintbrush.pointed.fill", tint: .purple) {
                        Picker("Theme", selection: $themeMode) {
                            ForEach(ThemeMode.allCases) { mode in
                                Text(mode.label).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("Accent color").font(.subheadline.weight(.medium))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(AccentChoice.allCases) { choice in
                                    Button {
                                        accentChoice = choice.rawValue
                                    } label: {
                                        Circle()
                                            .fill(choice.color.gradient)
                                            .frame(width: 32, height: 32)
                                            .overlay {
                                                if accentChoice == choice.rawValue {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                            .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    Card(title: "Music", icon: "music.note", tint: .pink,
                         footer: manager.settings.musicMode.explanation) {
                        HStack(spacing: 10) {
                            IconBadge(systemName: "music.note", color: .pink)
                            Text("When music plays")
                            Spacer()
                            Picker("When music plays", selection: $manager.settings.musicMode) {
                                ForEach(MusicMode.allCases) { mode in
                                    Text(mode.label).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                        }
                        if manager.settings.musicMode == .showMusic {
                            RowDivider()
                            NavigationLink {
                                MusicLayoutView()
                            } label: {
                                NavRowLabel(title: "Music layout", icon: "slider.horizontal.3", color: .purple)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Card(title: "Live info & automation", icon: "antenna.radiowaves.left.and.right", tint: .blue) {
                        NavigationLink {
                            ToolsView()
                        } label: {
                            NavRowLabel(title: "Tools & data slots", icon: "wrench.and.screwdriver.fill", color: .orange)
                        }
                        .buttonStyle(.plain)
                        RowDivider()
                        NavigationLink {
                            LiveInfoSettingsView()
                        } label: {
                            NavRowLabel(title: "Weather, steps, countdown", icon: "cloud.sun.fill", color: .blue)
                        }
                        .buttonStyle(.plain)
                        RowDivider()
                        NavigationLink {
                            ScheduleView()
                        } label: {
                            NavRowLabel(title: "Auto schedule", icon: "clock.badge.checkmark", color: .green,
                                        value: scheduleSummary)
                        }
                        .buttonStyle(.plain)
                    }

                    Card(title: "Automatic presets", icon: "calendar.badge.clock", tint: .green,
                         footer: "Holiday presets switch on once at the start of each holiday day: Valentine's, Halloween, Christmas and New Year. Your birthday gets its own preset. They beat the auto schedule for that day.") {
                        ToggleRow(title: "Holiday presets", icon: "gift.fill", color: .red,
                                  isOn: $manager.settings.holidayAuto)
                        RowDivider()
                        ToggleRow(title: "Birthday preset", icon: "birthday.cake.fill", color: .pink,
                                  isOn: $manager.settings.birthdayEnabled)
                        if manager.settings.birthdayEnabled {
                            RowDivider()
                            DatePicker("My birthday", selection: $manager.settings.birthday,
                                       displayedComponents: .date)
                        }
                    }

                    Card(title: "Backup", icon: "externaldrive.fill", tint: .gray,
                         footer: "Copies your settings, presets and photo as one code. Your location is left out. Paste it on a fresh install to restore everything.") {
                        HStack(spacing: 10) {
                            Button {
                                manager.copyBackup()
                            } label: {
                                Label("Copy backup", systemImage: "doc.on.doc")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.tertiarySystemFill)))
                            }
                            Button {
                                manager.restoreBackupFromClipboard()
                            } label: {
                                Label("Restore", systemImage: "arrow.down.doc")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.tertiarySystemFill)))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Card(title: "Background", icon: "bolt.fill", tint: .yellow,
                         footer: "Background mode keeps animations, live info, pop-outs and the schedule running. Don't swipe the app away in the app switcher.") {
                        ToggleRow(title: "Keep running in background", icon: "arrow.triangle.2.circlepath",
                                  color: .yellow, isOn: $manager.keepAlive)
                    }

                    Card(title: "Shortcuts", icon: "square.stack.3d.up.fill", tint: .indigo) {
                        Text("Open the Shortcuts app and search Island Studio for Start Island, Stop Island, Set Island Preset, Next and Previous Preset, and Pause or Resume. Try an automation like: When CarPlay connects → Set Island Preset.")
                            .font(.callout)
                    }

                    Text("Island Studio 1.4")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(ThemeBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// Lets you design the island that shows while music plays.
struct MusicLayoutView: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        let snapshot = manager.previewState(at: Date(), music: true)
        ScrollView {
            VStack(spacing: 16) {
                Card(title: "Left side", icon: "rectangle.lefthalf.inset.filled", tint: .pink,
                     footer: "Album art works with Apple Music. Turn on the switch to keep your own preset's left side instead.") {
                    ToggleRow(title: "Use my preset's left side", icon: "person.fill", color: .purple,
                              isOn: $manager.settings.musicLeftUsesMine)
                    if !manager.settings.musicLeftUsesMine {
                        RowDivider()
                        NavigationLink {
                            SlotEditor(title: "Music: left side", slot: $manager.settings.musicLeft, music: true)
                        } label: {
                            SlotNavLabel(title: "Music left side", slot: manager.settings.musicLeft, state: snapshot)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Card(title: "Right side", icon: "rectangle.righthalf.inset.filled", tint: .orange) {
                    ToggleRow(title: "Use my preset's right side", icon: "person.fill", color: .purple,
                              isOn: $manager.settings.musicRightUsesMine)
                    if !manager.settings.musicRightUsesMine {
                        RowDivider()
                        NavigationLink {
                            SlotEditor(title: "Music: right side", slot: $manager.settings.musicRight, music: true)
                        } label: {
                            SlotNavLabel(title: "Music right side", slot: manager.settings.musicRight, state: snapshot)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Card(title: "Minimal bubble", icon: "circle.fill", tint: .blue,
                     footer: "This is what shows when another app shares the island. During music it always stays whatever you chose for your preset.") {
                    NavigationLink {
                        SlotEditor(title: "Minimal bubble", slot: $manager.config.minimal, music: true)
                    } label: {
                        SlotNavLabel(title: "My minimal bubble", slot: manager.config.minimal, state: snapshot)
                    }
                    .buttonStyle(.plain)
                }

                Card(title: "Long-press", icon: "textformat", tint: .teal) {
                    ToggleRow(title: "Show song and artist", icon: "music.mic", color: .teal,
                              isOn: $manager.settings.musicSongTitle)
                }
            }
            .padding(16)
        }
        .background(ThemeBackground())
        .navigationTitle("Music layout")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview(music: true)
    }
}
