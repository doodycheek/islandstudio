import SwiftUI

/// "If this, then that" rules plus shuffle mode.
struct RulesView: View {
    @EnvironmentObject var manager: IslandManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card(title: "Rules", icon: "wand.and.rays", tint: .purple,
                     footer: "Rules swap your island's look while something is true, then switch back. They never change your saved style. The first matching rule wins, top to bottom.") {
                    ToggleRow(title: "Use rules", icon: "power", color: .purple, isOn: $manager.settings.rulesEnabled)
                    if !manager.takeoverLabel.isEmpty {
                        Text("Right now: \(manager.takeoverLabel)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach($manager.settings.rules) { $rule in
                    let ruleID = rule.id
                    RuleCard(rule: $rule, presets: manager.allPresets) {
                        manager.settings.rules.removeAll { $0.id == ruleID }
                    }
                    .opacity(manager.settings.rulesEnabled ? 1 : 0.55)
                }

                Button {
                    manager.settings.rules.append(IslandRule())
                    manager.settings.rulesEnabled = true
                } label: {
                    Label("Add a rule", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial))
                }
                .buttonStyle(.plain)

                Card(title: "Shuffle", icon: "shuffle", tint: .orange,
                     footer: "Shows a different preset every so often. Rules still win while they match.") {
                    ToggleRow(title: "Shuffle presets", icon: "shuffle", color: .orange,
                              isOn: $manager.settings.shuffleEnabled)
                    RowDivider()
                    Stepper("Every \(manager.settings.shuffleMinutes) min",
                            value: $manager.settings.shuffleMinutes, in: 5...240, step: 5)
                    RowDivider()
                    Picker("From", selection: $manager.settings.shuffleSource) {
                        Text("All").tag("all")
                        Text("Favorites").tag("favorites")
                        Text("Mine").tag("mine")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(16)
        }
        .background(ThemeBackground())
        .navigationTitle("Rules & shuffle")
        .navigationBarTitleDisplayMode(.inline)
        .pinnedPreview()
    }
}

struct RuleCard: View {
    @Binding var rule: IslandRule
    let presets: [SavedPreset]
    let onDelete: () -> Void

    var body: some View {
        Card(title: rule.kind.label, icon: rule.kind.icon, tint: .blue) {
            ToggleRow(title: "Rule on", icon: "checkmark", color: .green, isOn: $rule.enabled)
            RowDivider()
            HStack {
                Text("When")
                Spacer()
                Picker("When", selection: $rule.kind) {
                    ForEach(RuleKind.allCases) { kind in
                        Label(kind.label, systemImage: kind.icon).tag(kind)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            if let label = rule.kind.numberLabel {
                RowDivider()
                Stepper("\(label) \(rule.number)\(rule.kind.numberUnit)", value: $rule.number,
                        in: rule.kind.numberRange, step: rule.kind == .batteryBelow ? 5 : 1)
            }
            if rule.kind == .timeRange {
                RowDivider()
                DatePicker("From", selection: minuteBinding($rule.startMinute), displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: minuteBinding($rule.endMinute), displayedComponents: .hourAndMinute)
            }
            RowDivider()
            HStack {
                Text("Show")
                Spacer()
                Picker("Show", selection: $rule.presetID) {
                    ForEach(presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            RowDivider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete rule", systemImage: "trash")
                    .font(.subheadline.weight(.semibold))
            }
        }
        .onChange(of: rule.kind) { _, kind in
            switch kind {
            case .batteryBelow: rule.number = 20
            case .hot: rule.number = 85
            case .cold: rule.number = 45
            default: break
            }
        }
    }

    private func minuteBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.startOfDay(for: Date()).addingTimeInterval(TimeInterval(minutes.wrappedValue * 60))
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}
