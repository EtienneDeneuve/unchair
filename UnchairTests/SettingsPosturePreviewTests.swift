import XCTest
@testable import Unchair

@MainActor
final class SettingsPosturePreviewTests: XCTestCase {
    func testSettingsPreviewKeepsCameraRunningAndSurfacesConfidence() async {
        let poses = Array(repeating: PoseFixtures.seated(), count: 6)
        let capture = FakeCameraCapture(emitsFramesOnStart: 2, emitsPosesOnStart: poses)
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let coordinator = BreakCameraCoordinator(
            authorizer: authorizer,
            capture: capture,
            detector: SitToStandDetector(
                stabilization: PostureStabilizerConfig(requiredStableFrames: 3, occlusionGraceFrames: 5)
            )
        )

        await coordinator.startSettingsPreview()
        // Pose handlers hop through Task { @MainActor }; wait for ingest.
        let deadline = Date().addingTimeInterval(1)
        while Date() < deadline, coordinator.postureEstimate.state != .seatedLike {
            try? await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertTrue(capture.isRunning)
        XCTAssertEqual(coordinator.postureEstimate.state, .seatedLike)
        XCTAssertGreaterThan(coordinator.postureEstimate.confidence, 0.5)
        XCTAssertTrue(coordinator.postureEstimate.statusText.hasPrefix("Sitting"))

        await coordinator.handlePhaseChange(.working(until: Date().addingTimeInterval(100)))
        XCTAssertTrue(capture.isRunning, "phase ticks must not stop an open Settings preview")

        coordinator.stopSettingsPreview()
        XCTAssertFalse(capture.isRunning)
        // Last reading stays visible for Settings.
        XCTAssertEqual(coordinator.postureEstimate.state, .seatedLike)
    }
}
