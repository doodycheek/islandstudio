import SwiftUI
import UIKit

/// A friendly name for every icon, so you see "Heart (Filled)" instead of "heart.fill".
struct IconEntry: Identifiable, Hashable {
    let symbol: String
    let title: String
    let category: String

    var id: String { symbol }
}

enum IconCatalog {
    private struct Base {
        let symbol: String
        let name: String
        let category: String
        let filled: Bool
    }

    private static let bases: [Base] = [
        // Love & people
        Base(symbol: "heart", name: "Heart", category: "Love & people", filled: true),
        Base(symbol: "heart.circle", name: "Heart in circle", category: "Love & people", filled: true),
        Base(symbol: "face.smiling", name: "Smiley", category: "Love & people", filled: true),
        Base(symbol: "hand.thumbsup", name: "Thumbs up", category: "Love & people", filled: true),
        Base(symbol: "hand.raised", name: "Raised hand", category: "Love & people", filled: true),
        Base(symbol: "hands.clap", name: "Clapping", category: "Love & people", filled: true),
        Base(symbol: "person", name: "Person", category: "Love & people", filled: true),
        Base(symbol: "person.2", name: "Two people", category: "Love & people", filled: true),
        Base(symbol: "eye", name: "Eye", category: "Love & people", filled: true),
        Base(symbol: "brain.head.profile", name: "Brain", category: "Love & people", filled: false),
        Base(symbol: "bubble.left", name: "Chat bubble", category: "Love & people", filled: true),
        Base(symbol: "bell", name: "Bell", category: "Love & people", filled: true),
        Base(symbol: "gift", name: "Gift", category: "Love & people", filled: true),
        Base(symbol: "birthday.cake", name: "Birthday cake", category: "Love & people", filled: true),
        Base(symbol: "crown", name: "Crown", category: "Love & people", filled: true),
        // Sky & nature
        Base(symbol: "sun.max", name: "Sun", category: "Sky & nature", filled: true),
        Base(symbol: "sun.min", name: "Small sun", category: "Sky & nature", filled: true),
        Base(symbol: "moon", name: "Moon", category: "Sky & nature", filled: true),
        Base(symbol: "moon.stars", name: "Moon and stars", category: "Sky & nature", filled: true),
        Base(symbol: "star", name: "Star", category: "Sky & nature", filled: true),
        Base(symbol: "sparkles", name: "Sparkles", category: "Sky & nature", filled: false),
        Base(symbol: "cloud", name: "Cloud", category: "Sky & nature", filled: true),
        Base(symbol: "cloud.rain", name: "Rain", category: "Sky & nature", filled: true),
        Base(symbol: "cloud.snow", name: "Snow", category: "Sky & nature", filled: true),
        Base(symbol: "cloud.bolt", name: "Thunderstorm", category: "Sky & nature", filled: true),
        Base(symbol: "wind", name: "Wind", category: "Sky & nature", filled: false),
        Base(symbol: "snowflake", name: "Snowflake", category: "Sky & nature", filled: false),
        Base(symbol: "drop", name: "Water drop", category: "Sky & nature", filled: true),
        Base(symbol: "flame", name: "Flame", category: "Sky & nature", filled: true),
        Base(symbol: "bolt", name: "Lightning bolt", category: "Sky & nature", filled: true),
        Base(symbol: "leaf", name: "Leaf", category: "Sky & nature", filled: true),
        Base(symbol: "tree", name: "Tree", category: "Sky & nature", filled: true),
        Base(symbol: "pawprint", name: "Paw print", category: "Sky & nature", filled: true),
        Base(symbol: "tortoise", name: "Turtle", category: "Sky & nature", filled: true),
        Base(symbol: "hare", name: "Rabbit", category: "Sky & nature", filled: true),
        Base(symbol: "fish", name: "Fish", category: "Sky & nature", filled: true),
        Base(symbol: "ladybug", name: "Ladybug", category: "Sky & nature", filled: true),
        Base(symbol: "water.waves", name: "Waves", category: "Sky & nature", filled: false),
        Base(symbol: "mountain.2", name: "Mountains", category: "Sky & nature", filled: true),
        Base(symbol: "sunrise", name: "Sunrise", category: "Sky & nature", filled: true),
        Base(symbol: "sunset", name: "Sunset", category: "Sky & nature", filled: true),
        Base(symbol: "rainbow", name: "Rainbow", category: "Sky & nature", filled: false),
        Base(symbol: "umbrella", name: "Umbrella", category: "Sky & nature", filled: true),
        Base(symbol: "thermometer.medium", name: "Thermometer", category: "Sky & nature", filled: false),
        // Music & media
        Base(symbol: "music.note", name: "Music note", category: "Music & media", filled: false),
        Base(symbol: "music.note.list", name: "Playlist", category: "Music & media", filled: false),
        Base(symbol: "headphones", name: "Headphones", category: "Music & media", filled: false),
        Base(symbol: "speaker.wave.2", name: "Speaker", category: "Music & media", filled: true),
        Base(symbol: "mic", name: "Microphone", category: "Music & media", filled: true),
        Base(symbol: "waveform", name: "Sound wave", category: "Music & media", filled: false),
        Base(symbol: "play", name: "Play", category: "Music & media", filled: true),
        Base(symbol: "pause", name: "Pause", category: "Music & media", filled: true),
        Base(symbol: "forward", name: "Skip forward", category: "Music & media", filled: true),
        Base(symbol: "backward", name: "Skip back", category: "Music & media", filled: true),
        Base(symbol: "shuffle", name: "Shuffle", category: "Music & media", filled: false),
        Base(symbol: "repeat", name: "Repeat", category: "Music & media", filled: false),
        Base(symbol: "radio", name: "Radio", category: "Music & media", filled: true),
        Base(symbol: "tv", name: "TV", category: "Music & media", filled: true),
        Base(symbol: "film", name: "Film", category: "Music & media", filled: true),
        Base(symbol: "camera", name: "Camera", category: "Music & media", filled: true),
        Base(symbol: "photo", name: "Photo", category: "Music & media", filled: true),
        Base(symbol: "video", name: "Video", category: "Music & media", filled: true),
        Base(symbol: "gamecontroller", name: "Game controller", category: "Music & media", filled: true),
        Base(symbol: "popcorn", name: "Popcorn", category: "Music & media", filled: true),
        // Travel & places
        Base(symbol: "car", name: "Car", category: "Travel & places", filled: true),
        Base(symbol: "bus", name: "Bus", category: "Travel & places", filled: true),
        Base(symbol: "tram", name: "Tram", category: "Travel & places", filled: true),
        Base(symbol: "airplane", name: "Airplane", category: "Travel & places", filled: false),
        Base(symbol: "bicycle", name: "Bicycle", category: "Travel & places", filled: false),
        Base(symbol: "scooter", name: "Scooter", category: "Travel & places", filled: false),
        Base(symbol: "steeringwheel", name: "Steering wheel", category: "Travel & places", filled: false),
        Base(symbol: "fuelpump", name: "Gas pump", category: "Travel & places", filled: true),
        Base(symbol: "map", name: "Map", category: "Travel & places", filled: true),
        Base(symbol: "location", name: "Location arrow", category: "Travel & places", filled: true),
        Base(symbol: "globe", name: "Globe", category: "Travel & places", filled: false),
        Base(symbol: "safari", name: "Compass", category: "Travel & places", filled: true),
        Base(symbol: "house", name: "House", category: "Travel & places", filled: true),
        Base(symbol: "building.2", name: "Buildings", category: "Travel & places", filled: true),
        Base(symbol: "tent", name: "Tent", category: "Travel & places", filled: true),
        Base(symbol: "suitcase", name: "Suitcase", category: "Travel & places", filled: true),
        Base(symbol: "flag", name: "Flag", category: "Travel & places", filled: true),
        // Tech & tools
        Base(symbol: "iphone", name: "iPhone", category: "Tech & tools", filled: false),
        Base(symbol: "laptopcomputer", name: "Laptop", category: "Tech & tools", filled: false),
        Base(symbol: "keyboard", name: "Keyboard", category: "Tech & tools", filled: true),
        Base(symbol: "wifi", name: "Wi-Fi", category: "Tech & tools", filled: false),
        Base(symbol: "antenna.radiowaves.left.and.right", name: "Signal", category: "Tech & tools", filled: false),
        Base(symbol: "cpu", name: "Chip", category: "Tech & tools", filled: true),
        Base(symbol: "externaldrive", name: "Storage drive", category: "Tech & tools", filled: true),
        Base(symbol: "qrcode", name: "QR code", category: "Tech & tools", filled: false),
        Base(symbol: "lock", name: "Lock", category: "Tech & tools", filled: true),
        Base(symbol: "key", name: "Key", category: "Tech & tools", filled: true),
        Base(symbol: "shield", name: "Shield", category: "Tech & tools", filled: true),
        Base(symbol: "hammer", name: "Hammer", category: "Tech & tools", filled: true),
        Base(symbol: "wrench.and.screwdriver", name: "Tools", category: "Tech & tools", filled: true),
        Base(symbol: "gearshape", name: "Gear", category: "Tech & tools", filled: true),
        Base(symbol: "lightbulb", name: "Light bulb", category: "Tech & tools", filled: true),
        Base(symbol: "powerplug", name: "Power plug", category: "Tech & tools", filled: true),
        Base(symbol: "battery.100", name: "Battery", category: "Tech & tools", filled: false),
        Base(symbol: "bookmark", name: "Bookmark", category: "Tech & tools", filled: true),
        Base(symbol: "tag", name: "Tag", category: "Tech & tools", filled: true),
        Base(symbol: "pin", name: "Pin", category: "Tech & tools", filled: true),
        // Sport, health & time
        Base(symbol: "figure.walk", name: "Walking", category: "Sport, health & time", filled: false),
        Base(symbol: "figure.run", name: "Running", category: "Sport, health & time", filled: false),
        Base(symbol: "figure.yoga", name: "Yoga", category: "Sport, health & time", filled: false),
        Base(symbol: "dumbbell", name: "Dumbbell", category: "Sport, health & time", filled: true),
        Base(symbol: "soccerball", name: "Soccer ball", category: "Sport, health & time", filled: true),
        Base(symbol: "basketball", name: "Basketball", category: "Sport, health & time", filled: true),
        Base(symbol: "trophy", name: "Trophy", category: "Sport, health & time", filled: true),
        Base(symbol: "medal", name: "Medal", category: "Sport, health & time", filled: true),
        Base(symbol: "cross.case", name: "Medical kit", category: "Sport, health & time", filled: true),
        Base(symbol: "pills", name: "Pills", category: "Sport, health & time", filled: true),
        Base(symbol: "bed.double", name: "Bed", category: "Sport, health & time", filled: true),
        Base(symbol: "lungs", name: "Lungs", category: "Sport, health & time", filled: true),
        Base(symbol: "stopwatch", name: "Stopwatch", category: "Sport, health & time", filled: true),
        Base(symbol: "timer", name: "Timer", category: "Sport, health & time", filled: false),
        Base(symbol: "clock", name: "Clock", category: "Sport, health & time", filled: true),
        Base(symbol: "alarm", name: "Alarm clock", category: "Sport, health & time", filled: true),
        Base(symbol: "hourglass", name: "Hourglass", category: "Sport, health & time", filled: false),
        Base(symbol: "calendar", name: "Calendar", category: "Sport, health & time", filled: false),
        // Food & fun
        Base(symbol: "fork.knife", name: "Fork and knife", category: "Food & fun", filled: false),
        Base(symbol: "cup.and.saucer", name: "Coffee cup", category: "Food & fun", filled: true),
        Base(symbol: "wineglass", name: "Wine glass", category: "Food & fun", filled: true),
        Base(symbol: "takeoutbag.and.cup.and.straw", name: "Takeout", category: "Food & fun", filled: true),
        Base(symbol: "party.popper", name: "Party popper", category: "Food & fun", filled: true),
        Base(symbol: "balloon", name: "Balloon", category: "Food & fun", filled: true),
        Base(symbol: "dice", name: "Dice", category: "Food & fun", filled: true),
        Base(symbol: "puzzlepiece", name: "Puzzle piece", category: "Food & fun", filled: true),
        Base(symbol: "paintbrush", name: "Paintbrush", category: "Food & fun", filled: true),
        Base(symbol: "paintpalette", name: "Paint palette", category: "Food & fun", filled: true),
        Base(symbol: "book", name: "Book", category: "Food & fun", filled: true),
        Base(symbol: "graduationcap", name: "Graduation cap", category: "Food & fun", filled: true),
        Base(symbol: "circle", name: "Circle", category: "Food & fun", filled: true),
        Base(symbol: "square", name: "Square", category: "Food & fun", filled: true),
        Base(symbol: "diamond", name: "Diamond", category: "Food & fun", filled: true),
        Base(symbol: "hexagon", name: "Hexagon", category: "Food & fun", filled: true)
    ]

