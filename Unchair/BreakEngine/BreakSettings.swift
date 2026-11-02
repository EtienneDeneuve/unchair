import Foundation

struct BreakSettings: Equatable, Sendable {
    var workInterval: BreakDuration
    var breakDuration: BreakDuration
    /// Pause sitting + work clocks after this much HID idle (unlocked Mac).
    /// `.seconds(0)` disables idle freeze (sleep/lock still freeze).
    var idleFreezeAfter: BreakDuration = .minutes(5)

    static let `default` = BreakSettings(
        workInterval: .minutes(50),
        breakDuration: .seconds(90),
        idleFreezeAfter: .minutes(5)
    )
}
