import PhotosUI
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: IslandManager
    @State private var photoItem: PhotosPickerItem?

    private let quickSymbols = ["star.fill", "heart.fill", "bolt.fill", "flame.fill", "moon.fill",
                                "sparkles", "music.note", "car.fill", "gamecontroller.fill",
                                "leaf.fill", "crown.fill", "circle.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                        IslandPreview(state: manager.previewState(at: ctx.date))
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Preview")
                }

                Section {
                    if manager.isRunning {
                        Button(role: .destructive) {
                            Task { await manager.stop() }
                        } label: {
                            Label("Stop island", systemImage: "stop.fill")
                        }
                    } else {
                        Button {
                            Task { await manager.start() }
                        } label: {
                            Label("Start island", systemImage: "play.fill")
                        }
                    }
                    Toggle("Keep running in background", isOn: $manager.keepAlive)
                    VStack(alignment: .leading) {
                        Text("Animation step: \(manager.frameInterval, specifier: "%.1f")s")
                        Slider(value: $manager.frameInterval, in: 0.5...5, step: 0.5)
                    }
                    VStack(alignment: .leading) {
                        Text("Ring/bar loop length: \(manager.cycleLength, specifier: "%.0f")s")
                        Slider(value: $manager.cycleLength, in: 1...10, step: 1)
                    }
                    if !manager.status.isEmpty {
                        Text(manager.status).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Island")
                } footer: {
                    Text("Background mode keeps animations looping and renews the island before iOS's 8-hour limit. Don't swipe the app away in the app switcher.")
                }

                Section("Presets") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(IslandPreset.all) { p in
                                Button { apply(p) } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: p.icon).font(.title2)
                                        Text(p.name).font(.caption)
                                    }
                                    .frame(width: 84, height: 70)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                SlotEditor(title: "Left side", slot: $manager.config.left, quickSymbols: quickSymbols)
                SlotEditor(title: "Right side", slot: $manager.config.right, quickSymbols: quickSymbols)
                SlotEditor(title: "Minimal (when another app shares the island)",
                           slot: $manager.config.minimal, quickSymbols: quickSymbols)

                Section("Long-press view") {
                    TextField("Title", text: $manager.config.expandedTitle)
                    TextField("Subtitle", text: $manager.config.expandedSubtitle)
                }

                Section("Style") {
                    Picker("Font", selection: $manager.config.fontDesign) {
                        Text("Default").tag("default")
                        Text("Rounded").tag("rounded")
                        Text("Mono").tag("monospaced")
                        Text("Serif").tag("serif")
                    }
                    Toggle("Bold", isOn: $manager.config.bold)
                    ColorPicker("Outline glow", selection: hexBinding(\.keylineHex))
                }

                Section {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Choose a photo", systemImage: "photo.on.rectangle")
                    }
                    if let data = manager.config.imageData, let ui = UIImage(data: data) {
                        HStack {
                            Image(uiImage: ui).resizable().frame(width: 40, height: 40).clipShape(Circle())
                            Text("\(data.count) bytes").foregroundStyle(.secondary)
                            Spacer()
                            Button("Remove", role: .destructive) { manager.config.imageData = nil }
                        }
                    }
                } header: {
                    Text("My photo")
                } footer: {
                    Text("Set any slot to “My photo” to use it. iOS caps island data at 4 KB, so the photo is shrunk to a tiny icon.")
                }
            }
            .navigationTitle("Island Studio")
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let tiny = ImageCompressor.tinyJPEG(from: data) {
                        manager.config.imageData = tiny
                    } else {
                        manager.status = "Couldn't shrink that photo enough. Try a simpler image."
                    }
                }
            }
        }
    }

    private func apply(_ p: IslandPreset) {
        var s = p.build()
        s.imageData = manager.config.imageData
        manager.config = s
    }

    private func hexBinding(_ kp: WritableKeyPath<IslandState, String>) -> Binding<Color> {
        Binding(get: { Color(hex: manager.config[keyPath: kp]) },
                set: { manager.config[keyPath: kp] = $0.hexString })
    }
}

struct SlotEditor: View {
    let title: String
    @Binding var slot: SlotConfig
    let quickSymbols: [String]

    var body: some View {
        Section(title) {
            Picker("Show", selection: $slot.content) {
                ForEach(SlotContent.allCases) { c in
                    Text(c.label).tag(c)
                }
            }
            if slot.content.usesText {
                TextField(slot.content == .emoji ? "Emoji" : "Text", text: $slot.text)
            }
            if slot.content.usesSymbol {
                TextField("SF Symbol name", text: $slot.symbol)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(quickSymbols, id: \.self) { name in
                            Button { slot.symbol = name } label: {
                                Image(systemName: name)
                                    .font(.title3)
                                    .foregroundStyle(slot.symbol == name ? Color.accentColor : Color.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            if slot.content.usesColor {
                ColorPicker("Color", selection: Binding(get: { Color(hex: slot.colorHex) },
                                                        set: { slot.colorHex = $0.hexString }))
            }
        }
    }
}

struct IslandPreview: View {
    let state: IslandState

    var body: some View {
        HStack(spacing: 0) {
            SlotView(slot: state.left, state: state, size: 20)
                .frame(width: 72, alignment: .leading)
            Spacer(minLength: 90)
            SlotView(slot: state.right, state: state, size: 20)
                .frame(width: 72, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .frame(width: 300, height: 38)
        .background(Capsule().fill(Color.black))
        .overlay(Capsule().strokeBorder(Color(hex: state.keylineHex).opacity(0.5), lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .padding(.vertical, 8)
    }
}
