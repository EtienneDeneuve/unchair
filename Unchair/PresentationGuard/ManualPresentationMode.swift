import Foundation

/// Explicit user-controlled Presentation Mode (menu bar).
///
/// Suspends overlays and camera until the end condition clears.
final class ManualPresentationMode: PresentationSignalSource {
    enum EndCondition: Equatable, Sendable {
        case until(Date)
        case untilDisabled
    }

    private let clock: BreakClock
    private(set) var endCondition: EndCondition?

    var reason: PresentationBlockReason { .manualPresentationMode }

    var isActive: Bool {
        guard let endCondition else { return false }
        switch endCondition {
        case .until(let date):
            return clock.now < date
        case .untilDisabled:
            return true
        }
    }

    /// Presets exposed in the menu bar (issue #13).
    static let durationPresets: [BreakDuration] = [
        .minutes(30),
        .minutes(45),
        .minutes(60),
    ]

    init(clock: BreakClock) {
        self.clock = clock
    }

    func enable(for duration: BreakDuration) {
        endCondition = .until(clock.now.addingTimeInterval(duration.seconds))
    }

    func enable(until date: Date) {
        endCondition = .until(date)
    }

    func enableUntilDisabled() {
        endCondition = .untilDisabled
    }

    func disable() {
        endCondition = nil
    }

    /// Drop expired timed mode so UI reflects reality.
    func tick() {
        guard case .until(let date) = endCondition, clock.now >= date else { return }
        endCondition = nil
    }
}