    static let categories: [String] = {
        var seen: [String] = []
        for base in bases where !seen.contains(base.category) { seen.append(base.category) }
        return seen
    }()

    /// Only icons that exist on this iPhone's iOS.
    static let all: [IconEntry] = {
        var list: [IconEntry] = []
        for base in bases {
            if base.filled {
                if UIImage(systemName: base.symbol + ".fill") != nil {
                    list.append(IconEntry(symbol: base.symbol + ".fill", title: base.name + " (Filled)", category: base.category))
                }
                if UIImage(systemName: base.symbol) != nil {
                    list.append(IconEntry(symbol: base.symbol, title: base.name + " (Outline)", category: base.category))
                }
            } else if UIImage(systemName: base.symbol) != nil {
                list.append(IconEntry(symbol: base.symbol, title: base.name, category: base.category))
            }
        }
        return list
    }()

    private static let lookup: [String: String] = {
        var map: [String: String] = [:]
        for entry in all { map[entry.symbol] = entry.title }
        return map
    }()

    /// "heart.fill" becomes "Heart (Filled)". Unknown names get a tidy automatic title.
    static func title(for symbol: String) -> String {
        if symbol.isEmpty { return "No icon" }
        if let found = lookup[symbol] { return found }
        var parts = symbol.split(separator: ".").map { String($0) }
        var suffix = ""
        if parts.last == "fill" {
            parts.removeLast()
            suffix = " (Filled)"
        }
        let words = parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }
        return words.joined(separator: " ") + suffix
    }

    static func recents() -> [String] {
        UserDefaults.standard.stringArray(forKey: "recentIcons") ?? []
    }

    static func remember(_ symbol: String) {
        guard !symbol.isEmpty else { return }
        var list = recents().filter { $0 != symbol }
        list.insert(symbol, at: 0)
        UserDefaults.standard.set(Array(list.prefix(12)), forKey: "recentIcons")
    }
}

