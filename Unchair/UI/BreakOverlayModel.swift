import Foundation

enum BreakVerificationStatus: Equatable, Sendable {
    case waitingToStart
    case pendingMovement
    case capturing
    case standingDetected
    case permissionDenied
    case cameraBusy
    case cameraUnavailable
    /// User chose reminders-only; camera stays off for this break.
    case verificationOptedOut
    case verified
}

enum BreakOverlayAction: Equatable, Sendable {
    case startOrComplete
    case skip
    case postpone15
    case openCameraSettings
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
    /// Live camera preview while the timed break is running (not on the due prompt).
    var showsCameraPreview: Bool
    var verificationStatus: BreakVerificationStatus
    var isPrimaryEnabled: Bool
    /// Optional recovery CTA (System Settings / Camera pane) for fail-open paths.
    var recoveryActionTitle: String?

    static let accessibilityActions: [BreakOverlayAction] = [
        .startOrComplete,
        .skip,
        .postpone15,
        .openCameraSettings,
        .quit,
    ]

    /// Combined VoiceOver announcement for the status block.
    var accessibilityStatusLabel: String {
        "\(headline). \(subheadline). \(verificationText)"
    }

    var primaryAccessibilityHint: String {
        if isPrimaryEnabled {
            return verificationStatus == .waitingToStart
                ? "Starts the timed movement break"
                : "Marks this break complete"
        }
        return "Unavailable until movement is verified or camera fails open"
    }

    var secondaryAccessibilityHint: String {
        "Skips this break and keeps movement debt"
    }

    var postponeAccessibilityHint: String {
        "Postpones the break for 15 minutes. Keyboard shortcut Escape."
    }

    var quitAccessibilityHint: String {
        "Quits Unchair. Keyboard shortcut Command Q."
    }

    var recoveryAccessibilityHint: String {
        "Opens System Settings Privacy and Security Camera for Unchair"
    }

    /// Non-empty titles used as accessibility labels for the primary control surface.
    var requiredAccessibilityLabels: [String] {
        var labels = [
            accessibilityStatusLabel,
            primaryActionTitle,
            secondaryActionTitle,
            "Postpone 15 min",
            "Quit Unchair",
        ]
        if let recoveryActionTitle {
            labels.append(recoveryActionTitle)
        }
        return labels.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

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
            showsCameraPreview: false,
            verificationStatus: verificationStatus,
            isPrimaryEnabled: true,
            recoveryActionTitle: nil
        )
    }

    static func active(
        remaining: BreakDuration,
        verificationStatus: BreakVerificationStatus,
        canComplete: Bool,
        proofProgressText: String? = nil
    ) -> BreakOverlayModel {
        let seconds = Int(remaining.seconds.rounded())
        let verificationText: String
        if let proofProgressText,
           verificationStatus != .permissionDenied,
           verificationStatus != .cameraBusy,
           verificationStatus != .cameraUnavailable,
           verificationStatus != .verificationOptedOut
        {
            verificationText = proofProgressText
        } else {
            switch verificationStatus {
            case .waitingToStart:
                verificationText = "Movement verification: waiting"
            case .pendingMovement:
                verificationText = "Stand up to start verification"
            case .capturing:
                verificationText = "Camera on · stand up, then keep moving"
            case .standingDetected:
                verificationText = "Standing · keep moving to complete"
            case .permissionDenied:
                verificationText = "Camera permission denied · you can still mark complete"
            case .cameraBusy:
                verificationText = "Camera busy in another app · you can still mark complete"
            case .cameraUnavailable:
                verificationText = "Camera unavailable · you can still mark complete"
            case .verificationOptedOut:
                verificationText = "Camera verification off · mark complete when ready"
            case .verified:
                verificationText = "Movement verified · you can complete"
            }
        }

        let recovery: String? = {
            switch verificationStatus {
            case .permissionDenied:
                return "Open Camera Privacy Settings"
            case .cameraBusy, .cameraUnavailable:
                return "Open Camera Settings"
            default:
                return nil
            }
        }()

        return BreakOverlayModel(
            headline: "Break in progress",
            subheadline: "\(seconds)s left. Stand up. Move.",
            primaryActionTitle: canComplete ? "Mark complete" : "Keep moving…",
            secondaryActionTitle: "Skip for now",
            escapeHint: "Esc postpones 15 minutes · ⌘Q quits Unchair",
            verificationText: verificationText,
            showsVerificationSlot: true,
            showsCameraPreview: true,
            verificationStatus: verificationStatus,
            isPrimaryEnabled: canComplete,
            recoveryActionTitle: recovery
        )
    }
}
