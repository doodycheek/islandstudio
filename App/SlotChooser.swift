import SwiftUI

/// A gallery of everything a slot can show, with a live mini preview on each tile.
struct SlotChooserSheet: View {
    @EnvironmentObject var manager: IslandManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.themeAccent) private var accent
    @Environment(\.appTheme) private var theme
    @Binding var selection: SlotContent
    let base: SlotConfig
    @State private var search = ""
    @State private var category: SlotCategory? = nil

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    private var items: [SlotContent] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return SlotContent.allCases.filter { item in
            (category == nil || item.category == category)
                && (query.isEmpty || item.label.lowercased().contains(query))
        }
    }

    private func tile(_ item: SlotContent, snapshot: IslandState) -> some View {
        var sample = base
        sample.content = item
        sample.rotate = []
        sample.showWhen = ""
        if sample.text.isEmpty && item.usesText { sample.text = "Hi" }
        let selected = selection == item
        return Button {
            selection = item
            Haptics.tap()
            dismiss()
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    Capsule().fill(Color.black)
                    SlotView(slot: sample, state: snapshot, size: 22, decorated: false)
                        .frame(maxWidth: 92)
                        .clipped()
                }
                .frame(height: 40)
                Text(item.label)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(GlassBackground(radius: 20, theme: theme, tint: selected ? accent : Color.clear))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(selected ? accent : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    var body: some View {
        let snapshot = manager.previewState(at: Date())
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", selected: category == nil) { category = nil }
                            ForEach(SlotCategory.allCases) { entry in
                                FilterChip(title: entry.title, selected: category == entry) { category = entry }
                            }
                        }
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { item in
                            tile(item, snapshot: snapshot)
                        }
                    }
                    if items.isEmpty {
                        Text("Nothing matches that.")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 30)
                    }
                }
                .padding(16)
            }
            .background(ThemeBackground())
            .searchable(text: $search, prompt: "Search what it can show")
            .navigationTitle("What should it show?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
