import Foundation

struct BreakSettings: Equatable, Sendable {
    var workInterval: BreakDuration
    var breakDuration: BreakDuration

    static let `default` = BreakSettings(
        workInterval: .minutes(50),
        breakDuration: .seconds(90)
    )
}
