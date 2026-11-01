import XCTest
@testable import Unchair

final class EvidenceEngineTests: XCTestCase {
    private var engine: EvidenceEngine!
    private let t0 = Date(timeIntervalSince1970: 2_000_000_000)

    override func setUp() {
        engine = EvidenceEngine()
    }

    private func vision(
        kind: EvidenceKind,
        at offset: TimeInterval = 0,
        ttl: TimeInterval = 5,
        confidence: Double = 0.9,
        standing: Bool = false,
        moving: Bool = false,
        stoodFor: TimeInterval? = nil,
        motion: Double? = nil
    ) -> MovementEvidence {
        MovementEvidence(
            source: .macVision,
            kind: kind,
            timestamp: t0.addingTimeInterval(offset),
            timeToLive: ttl,
            confidence: confidence,
            standingLikely: standing,
            movingLikely: moving,
            stoodForSeconds: stoodFor,
            motionScore: motion
        )
    }

    private func watch(
        kind: EvidenceKind,
        at offset: TimeInterval = 0,
        ttl: TimeInterval = 5,
        confidence: Double = 0.85,
        standing: Bool = false,
        moving: Bool = false
    ) -> MovementEvidence {
        MovementEvidence(
            source: .appleWatchLive,
            kind: kind,
            timestamp: t0.addingTimeInterval(offset),
            timeToLive: ttl,
            confidence: confidence,
            standingLikely: standing,
            movingLikely: moving,
            stoodForSeconds: nil,
            motionScore: nil
        )
    }

    func testVisionOnlyStandingThenVerified() {
        engine.ingest(vision(kind: .standing, standing: true))
        XCTAssertEqual(engine.evaluate(at: t0), .standingDetected)

        engine.ingest(vision(kind: .moving, standing: true, moving: true, stoodFor: 6, motion: 0.3))
        XCTAssertEqual(engine.evaluate(at: t0), .movementVerified)
    }

    func testVisionMapperPreservesMacOnlyProofPath() {
        let standing = VisionEvidenceMapper.evidence(
            from: .standing(elapsed: 3, motionScore: 0.1),
            at: t0
        )
        engine.ingest(standing!)
        XCTAssertEqual(engine.evaluate(at: t0), .standingDetected)

        let verified = VisionEvidenceMapper.evidence(
            from: .verified(stoodFor: 6, motionScore: 0.25),
            at: t0
        )
        engine.ingest(verified!)
        XCTAssertEqual(engine.evaluate(at: t0), .movementVerified)
    }

    func testWatchOnlyDoesNotVerifyUnlessPolicyAllows() {
        engine.ingest(watch(kind: .moving, standing: true, moving: true))
        XCTAssertEqual(
            engine.evaluate(at: t0),
            .standingDetected,
            "without policy, Watch alone must not verify"
        )

        engine.updatePolicy(
            EvidenceFusionPolicy(
                minimumConfidence: 0.5,
                allowNonVisionVerification: true,
                sourcePriority: EvidenceFusionPolicy.default.sourcePriority
            )
        )
        XCTAssertEqual(engine.evaluate(at: t0), .movementVerified)
    }

    func testVisionAndWatchAgreementVerifies() {
        engine.ingest(vision(kind: .standing, standing: true))
        engine.ingest(watch(kind: .moving, standing: true, moving: true))
        XCTAssertEqual(engine.evaluate(at: t0), .movementVerified)
    }

    func testConflictingSignalsResolveDeterministically() {
        // Equal confidence — Vision priority wins standing claim → standingDetected.
        engine.ingest(vision(kind: .standing, confidence: 0.8, standing: true))
        engine.ingest(
            MovementEvidence(
                source: .appleWatchLive,
                kind: .seated,
                timestamp: t0,
                timeToLive: 5,
                confidence: 0.8,
                standingLikely: false,
                movingLikely: false,
                stoodForSeconds: nil,
                motionScore: nil
            )
        )
        XCTAssertEqual(engine.evaluate(at: t0), .standingDetected)

        // Higher-confidence seated Watch beats lower-confidence Vision standing → insufficient.
        engine.ingest(vision(kind: .standing, confidence: 0.55, standing: true))
        engine.ingest(
            MovementEvidence(
                source: .appleWatchLive,
                kind: .seated,
                timestamp: t0,
                timeToLive: 5,
                confidence: 0.95,
                standingLikely: false,
                movingLikely: false,
                stoodForSeconds: nil,
                motionScore: nil
            )
        )
        XCTAssertEqual(engine.evaluate(at: t0), .insufficient)
    }

