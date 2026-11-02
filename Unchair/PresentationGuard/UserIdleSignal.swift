import CoreGraphics
import Foundation

protocol UserIdleInspecting: AnyObject {
    /// Seconds since the last HID input in the login session (keyboard/mouse/trackpad).
    var idleSeconds: TimeInterval { get }
}

/// Session-wide idle via CoreGraphics — no Accessibility / Screen Recording permission.
final class CGEventUserIdleInspector: UserIdleInspecting {
    var idleSeconds: TimeInterval {
        // kCGAnyInputEventType == ~0 — any keyboard/mouse/tablet event.
        let anyInput = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}

final class ControllableUserIdleInspector: UserIdleInspecting {
    var idleSeconds: TimeInterval = 0
}
