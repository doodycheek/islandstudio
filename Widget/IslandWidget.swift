import ActivityKit
import SwiftUI
import WidgetKit

@main
struct IslandWidgetBundle: WidgetBundle {
    var body: some Widget {
        IslandLiveActivity()
    }
}

struct IslandLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IslandAttributes.self) { context in
            LockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    SlotView(slot: s.left, state: s, size: 34).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SlotView(slot: s.right, state: s, size: 34).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.expandedTitle)
                        .font(.headline)
                        .fontDesign(s.design)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(s.expandedSubtitle)
                        .font(.subheadline)
                        .fontDesign(s.design)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } compactLeading: {
                SlotView(slot: s.left, state: s, size: 20)
            } compactTrailing: {
                SlotView(slot: s.right, state: s, size: 20)
            } minimal: {
                SlotView(slot: s.minimal, state: s, size: 20)
            }
            .keylineTint(Color(hex: s.keylineHex))
        }
    }
}

struct LockScreenView: View {
    let state: IslandState

    var body: some View {
        HStack(spacing: 12) {
            SlotView(slot: state.left, state: state, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(state.expandedTitle).font(.headline)
                Text(state.expandedSubtitle).font(.caption).foregroundStyle(.secondary)
            }
            .fontDesign(state.design)
            Spacer()
            SlotView(slot: state.right, state: state, size: 30)
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}
