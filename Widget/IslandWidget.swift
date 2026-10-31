import ActivityKit
import SwiftUI
import WidgetKit

@main
struct IslandWidgetBundle: WidgetBundle {
    var body: some Widget {
        IslandLiveActivity()
        IslandClockWidget()
        IslandBatteryWidget()
        IslandDaysWidget()
        IslandMoonWidget()
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
                    SlotView(slot: s.left, state: s, size: s.expandedSlotSize)
                        .islandPanel(s)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    SlotView(slot: s.right, state: s, size: s.expandedSlotSize)
                        .islandPanel(s)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedTitle(state: s)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottom(state: s)
                }
            } compactLeading: {
                CompactSlot(slot: s.left, state: s)
            } compactTrailing: {
                CompactSlot(slot: s.right, state: s)
            } minimal: {
                CompactSlot(slot: s.minimal, state: s, minimal: true)
            }
            .keylineTint(Color(hex: s.keylineHex))
        }
    }
}
