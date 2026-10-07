import Foundation
#if canImport(AlarmKit)
import AlarmKit
#endif

/// Metadata budíku sdílená aplikací a widgetem (Live Activity odpočtu).
/// Obsahuje jen popisek – žádná další data.
#if canImport(AlarmKit)
@available(iOS 26.0, *)
struct OAAlarmMetadata: AlarmMetadata {
    var label: String
    var isTimer: Bool
}
#endif
