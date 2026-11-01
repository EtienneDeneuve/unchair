import Foundation

/// Deterministic fusion rules for multi-source movement evidence (issue #35).
struct EvidenceFusionPolicy: Equatable, Sendable {
    var minimumConfidence: Double
    /// When true, non-Vision sources may alone produce `movementVerified`
    /// (Sensors Only / Vision unavailable). Default false — Vision alone is the Mac path.
    var allowNonVisionVerification: Bool
    /// Higher wins on conflicts. Vision preferred.
    var sourcePriority: [EvidenceSource: Int]

    static let `default` = EvidenceFusionPolicy(
        minimumConfidence: 0.5,
        allowNonVisionVerification: false,
        sourcePriority: [
            .macVision: 100,
            .appleWatchLive: 80,
            .healthKitRecent: 60,
            .chairOccupancy: 50,
            .macActivityIdle: 40,
            .manualBreakContext: 10,
        ]
    )

    func priority(of source: EvidenceSource) -> Int {
        sourcePriority[source] ?? 0
    }
}