/// Browse every icon by name, with search, categories, recents and a filled/outline switch.
struct IconPickerView: View {
    @Binding var symbol: String
    var allowNone = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeAccent) private var accent
    @State private var search = ""
    @State private var category = "All"
    @State private var recent: [String] = IconCatalog.recents()

    private let columns = [GridItem(.adaptive(minimum: 78), spacing: 10)]

    private var filtered: [IconEntry] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return IconCatalog.all.filter { entry in
            (category == "All" || entry.category == category)
                && (query.isEmpty || entry.title.lowercased().contains(query) || entry.symbol.contains(query))
        }
    }

    private var base: String {
        symbol.hasSuffix(".fill") ? String(symbol.dropLast(5)) : symbol
    }

    private var canToggleFill: Bool {
        !symbol.isEmpty && UIImage(systemName: base) != nil && UIImage(systemName: base + ".fill") != nil
    }

    private var filledBinding: Binding<Bool> {
        Binding(get: { symbol.hasSuffix(".fill") },
                set: { symbol = $0 ? base + ".fill" : base })
    }

    private func choose(_ name: String) {
        symbol = name
        IconCatalog.remember(name)
        recent = IconCatalog.recents()
    }

    private func cell(_ entry: IconEntry) -> some View {
        Button {
            choose(entry.symbol)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: entry.symbol)
                    .font(.title2)
                    .frame(height: 30)
                Text(entry.title)
                    .font(.caption2)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .padding(4)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(symbol == entry.symbol ? accent.opacity(0.25) : Color(.tertiarySystemFill)))
            .foregroundStyle(symbol == entry.symbol ? accent : Color.primary)
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: symbol.isEmpty ? "nosign" : symbol)
                            .font(.largeTitle)
                            .frame(width: 56, height: 56)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(accent.opacity(0.2)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(IconCatalog.title(for: symbol)).font(.headline)
                            Text("Your current icon").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    if canToggleFill {
                        Toggle("Filled", isOn: filledBinding)
                    }
                    if allowNone {
                        Button {
                            choose("")
                        } label: {
                            Label("No icon", systemImage: "nosign")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", selected: category == "All") { category = "All" }
                            ForEach(IconCatalog.categories, id: \.self) { name in
                                FilterChip(title: name, selected: category == name) { category = name }
                            }
                        }
                    }
                    if !recent.isEmpty && search.isEmpty && category == "All" {
                        Text("Recent").font(.subheadline.weight(.semibold))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(recent, id: \.self) { name in
                                    Button {
                                        choose(name)
                                    } label: {
                                        Image(systemName: name)
                                            .font(.title3)
                                            .frame(width: 44, height: 44)
                                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(symbol == name ? accent.opacity(0.25) : Color(.tertiarySystemFill)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filtered) { entry in
                            cell(entry)
                        }
                    }
                    if filtered.isEmpty {
                        Text("No icons match that.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 24)
                    }
                }
                .padding(16)
            }
            .searchable(text: $search, prompt: "Search icons by name")
            .navigationTitle("Choose an icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
