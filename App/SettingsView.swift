import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var manager: IslandManager
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument = BackupDocument(data: Data())
    @AppStorage("themeMode") private var themeMode = ThemeMode.system.rawValue
    @AppStorage("accentChoice") private var accentChoice = AccentChoice.purple.rawValue
    @AppStorage("appTheme") private var appThemeName = AppTheme.midnight.rawValue

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    appearanceCard
                    musicCard
                    automationCard
                    dataCard
                    backgroundCard
                    calmCard
                    SoundCard()
                    QuickLinksCard()
                    AccessibilityCard()
                    healthCard
                    backupCard
                    shortcutsCard
                    Text("Island Studio \(version)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .padding(16)
            }
            .background(ThemeBackground())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                          defaultFilename: "IslandStudio-backup") { result in
                switch result {
                case .success:
                    manager.status = "Saved to Files"
                case .failure:
                    manager.status = "Couldn't save the file"
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .plainText]) { result in
                switch result {
                case .success(let url):
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url) {
                        manager.restoreBackup(data: data)
                    } else {
                        manager.status = "Couldn't read that file"
                    }
                case .failure:
                    manager.status = "Couldn't open that file"
                }
            }
        }
    }

    private var appearanceCard: some View {
        Card(title: "Appearance", icon: "paintbrush.pointed.fill", tint: .purple,
             footer: "The first swatch makes the app match your island's accent color.") {
            Text("App theme").font(.system(size: 15, weight: .semibold, design: .rounded))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { pack in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) { appThemeName = pack.rawValue }
                        } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(LinearGradient(colors: [pack.top, pack.bottom], startPoint: .top, endPoint: .bottom))
                                    Image(systemName: pack.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(pack.blobA ?? (pack.isLight ? Color.black : Color.white))
                                }
                                .frame(width: 76, height: 56)
                                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(appThemeName == pack.rawValue ? Color.accentColor : Color.primary.opacity(0.15),
                                                  lineWidth: appThemeName == pack.rawValue ? 2.5 : 1))
                                Text(pack.label).font(.system(size: 12, weight: .semibold, design: .rounded))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            RowDivider()
            Text("App color").font(.subheadline.weight(.medium))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AccentChoice.allCases) { choice in
                        Button {
                            accentChoice = choice.rawValue
                        } label: {
                            Circle()
                                .fill(choice == .island
                                      ? AnyShapeStyle(AngularGradient(colors: [.pink, .orange, .yellow, .green, .cyan, .purple, .pink],
                                                                      center: .center))
                                      : AnyShapeStyle(choice.color.gradient))
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if accentChoice == choice.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(.white)
                                    } else if choice == .island {
                                        Image(systemName: "capsule.fill")
                                            .font(.caption2)
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
    }

    private var musicCard: some View {
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
    }

    private var automationCard: some View {
        Card(title: "Automation", icon: "wand.and.rays", tint: .green,
             footer: "Rules and shuffle swap the look for a while without changing your saved style. Holiday presets switch on once at the start of each holiday, then you're returned to your default.") {
            NavigationLink {
                RulesView()
            } label: {
                NavRowLabel(title: "Rules & shuffle", icon: "wand.and.rays", color: .purple,
                            value: manager.settings.rulesEnabled || manager.settings.shuffleEnabled ? "On" : "Off")
            }
            .buttonStyle(.plain)
            RowDivider()
            NavigationLink {
                ScheduleView()
            } label: {
                NavRowLabel(title: "Auto schedule", icon: "clock.badge.checkmark", color: .green,
                            value: manager.settings.schedule.enabled ? "On" : "Off")
            }
            .buttonStyle(.plain)
            RowDivider()
            ToggleRow(title: "Holiday presets", icon: "gift.fill", color: .red, isOn: $manager.settings.holidayAuto)
            RowDivider()
            ToggleRow(title: "Birthday preset", icon: "birthday.cake.fill", color: .pink,
                      isOn: $manager.settings.birthdayEnabled)
            if manager.settings.birthdayEnabled {
                DatePicker("My birthday", selection: $manager.settings.birthday, displayedComponents: .date)
            }
        }
    }

    private var dataCard: some View {
        Card(title: "Live info & tools", icon: "antenna.radiowaves.left.and.right", tint: .blue) {
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
        }
    }

    private var backgroundCard: some View {
        Card(title: "Background", icon: "bolt.fill", tint: .yellow,
             footer: "Background mode keeps animations, live info, rules, pop-outs and the schedule running. Don't swipe the app away in the app switcher.") {
            ToggleRow(title: "Keep running in background", icon: "arrow.triangle.2.circlepath",
                      color: .yellow, isOn: $manager.keepAlive)
            RowDivider()
            BubbleControls()
            Text("When another app has a Live Activity (like Uber Eats), iOS decides who gets the big spot, and apps can't choose or even see it. It tends to favor whoever updated most recently. This mode updates your island rarely and turns off pop-outs, so the other app takes the big spot. Use the Set Small Bubble Mode action in Shortcuts to switch it on automatically, for example when Uber Eats opens.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func minuteBinding(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.startOfDay(for: Date())
                    .addingTimeInterval(TimeInterval(manager.settings[keyPath: keyPath] * 60))
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                manager.settings[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private var calmCard: some View {
        Card(title: "Quiet hours & recap", icon: "moon.zzz.fill", tint: .indigo,
             footer: "During quiet hours the island stays calm: no pop-outs, alerts or sounds, and it can switch to a quieter preset. The recap is one pop-out in the evening with your day: steps, goal, focus rounds and streak.") {
            ToggleRow(title: "Quiet hours", icon: "moon.zzz.fill", color: .indigo, isOn: $manager.settings.quietEnabled)
            if manager.settings.quietEnabled {
                DatePicker("From", selection: minuteBinding(\.quietStartMinute), displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: minuteBinding(\.quietEndMinute), displayedComponents: .hourAndMinute)
                HStack {
                    Text("Quieter preset")
                    Spacer()
                    Picker("Quieter preset", selection: $manager.settings.quietPresetID) {
                        Text("Keep my preset").tag("")
                        ForEach(manager.allPresets) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
            RowDivider()
            ToggleRow(title: "Daily recap", icon: "chart.bar.doc.horizontal.fill", color: .orange,
                      isOn: $manager.settings.recapEnabled)
            if manager.settings.recapEnabled {
                DatePicker("Show at", selection: minuteBinding(\.recapMinute), displayedComponents: .hourAndMinute)
            }
            RowDivider()
            DatePicker("Bedtime", selection: minuteBinding(\.bedtimeMinute), displayedComponents: .hourAndMinute)
            RowDivider()
            Stepper("Step goal: \(manager.settings.stepsGoal.formatted())", value: $manager.settings.stepsGoal,
                    in: 2000...30000, step: 500)
            RowDivider()
            ToggleRow(title: "Haptic taps", icon: "hand.tap.fill", color: .pink, isOn: $manager.settings.haptics)
        }
    }

    private var healthCard: some View {
        Card(title: "Health check", icon: "stethoscope", tint: .teal,
             footer: "See whether the island is running, which permissions are on, and whether your battery is read exactly.") {
            NavigationLink {
                HealthView()
            } label: {
                NavRowLabel(title: "Open health check", icon: "heart.text.square.fill", color: .teal,
                            value: manager.batteryIsExact ? "Battery exact" : "Battery 5% steps")
            }
            .buttonStyle(.plain)
        }
    }

    private var autoSaveLine: String {
        if let date = manager.lastAutoSave {
            return "Last saved " + date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
        }
        if manager.autoSaveOK == false {
            return "Auto-save isn't available with this signing. Use Save to Files below instead."
        }
        return "Saves a few seconds after each change."
    }

    private var backupCard: some View {
        Card(title: "Save & restore", icon: "externaldrive.fill", tint: .gray,
             footer: "Auto-save keeps a copy in your iPhone's secure storage, which usually survives deleting and re-signing the app if you use the same certificate and bundle ID. If you ever switch certificates, tap Save to Files first. That copy lives outside the app, so it always survives.") {
            ToggleRow(title: "Auto-save my setup", icon: "checkmark.shield.fill", color: .green,
                      isOn: $manager.settings.autoSave)
            Text(autoSaveLine)
                .font(.footnote)
                .foregroundStyle(.secondary)
            RowDivider()
            ToggleRow(title: "Start the island when the app opens", icon: "play.circle.fill", color: .blue,
                      isOn: $manager.settings.autoStart)
            RowDivider()
            HStack(spacing: 10) {
                WideButton(title: "Save to Files", icon: "square.and.arrow.up") {
                    exportDocument = BackupDocument(data: manager.backupData(includeLocation: false) ?? Data())
                    showExporter = true
                }
                WideButton(title: "Restore from file", icon: "folder") {
                    showImporter = true
                }
            }
            HStack(spacing: 10) {
                WideButton(title: "Copy backup", icon: "doc.on.doc") {
                    manager.copyBackup()
                }
                WideButton(title: "Paste backup", icon: "arrow.down.doc") {
                    manager.restoreBackupFromClipboard()
                }
            }
        }
    }

    private var shortcutsCard: some View {
        Card(title: "Shortcuts", icon: "square.stack.3d.up.fill", tint: .indigo) {
            Text("Open the Shortcuts app and search Island Studio for Start Island, Set Island Preset, Next Preset, Surprise, Focus Timer, Add One, music controls, Set Island Text, Clear Island Text and more. Try an automation like: When CarPlay connects → Set Island Preset.")
                .font(.callout)
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

                Card(title: "Long-press", icon: "textformat", tint: .teal,
                     footer: "Tip: add Music play/pause and next buttons under Studio → Expanded → Buttons.") {
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
