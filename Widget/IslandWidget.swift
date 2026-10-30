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
                .activityBackgroundTint(context.state.lockBackground)
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
                    ExpandedTitle(state: s)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(state: s)
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
