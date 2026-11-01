import Foundation

/// Interval used by the break scheduler. Kept as a value type so tests stay
/// free of wall-clock sleeps and UI frameworks.
struct BreakDuration: Equatable, Hashable, Sendable {
    var seconds: TimeInterval

    static func seconds(_ value: TimeInterval) -> BreakDuration {
        BreakDuration(seconds: value)
    }

    static func minutes(_ value: TimeInterval) -> BreakDuration {
        BreakDuration(seconds: value * 60)
    }
}
