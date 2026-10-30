import PhotosUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: IslandManager
    @AppStorage("previewMode") private var previewMode = PreviewMode.island.rawValue
    @State private var photoItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title, subtitle
    }

    var body: some View {
        NavigationStack {
            Form {
                controlSection
                presetsSection
                layoutSection
                lockScreenSection
                expandedSection
                styleSection
                musicSection
                animationSection
                featuresSection
                photoSection
            }
            .navigationTitle("Island Studio")
            .navigationBarTitleDisplayMode(.inline)
            .pinnedPreview()
            .onChange(of: photoItem) { _, item in
                loadPhoto(item)
            }
            .onChange(of: focusedField) { _, field in
                if field != nil { previewMode = PreviewMode.expanded.rawValue }
            }
        }
    }

    // MARK: Sections

    private var controlSection: some View {
        Section {
            Button {
                toggleRunning()
            } label: {
                Label(manager.isRunning ? "Stop island" : "Start island",
                      systemImage: manager.isRunning ? "stop.fill" : "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(manager.isRunning ? Color.red.gradient : Color.accentColor.gradient)
                    )
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))

            if manager.isRunning {
                Toggle("Pause animations", isOn: $manager.paused)
            }
            Toggle("Keep running in background", isOn: $manager.keepAlive)
        } footer: {
            Text("Background mode keeps animations, live info, pop-outs and the schedule running. Don't swipe the app away in the app switcher.")
        }
    }

    private var presetsSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(PresetStore.builtIns + manager.savedPresets) { preset in
                        PresetTile(preset: preset,
                                   isCurrent: preset.id == manager.settings.currentPresetID,
                                   state: manager.previewState(style: preset.style, at: Date())) {
                            manager.apply(preset)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            NavigationLink {
                SavedPresetsView()
            } label: {
                Label("Save, share & manage presets", systemImage: "square.and.arrow.down.on.square")
            }
        } header: {
            Text("Presets")
        }
    }

    private var layoutSection: some View {
        Section {
            NavigationLink {
                SlotEditor(title: "Left side", slot: $manager.config.left)
            } label: {
                SlotRow(title: "Left side", slot: manager.config.left)
            }
            NavigationLink {
                SlotEditor(title: "Right side", slot: $manager.config.right)
            } label: {
                SlotRow(title: "Right side", slot: manager.config.right)
            }
            NavigationLink {
                SlotEditor(title: "Minimal bubble", slot: $manager.config.minimal)
            } label: {
                SlotRow(title: "Minimal bubble", slot: manager.config.minimal)
            }
        } header: {
            Text("Island layout")
        } footer: {
            Text("The minimal bubble is what shows when another app, like FaceTime, takes the main island.")
        }
    }

    private var lockScreenSection: some View {
        Section {
            Picker("Background", selection: lockBinding(\.lockStyle)) {
                ForEach(LockStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.segmented)
            Toggle("Info chips", isOn: lockBinding(\.lockChips))
            Toggle("Animated accent bar", isOn: lockBinding(\.lockAccent))
        } header: {
            Text("Lock Screen")
        } footer: {
            Text("Tinted uses your outline glow color. Chips show battery and date, plus weather and steps once you've set those up under Live info.")
        }
    }

    private var expandedSection: some View {
        Section {
            TextField("Title", text: $manager.config.expandedTitle)
                .focused($focusedField, equals: .title)
            TextField("Subtitle", text: $manager.config.expandedSubtitle)
                .focused($focusedField, equals: .subtitle)
        } header: {
            Text("Long-press & Lock Screen text")
        }
    }

    private var styleSection: some View {
        Section("Style") {
            Picker("Font", selection: $manager.config.fontDesign) {
                Text("Default").tag("default")
                Text("Rounded").tag("rounded")
                Text("Mono").tag("monospaced")
                Text("Serif").tag("serif")
            }
            Toggle("Bold", isOn: $manager.config.bold)
            ColorPicker("Outline glow & accent", selection: hexBinding(\.keylineHex))
        }
    }

    private var musicSection: some View {
        Section {
            Picker("When music plays", selection: $manager.settings.musicMode) {
                ForEach(MusicMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
        } header: {
            Text("Music")
        } footer: {
            Text(manager.settings.musicMode.explanation)
        }
    }

    private var animationSection: some View {
        Section("Animation") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Step speed")
                    Spacer()
                    Text("\(manager.frameInterval, specifier: "%.1f")s").foregroundStyle(.secondary)
                }
                Slider(value: $manager.frameInterval, in: 0.5...5, step: 0.5)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Ring & bar loop")
                    Spacer()
                    Text("\(manager.cycleLength, specifier: "%.0f")s").foregroundStyle(.secondary)
                }
                Slider(value: $manager.cycleLength, in: 1...10, step: 1)
            }
        }
    }

    private var featuresSection: some View {
        Section("Features") {
            NavigationLink {
                LiveInfoSettingsView()
            } label: {
                Label("Live info", systemImage: "antenna.radiowaves.left.and.right")
            }
            NavigationLink {
                ExtrasView()
            } label: {
                Label("Pop-outs, charging & buttons", systemImage: "rectangle.expand.vertical")
            }
            NavigationLink {
                ScheduleView()
            } label: {
                Label("Auto schedule", systemImage: "clock.badge.checkmark")
            }
        }
    }

    private var photoSection: some View {
        Section {
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Choose a photo", systemImage: "photo.on.rectangle")
            }
            if let data = manager.config.imageData, let ui = UIImage(data: data) {
                HStack {
                    Image(uiImage: ui)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                    Text("\(data.count) bytes").foregroundStyle(.secondary)
                    Spacer()
                    Button("Remove", role: .destructive) {
                        manager.config.imageData = nil
                    }
                }
            }
        } header: {
            Text("My photo")
        } footer: {
            Text("Set any slot to My photo to use it. iOS caps island data at 4 KB, so the photo is shrunk to a tiny icon.")
        }
    }

    // MARK: Helpers

    private func toggleRunning() {
        Task {
            if manager.isRunning {
                await manager.stop()
            } else {
                await manager.start()
            }
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let tiny = ImageCompressor.tinyJPEG(from: data, maxBytes: 1000) {
                manager.config.imageData = tiny
            } else {
                manager.status = "Couldn't shrink that photo enough. Try a simpler image."
            }
        }
    }

    private func hexBinding(_ keyPath: WritableKeyPath<IslandState, String>) -> Binding<Color> {
        Binding(get: { Color(hex: manager.config[keyPath: keyPath]) },
                set: { manager.config[keyPath: keyPath] = $0.hexString })
    }

    /// Lock Screen controls also flip the preview to the Lock Screen tab.
    private func lockBinding<T>(_ keyPath: WritableKeyPath<IslandState, T>) -> Binding<T> {
        Binding(get: { manager.config[keyPath: keyPath] },
                set: {
                    manager.config[keyPath: keyPath] = $0
                    previewMode = PreviewMode.lock.rawValue
                })
    }
}
