import PhotosUI
import SwiftUI

/// Setup for the tool and data slots: counter, focus timer, days counter, crypto, world clock, messages.
struct ToolsView: View {
    @EnvironmentObject var manager: IslandManager
    @State private var slideItems: [PhotosPickerItem] = []

    private let zones: [(id: String, name: String)] = [
        ("Pacific/Honolulu", "Honolulu"), ("America/Los_Angeles", "Los Angeles"), ("America/Denver", "Denver"),
        ("America/Chicago", "Chicago"), ("America/New_York", "New York"), ("America/Sao_Paulo", "São Paulo"),
        ("Europe/London", "London"), ("Europe/Paris", "Paris"), ("Europe/Moscow", "Moscow"),
        ("Asia/Dubai", "Dubai"), ("Asia/Kolkata", "Mumbai"), ("Asia/Bangkok", "Bangkok"),
        ("Asia/Shanghai", "Shanghai"), ("Asia/Tokyo", "Tokyo"), ("Asia/Seoul", "Seoul"),
        ("Australia/Sydney", "Sydney"), ("Pacific/Auckland", "Auckland")
    ]

    private var goalText: String {
        manager.settings.counterGoal == 0 ? "none" : "\(manager.settings.counterGoal)"
    }

    private var timerText: String {
        switch manager.settings.pomoPhase {
        case "focus": return "Focusing"
        case "break": return "On a break"
        default: return "Not running"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                counterCard
                focusCard
                daysCard
                cryptoCard
                worldCard
                messagesCard
                slideshowCard
            }
            .padding(16)
        }
        .background(ThemeBackground())
        .navigationTitle("Tools")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
    }

    private var counterCard: some View {
        Card(title: "Tap counter", icon: "plus.circle.fill", tint: .blue,
             footer: "Set a slot to Tap counter, then long-press the island to use + and −. With a goal it shows like 3/8 and pops out when you reach it.") {
            HStack {
                Text("Count")
                Spacer()
                Text("\(manager.settings.counter)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            RowDivider()
            Stepper("Goal: \(goalText)", value: $manager.settings.counterGoal, in: 0...50)
            RowDivider()
            HStack {
                Text("Goal streak")
                Spacer()
                Text("\(manager.settings.streak) days 🔥").foregroundStyle(.secondary)
            }
            RowDivider()
            ToggleRow(title: "Reset every day", icon: "sunrise.fill", color: .orange,
                      isOn: $manager.settings.counterResetsDaily)
            RowDivider()
            Button {
                manager.settings.counter = 0
            } label: {
                Label("Reset count", systemImage: "arrow.counterclockwise")
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var focusCard: some View {
        Card(title: "Focus timer", icon: "timer", tint: .red,
             footer: "Set a slot to Focus timer. It runs focus and break rounds back to back and pops out at each switch.") {
            Stepper("Focus: \(manager.settings.focusMinutes) min", value: $manager.settings.focusMinutes,
                    in: 5...90, step: 5)
            RowDivider()
            Stepper("Break: \(manager.settings.breakMinutes) min", value: $manager.settings.breakMinutes,
                    in: 1...30)
            RowDivider()
            HStack {
                Text(timerText).foregroundStyle(.secondary)
                Spacer()
                Button {
                    manager.togglePomodoro()
                } label: {
                    Label(manager.settings.pomoPhase.isEmpty ? "Start" : "Stop",
                          systemImage: manager.settings.pomoPhase.isEmpty ? "play.fill" : "stop.fill")
                        .font(.subheadline.weight(.semibold))
                }
            }
        }
    }

    private var daysCard: some View {
        Card(title: "Days counter", icon: "calendar.badge.clock", tint: .pink,
             footer: "Set a slot to Days counter. Type an emoji like 💜 in its text box to show next to the number.") {
            DatePicker("Days since", selection: $manager.settings.daysSince,
                       in: ...Date(), displayedComponents: .date)
        }
    }

    private var cryptoCard: some View {
        Card(title: "Crypto price", icon: "bitcoinsign.circle.fill", tint: .orange,
             footer: "Price and 24-hour change from CoinGecko, refreshed every minute while a crypto slot is showing. The Live color mode turns it green or red.") {
            HStack {
                Text("Coin")
                Spacer()
                Picker("Coin", selection: $manager.settings.cryptoCoin) {
                    ForEach(CryptoService.symbols, id: \.self) { symbol in
                        Text(symbol).tag(symbol)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            RowDivider()
            HStack {
                Text("Price now")
                Spacer()
                Text(CryptoFormat.price(manager.info.cryptoPrice)).foregroundStyle(.secondary)
            }
        }
    }

    private var worldCard: some View {
        Card(title: "World clock", icon: "globe", tint: .teal,
             footer: "Set a slot to World clock. Add a flag or city name in its text box.") {
            HStack {
                Text("City")
                Spacer()
                Picker("City", selection: $manager.settings.worldTZ) {
                    ForEach(zones, id: \.id) { zone in
                        Text(zone.name).tag(zone.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var slideshowCard: some View {
        Card(title: "Photo slideshow", icon: "photo.stack", tint: .green,
             footer: "Pick up to 4 photos, then set a slot to Photo slideshow and they take turns. Each one is shrunk to a tiny icon to fit iOS's limit.") {
            PhotosPicker(selection: $slideItems, maxSelectionCount: 4, matching: .images) {
                Label(manager.settings.slideshowPhotos.isEmpty ? "Choose photos" : "Change photos",
                      systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline.weight(.semibold))
            }
            if !manager.settings.slideshowPhotos.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(manager.settings.slideshowPhotos.enumerated()), id: \.offset) { item in
                        if let ui = UIImage(data: item.element) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    Spacer()
                    Button("Clear", role: .destructive) {
                        manager.setSlideshowPhotos([])
                    }
                    .font(.subheadline)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Change every")
                    Spacer()
                    Text("\(manager.settings.slideSeconds, specifier: "%.0f")s").foregroundStyle(.secondary)
                }
                GlowSlider(value: $manager.settings.slideSeconds, in: 1...10, step: 1)
            }
        }
        .onChange(of: slideItems) { _, items in
            loadSlides(items)
        }
    }

    private func loadSlides(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var photos: [Data] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let tiny = ImageCompressor.tinyJPEG(from: data, maxBytes: 700) {
                    photos.append(tiny)
                }
            }
            manager.setSlideshowPhotos(photos)
        }
    }

    private var messagesCard: some View {
        Card(title: "Rotating messages", icon: "text.bubble.fill", tint: .purple,
             footer: "One message per line. Set a slot to Rotating messages and they scroll by in turn.") {
            TextEditor(text: $manager.settings.messagesText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .cardField()
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Change every")
                    Spacer()
                    Text("\(manager.settings.messageSeconds, specifier: "%.0f")s").foregroundStyle(.secondary)
                }
                GlowSlider(value: $manager.settings.messageSeconds, in: 2...12, step: 1)
            }
        }
    }
}
