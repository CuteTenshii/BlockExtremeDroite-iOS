import ActivityKit
import SwiftUI
import WidgetKit

@main
struct LiveActivityBundle: WidgetBundle {
    var body: some Widget { BlockLiveActivity() }
}

struct BlockLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BlockAttributes.self) { context in
            ProgressSummary(platform: context.attributes.platform, state: context.state)
                .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.platform).font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(.liveBlocked(context.state.blocked)).font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressSummary(platform: nil, state: context.state)
                }
            } compactLeading: {
                Image(systemName: "hand.raised.fill")
            } compactTrailing: {
                Text("\(context.state.blocked)")
            } minimal: {
                Image(systemName: "hand.raised.fill")
            }
        }
    }
}

private struct ProgressSummary: View {
    let platform: String?
    let state: BlockAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let platform {
                HStack {
                    Text(platform).font(.headline)
                    Spacer()
                    Text(.liveBlocked(state.blocked)).font(.headline)
                }
            }
            if state.isFinished {
                Text(.liveFinished).foregroundStyle(.secondary)
            } else if let current = state.current {
                Text(current).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text(.liveWorking).foregroundStyle(.secondary)
            }
            if let cap = state.cap {
                ProgressBar(fraction: Double(min(state.blocked, cap)) / Double(cap))
            }
        }
    }
}

/// Drawn by hand because the system bar's empty track is nearly black on the activity's dark card.
private struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.25))
                Capsule().fill(.primary).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 8)
    }
}