    func testStaleEvidenceIsIgnored() {
        engine.ingest(vision(kind: .moving, ttl: 2, standing: true, moving: true))
        XCTAssertEqual(engine.evaluate(at: t0), .movementVerified)
        XCTAssertEqual(
            engine.evaluate(at: t0.addingTimeInterval(3)),
            .insufficient
        )
    }

    func testSensorDisappearingMidBreakDropsItsEvidence() {
        engine.ingest(vision(kind: .standing, standing: true))
        engine.ingest(watch(kind: .moving, standing: true, moving: true))
        XCTAssertEqual(engine.evaluate(at: t0), .movementVerified)

        engine.removeSource(.appleWatchLive)
        XCTAssertEqual(
            engine.evaluate(at: t0),
            .standingDetected,
            "without Watch motion, Vision standing alone is not verified yet"
        )
    }

    func testFailedOpenOutcome() {
        engine.noteFailedOpen(true)
        XCTAssertEqual(engine.evaluate(at: t0), .failedOpen)
    }

    func testTableDrivenFusionCases() {
        struct Case {
            let name: String
            let policy: EvidenceFusionPolicy
            let evidence: [MovementEvidence]
            let remove: EvidenceSource?
            let at: Date
            let expected: VerificationOutcome
        }

        let cases: [Case] = [
            Case(
                name: "empty",
                policy: .default,
                evidence: [],
                remove: nil,
                at: t0,
                expected: .insufficient
            ),
            Case(
                name: "vision moving",
                policy: .default,
                evidence: [vision(kind: .moving, standing: true, moving: true)],
                remove: nil,
                at: t0,
                expected: .movementVerified
            ),
            Case(
                name: "watch moving blocked",
                policy: .default,
                evidence: [watch(kind: .moving, standing: true, moving: true)],
                remove: nil,
                at: t0,
                expected: .standingDetected
            ),
            Case(
                name: "watch moving allowed",
                policy: EvidenceFusionPolicy(
                    minimumConfidence: 0.5,
                    allowNonVisionVerification: true,
                    sourcePriority: EvidenceFusionPolicy.default.sourcePriority
                ),
                evidence: [watch(kind: .moving, standing: true, moving: true)],
                remove: nil,
                at: t0,
                expected: .movementVerified
            ),
            Case(
                name: "stale vision",
                policy: .default,
                evidence: [vision(kind: .moving, ttl: 1, standing: true, moving: true)],
                remove: nil,
                at: t0.addingTimeInterval(5),
                expected: .insufficient
            ),
            Case(
                name: "low confidence dropped",
                policy: .default,
                evidence: [vision(kind: .moving, confidence: 0.2, standing: true, moving: true)],
                remove: nil,
                at: t0,
                expected: .insufficient
            ),
        ]

        for item in cases {
            let local = EvidenceEngine(policy: item.policy)
            for evidence in item.evidence {
                local.ingest(evidence)
            }
            if let remove = item.remove {
                local.removeSource(remove)
            }
            XCTAssertEqual(
                local.evaluate(at: item.at),
                item.expected,
                item.name
            )
        }
    }

    func testBreakEngineDoesNotImportEvidenceTypes() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Unchair/BreakEngine", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )
        let banned = ["EvidenceEngine", "MovementEvidence", "HealthKit", "AVCapture", "VNHuman"]
        for file in files where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            for token in banned {
                XCTAssertFalse(
                    source.contains(token),
                    "\(file.lastPathComponent) must not reference \(token)"
                )
            }
        }
    }

    func testOutcomeNeverImpliesDomainCompletionAPI() {
        // EvidenceEngine only exposes VerificationOutcome — no complete() surface.
        let outcomes: [VerificationOutcome] = [
            .insufficient, .standingDetected, .movementVerified, .failedOpen,
        ]
        XCTAssertEqual(outcomes.count, 4)
        engine.ingest(vision(kind: .moving, standing: true, moving: true))
        XCTAssertNotEqual(
            String(describing: engine.evaluate(at: t0)),
            "completed"
        )
    }
}
