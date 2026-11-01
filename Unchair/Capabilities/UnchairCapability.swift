import Foundation

/// Typed optional/core capabilities. Not feature flags — explicit product surface (issue #34).
enum UnchairCapabilityID: String, CaseIterable, Codable, Sendable, Hashable {
    // Core Mac Standalone
    case scheduler
    case presentationGuard
    case localHistory
    case visionVerification
    case movementDebt
    case launchAtLogin

    // Apple Enhanced (optional)
    case watchLiveEvidence
    case healthKitHistory

    // Sensors / integrations (optional)
    case chairOccupancy
    case homeAssistant
}

/// Runtime availability for a capability. Adapters report this; UI displays it.
enum CapabilityAvailability: Equatable, Sendable {
    case available
    case unavailable(reason: String)
    case comingSoon

    var isUsable: Bool {
        if case .available = self { return true }
        return false
    }
}

struct CapabilityDescriptor: Equatable, Sendable, Identifiable {
    var id: UnchairCapabilityID
    var title: String
    var summary: String
    var availability: CapabilityAvailability
    /// Core capabilities ship with Mac Standalone; optional ones never block BreakEngine.
    var isCore: Bool

    var isAvailable: Bool { availability.isUsable }
}

extension UnchairCapabilityID {
    var defaultTitle: String {
        switch self {
        case .scheduler: return "Scheduler"
        case .presentationGuard: return "Presentation guard"
        case .localHistory: return "Local history"
        case .visionVerification: return "Vision verification"
        case .movementDebt: return "Movement debt"
        case .launchAtLogin: return "Launch at login"
        case .watchLiveEvidence: return "Watch live evidence"
        case .healthKitHistory: return "HealthKit history"
        case .chairOccupancy: return "Chair occupancy"
        case .homeAssistant: return "Home Assistant"
        }
    }

    var defaultSummary: String {
        switch self {
        case .scheduler:
            return "Work intervals, break prompts, postpone and pause."
        case .presentationGuard:
            return "Defers overlays during calls, screen lock, and presentation mode."
        case .localHistory:
            return "On-device break outcomes with no media."
        case .visionVerification:
            return "Local sit→stand and movement proof via the Mac camera."
        case .movementDebt:
            return "Accrues owed movement until a break completes successfully."
        case .launchAtLogin:
            return "Starts Unchair with your Mac login session."
        case .watchLiveEvidence:
            return "Optional Apple Watch movement evidence during a break."
        case .healthKitHistory:
            return "Optional recent-activity context from HealthKit."
        case .chairOccupancy:
            return "Optional chair sensor occupancy as non-camera evidence."
        case .homeAssistant:
            return "Optional MQTT / Home Assistant integration plane."
        }
    }

    var isCore: Bool {
        switch self {
        case .scheduler, .presentationGuard, .localHistory, .visionVerification,
             .movementDebt, .launchAtLogin:
            return true
        case .watchLiveEvidence, .healthKitHistory, .chairOccupancy, .homeAssistant:
            return false
        }
    }
}
