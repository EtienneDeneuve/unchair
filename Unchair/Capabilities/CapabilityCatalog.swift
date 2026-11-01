import Foundation

/// Runtime facts that can appear/disappear without touching BreakEngine.
struct CapabilityRuntimeSnapshot: Equatable, Sendable {
    var visionVerification: CapabilityAvailability
    var watchLiveEvidence: CapabilityAvailability
    var healthKitHistory: CapabilityAvailability
    var chairOccupancy: CapabilityAvailability
    var homeAssistant: CapabilityAvailability

    /// Production Mac defaults — companions are declared, not stubbed as "limited".
    static let macDefaults = CapabilityRuntimeSnapshot(
        visionVerification: .available,
        watchLiveEvidence: .comingSoon,
        healthKitHistory: .comingSoon,
        chairOccupancy: .comingSoon,
        homeAssistant: .comingSoon
    )

    static func mac(
        cameraAuthorized: Bool,
        cameraDeniedReason: String = "Camera permission is off — enable Unchair in System Settings → Privacy & Security → Camera."
    ) -> CapabilityRuntimeSnapshot {
        var snap = macDefaults
        snap.visionVerification = cameraAuthorized
            ? .available
            : .unavailable(reason: cameraDeniedReason)
        return snap
    }
}

/// Explicit, testable capability catalog. BreakEngine must not depend on this type.
struct CapabilityCatalog: Equatable, Sendable {
    /// User preference (Sensors Only is opt-in; Standalone is the default product).
    var preference: UnchairOperatingMode
    var capabilities: [CapabilityDescriptor]

    var activeMode: UnchairOperatingMode {
        OperatingModeResolver.resolve(preference: preference, available: availableIDs)
    }

    var availableIDs: Set<UnchairCapabilityID> {
        Set(capabilities.filter(\.isAvailable).map(\.id))
    }

    func availability(for id: UnchairCapabilityID) -> CapabilityAvailability {
        capabilities.first(where: { $0.id == id })?.availability ?? .unavailable(reason: "Unknown capability")
    }

    func isAvailable(_ id: UnchairCapabilityID) -> Bool {
        availability(for: id).isUsable
    }

    /// Build the catalog from a runtime snapshot. Core IDs are always present.
    static func make(
        runtime: CapabilityRuntimeSnapshot = .macDefaults,
        preference: UnchairOperatingMode = .standalone
    ) -> CapabilityCatalog {
        let descriptors: [CapabilityDescriptor] = UnchairCapabilityID.allCases.map { id in
            CapabilityDescriptor(
                id: id,
                title: id.defaultTitle,
                summary: id.defaultSummary,
                availability: availability(for: id, runtime: runtime),
                isCore: id.isCore
            )
        }
        return CapabilityCatalog(preference: preference, capabilities: descriptors)
    }

    private static func availability(
        for id: UnchairCapabilityID,
        runtime: CapabilityRuntimeSnapshot
    ) -> CapabilityAvailability {
        switch id {
        case .scheduler, .presentationGuard, .localHistory, .movementDebt, .launchAtLogin:
            return .available
        case .visionVerification:
            return runtime.visionVerification
        case .watchLiveEvidence:
            return runtime.watchLiveEvidence
        case .healthKitHistory:
            return runtime.healthKitHistory
        case .chairOccupancy:
            return runtime.chairOccupancy
        case .homeAssistant:
            return runtime.homeAssistant
        }
    }
}
