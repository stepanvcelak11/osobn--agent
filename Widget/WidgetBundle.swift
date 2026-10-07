import WidgetKit
import SwiftUI

@main
struct OsobniAgentWidgets: WidgetBundle {
    var body: some Widget {
        QuickCaptureWidget()
        if #available(iOS 26.0, *) {
            AlarmLiveActivity()
        }
    }
}
