import Foundation

enum BreakVerificationStatus: Equatable, Sendable {
    case waitingToStart
    case pendingMovement
    case capturing
    case standingDetected
    case permissionDenied
    case cameraUnavailable
    case verified
}

enum BreakOverlayAction: Equatable, Sendable {
    case startOrComplete
    case skip
    case postpone15
    case quit
}

struct BreakOverlayModel: Equatable, Sendable {
    var headline: String
    var subheadline: String
    var primaryActionTitle: String
    var secondaryActionTitle: String
    var escapeHint: String
    var verificationText: String
    var showsVerificationSlot: Bool
    var verificationStatus: BreakVerificationStatus

    static let accessibilityActions: [BreakOverlayAction] = [
        .startOrComplete,
        .skip,
        .postpone15,
        .quit,
    ]

    static func shouldPresent(phase: BreakPhase) -> Bool {
        switch phase {
        case .breakDue, .onBreak:
            return true
        case .idle, .working, .postponed, .deferredForPresentation, .paused:
            return false
        }
    }

    static func due(
        sittingSeconds: TimeInterval,
        breakDuration: BreakDuration,
        verificationStatus: BreakVerificationStatus
    ) -> BreakOverlayModel {
        let minutes = max(1, Int((sittingSeconds / 60).rounded()))
        return BreakOverlayModel(
            headline: "You've been sitting for \(minutes) minutes.",
            subheadline: "Move your ass.",
            primaryActionTitle: "Start \(Int(breakDuration.seconds))s break",
            secondaryActionTitle: "Skip for now",
            escapeHint: "Esc postpones 15 minutes · ⌘Q quits Unchair",
            verificationText: "Movement verification: waiting",
            showsVerificationSlot: true,
            verificationStatus: verificationStatus
        )
    }

    static func active(
        remaining: BreakDuration,
        verificationStatus: BreakVerificationStatus
    ) -> BreakOverlayModel {
        let seconds = Int(remaining.seconds.rounded())
        let verificationText: String
        switch verificationStatus {
        case .waitingToStart:
            verificationText = "Movement verification: waiting"
        case .pendingMovement:
            verificationText = "Movement verification: pending"
        case .capturing:
            verificationText = "Camera on · frames stay in memory"
        case .standingDetected:
            verificationText = "Standing detected · keep moving"
        case .permissionDenied:
            verificationText = "Camera permission denied · break still counts if you move"
        case .cameraUnavailable:
            verificationText = "Camera unavailable · break still counts if you move"
        case .verified:
            verificationText = "Movement verification: done"
        }

        return BreakOverlayModel(
            headline: "Break in progress",
            subheadline: "\(seconds)s left. Stand up. Move.",
            primaryActionTitle: "Mark complete",
            secondaryActionTitle: "Skip for now",
            escapeHint: "Esc postpones 15 minutes · ⌘Q quits Unchair",
            verificationText: verificationText,
            showsVerificationSlot: true,
            verificationStatus: verificationStatus
        )
    }
}
