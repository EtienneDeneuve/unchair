import Foundation

/// Product operating modes. Mac-only Standalone is a complete product, not a "limited" tier.
enum UnchairOperatingMode: String, CaseIterable, Codable, Sendable, Equatable {
    /// Mac + local Vision verification. Fully useful offline with no companions.
    case standalone
    /// Mac + optional iPhone / Apple Watch evidence on top of local Vision.
    case appleEnhanced
    /// Privacy mode: camera verification off when sufficiently strong non-camera evidence exists.
    case sensorsOnly

    var title: String {
        switch self {
        case .standalone: return "Standalone"
        case .appleEnhanced: return "Apple Enhanced"
        case .sensorsOnly: return "Sensors Only"
        }
    }

    var summary: String {
        switch self {
        case .standalone:
            return "Mac + local Vision. Complete product — no phone, watch, or network required."
        case .appleEnhanced:
            return "Mac Vision plus optional iPhone / Apple Watch movement evidence."
        case .sensorsOnly:
            return "Camera verification disabled when strong non-camera evidence is available."
        }
    }
}

enum OperatingModeResolver {
    /// Derive the active mode from user preference + currently usable capabilities.
    ///
    /// Rules:
    /// - Never leave Standalone "broken" — fall back when a preferred mode cannot run.
    /// - Apple Enhanced activates when any Apple companion capability is usable.
    /// - Sensors Only requires non-camera evidence and Vision intentionally unavailable.
    static func resolve(
        preference: UnchairOperatingMode,
        available: Set<UnchairCapabilityID>
    ) -> UnchairOperatingMode {
        let hasAppleCompanion = available.contains(.watchLiveEvidence)
            || available.contains(.healthKitHistory)
        let hasNonCameraEvidence = hasAppleCompanion || available.contains(.chairOccupancy)
        let hasVision = available.contains(.visionVerification)

        switch preference {
        case .sensorsOnly:
            if hasNonCameraEvidence, !hasVision {
                return .sensorsOnly
            }
            if hasAppleCompanion {
                return .appleEnhanced
            }
            return .standalone
        case .appleEnhanced:
            if hasAppleCompanion {
                return .appleEnhanced
            }
            return .standalone
        case .standalone:
            // Companions may appear at runtime — promote without demoting core usefulness.
            if hasAppleCompanion {
                return .appleEnhanced
            }
            return .standalone
        }
    }
}
