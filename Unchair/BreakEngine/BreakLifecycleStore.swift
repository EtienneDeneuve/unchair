import Foundation

/// Restorable scheduler state. Never includes an active camera / on-break session —
/// a mid-break quit restores as `.breakDue` so the overlay can resume without
/// resurrecting a stale capture session (issue #7).
struct BreakPersistedState: Equatable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case working
        case breakDue
        case postponed
        case deferredForPresentation
        case paused
    }

    var kind: Kind
    var until: Date?
    var pendingSince: Date?
    var remainingWhenPaused: TimeInterval?
    var sittingStartedAt: Date?
    var hasMovementDebt: Bool
    /// Full accrual state when available; older saves may omit this.
    var movementDebt: MovementDebtState?
    var breakID: UUID?
    var workIntervalSeconds: TimeInterval
    var breakDurationSeconds: TimeInterval
}

protocol BreakLifecycleStoring: AnyObject {
    func load() -> BreakPersistedState?
    func save(_ state: BreakPersistedState)
    func clear()
}

final class UserDefaultsBreakLifecycleStore: BreakLifecycleStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "unchair.breakLifecycle.v1") {
        self.defaults = defaults
        self.key = key
    }

    func load() -> BreakPersistedState? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(BreakPersistedState.self, from: data)
    }

    func save(_ state: BreakPersistedState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

final class InMemoryBreakLifecycleStore: BreakLifecycleStoring {
    private var state: BreakPersistedState?

    func load() -> BreakPersistedState? { state }

    func save(_ state: BreakPersistedState) { self.state = state }

    func clear() { state = nil }
}
