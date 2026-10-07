import WidgetKit
import SwiftUI
import ActivityKit
#if canImport(AlarmKit)
import AlarmKit

/// Zobrazení běžícího odpočtu / odloženého budíku na zamčené obrazovce a v Dynamic Islandu.
@available(iOS 26.0, *)
struct AlarmLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<OAAlarmMetadata>.self) { context in
            HStack(spacing: 14) {
                Image(systemName: context.attributes.metadata?.isTimer == true ? "timer" : "alarm")
                    .font(.title2)
                    .foregroundStyle(context.attributes.tintColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.metadata?.label ?? "Osobní agent").font(.headline)
                    AlarmTimeText(mode: context.state.mode).font(.title.monospacedDigit())
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color(red: 0.06, green: 0.09, blue: 0.16))
            .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.attributes.metadata?.isTimer == true ? "timer" : "alarm")
                        .foregroundStyle(context.attributes.tintColor)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.metadata?.label ?? "").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    AlarmTimeText(mode: context.state.mode).monospacedDigit()
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(context.attributes.tintColor)
            } compactTrailing: {
                AlarmTimeText(mode: context.state.mode).monospacedDigit().frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(context.attributes.tintColor)
            }
        }
    }
}

@available(iOS 26.0, *)
struct AlarmTimeText: View {
    var mode: AlarmPresentationState.Mode
    var body: some View {
        switch mode {
        case .countdown(let c):
            Text(timerInterval: Date.now...max(Date.now, c.fireDate), countsDown: true)
        case .paused(let p):
            let left = max(0, p.totalCountdownDuration - p.previouslyElapsedDuration)
            Text(String(format: "%d:%02d", Int(left) / 60, Int(left) % 60))
        case .alert:
            Text("Zvoní")
        @unknown default:
            Text("")
        }
    }
}
#endif
