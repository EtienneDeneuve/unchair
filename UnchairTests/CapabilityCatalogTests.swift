import XCTest
@testable import Unchair

final class CapabilityCatalogTests: XCTestCase {
    func testStandaloneCatalogExposesCoreCapabilitiesAsAvailable() {
        let catalog = CapabilityCatalog.make(
            runtime: .mac(cameraAuthorized: true),
            preference: .standalone
        )

        XCTAssertEqual(catalog.activeMode, .standalone)
        for id in [
            UnchairCapabilityID.scheduler,
            .presentationGuard,
            .localHistory,
            .visionVerification,
            .movementDebt,
            .launchAtLogin,
        ] {
            XCTAssertTrue(catalog.isAvailable(id), "\(id) should be available in Standalone")
            XCTAssertTrue(id.isCore)
        }
    }

    func testStandaloneDoesNotRequireCompanionsOrNetwork() {
        let catalog = CapabilityCatalog.make(
            runtime: CapabilityRuntimeSnapshot(
                visionVerification: .available,
                watchLiveEvidence: .comingSoon,
                healthKitHistory: .comingSoon,
                chairOccupancy: .comingSoon,
                homeAssistant: .comingSoon
            ),
            preference: .standalone
        )

        XCTAssertEqual(catalog.activeMode, .standalone)
        XCTAssertFalse(catalog.isAvailable(.watchLiveEvidence))
        XCTAssertFalse(catalog.isAvailable(.healthKitHistory))
        XCTAssertFalse(catalog.isAvailable(.chairOccupancy))
        XCTAssertFalse(catalog.isAvailable(.homeAssistant))
        // Core loop still complete.
        XCTAssertTrue(catalog.isAvailable(.scheduler))
        XCTAssertTrue(catalog.isAvailable(.visionVerification))
    }

    func testAppleEnhancedActivatesWhenCompanionAppears() {
        var runtime = CapabilityRuntimeSnapshot.macDefaults
        runtime.watchLiveEvidence = .available

        let catalog = CapabilityCatalog.make(runtime: runtime, preference: .standalone)
        XCTAssertEqual(catalog.activeMode, .appleEnhanced)
        XCTAssertTrue(catalog.isAvailable(.watchLiveEvidence))
        XCTAssertTrue(catalog.isAvailable(.visionVerification))
    }

    func testAppleEnhancedFallsBackWhenCompanionDisappears() {
        var runtime = CapabilityRuntimeSnapshot.macDefaults
        runtime.watchLiveEvidence = .available
        var catalog = CapabilityCatalog.make(runtime: runtime, preference: .appleEnhanced)
        XCTAssertEqual(catalog.activeMode, .appleEnhanced)

        runtime.watchLiveEvidence = .unavailable(reason: "Watch unpaired")
        catalog = CapabilityCatalog.make(runtime: runtime, preference: .appleEnhanced)
        XCTAssertEqual(catalog.activeMode, .standalone)
    }

    func testSensorsOnlyRequiresNonCameraEvidenceAndNoVision() {
        let ready = CapabilityRuntimeSnapshot(
            visionVerification: .unavailable(reason: "Camera disabled by preference"),
            watchLiveEvidence: .available,
            healthKitHistory: .comingSoon,
            chairOccupancy: .comingSoon,
            homeAssistant: .comingSoon
        )
        let catalog = CapabilityCatalog.make(runtime: ready, preference: .sensorsOnly)
        XCTAssertEqual(catalog.activeMode, .sensorsOnly)

        // Vision still on → cannot honor Sensors Only; promote or stand alone.
        let withVision = CapabilityRuntimeSnapshot(
            visionVerification: .available,
            watchLiveEvidence: .available,
            healthKitHistory: .comingSoon,
            chairOccupancy: .comingSoon,
            homeAssistant: .comingSoon
        )
        let fallback = CapabilityCatalog.make(runtime: withVision, preference: .sensorsOnly)
        XCTAssertEqual(fallback.activeMode, .appleEnhanced)
    }

    func testSensorsOnlyFallsBackToStandaloneWithoutEvidence() {
        let catalog = CapabilityCatalog.make(
            runtime: .mac(cameraAuthorized: false),
            preference: .sensorsOnly
        )
        XCTAssertEqual(catalog.activeMode, .standalone)
        XCTAssertFalse(catalog.isAvailable(.visionVerification))
    }

    func testTableDrivenModeResolution() {
        struct Case {
            let preference: UnchairOperatingMode
            let available: Set<UnchairCapabilityID>
            let expected: UnchairOperatingMode
        }

        let core: Set<UnchairCapabilityID> = [
            .scheduler, .presentationGuard, .localHistory,
            .visionVerification, .movementDebt, .launchAtLogin,
        ]

        let cases: [Case] = [
            Case(preference: .standalone, available: core, expected: .standalone),
            Case(
                preference: .standalone,
                available: core.union([.watchLiveEvidence]),
                expected: .appleEnhanced
            ),
            Case(
                preference: .appleEnhanced,
                available: core,
                expected: .standalone
            ),
            Case(
                preference: .sensorsOnly,
                available: [.watchLiveEvidence, .scheduler],
                expected: .sensorsOnly
            ),
            Case(
                preference: .sensorsOnly,
                available: core.union([.chairOccupancy]),
                expected: .standalone // vision still present → cannot honor Sensors Only
            ),
            Case(
                preference: .sensorsOnly,
                available: [.chairOccupancy, .scheduler],
                expected: .sensorsOnly
            ),
        ]

        for item in cases {
            let mode = OperatingModeResolver.resolve(
                preference: item.preference,
                available: item.available
            )
            XCTAssertEqual(
                mode,
                item.expected,
                "pref=\(item.preference) available=\(item.available)"
            )
        }
    }

    func testCameraDeniedMarksVisionUnavailableWithoutCallingStandaloneLimited() {
        let catalog = CapabilityCatalog.make(
            runtime: .mac(cameraAuthorized: false),
            preference: .standalone
        )
        XCTAssertEqual(catalog.activeMode, .standalone)
        XCTAssertEqual(catalog.activeMode.title, "Standalone")
        XCTAssertFalse(catalog.activeMode.summary.lowercased().contains("limited"))
        if case .unavailable(let reason) = catalog.availability(for: .visionVerification) {
            XCTAssertTrue(reason.contains("Camera"))
        } else {
            XCTFail("expected vision unavailable")
        }
    }

    func testBreakEngineTypesDoNotReferenceCapabilityCatalog() throws {
        // Architectural guard: BreakEngine sources must stay free of capability / sensor APIs.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Unchair/BreakEngine", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: nil
        )
        XCTAssertFalse(files.isEmpty)
        let banned = ["CapabilityCatalog", "UnchairCapabilityID", "HealthKit", "MQTT", "WatchLive"]
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
}
