import XCTest
@testable import Unchair

@MainActor
final class OnboardingFlowTests: XCTestCase {
    private func makeShell(
        camera: CameraAuthorizationStatus,
        onboarding: UserDefaultsOnboardingPreferences,
        presentsOnboardingAtLaunch: Bool = false
    ) -> MenuBarShell {
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let capture = FakeCameraCapture()
        let authorizer = FakeCameraAuthorizer(initial: camera, grantOnRequest: .authorized)
        return MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController(),
            cameraCoordinator: BreakCameraCoordinator(authorizer: authorizer, capture: capture),
            history: BreakHistoryRecorder(store: InMemoryBreakHistoryStore(), clock: clock),
            launchAtLogin: ControllableLaunchAtLogin(isEnabled: false),
            onboarding: onboarding,
            updateController: NoOpUpdateController(),
            observesMenuTracking: false,
            startsPeriodicTicker: false,
            primesCameraAtLaunch: false,
            presentsOnboardingAtLaunch: presentsOnboardingAtLaunch
        )
    }

    func testFreshInstallNeedsOnboardingAndShowsRecovery() {
        let defaults = UserDefaults(suiteName: "unchair.tests.onboarding.flow.\(UUID().uuidString)")!
        let store = UserDefaultsOnboardingPreferences(defaults: defaults)
        let shell = makeShell(camera: .notDetermined, onboarding: store)

        XCTAssertFalse(shell.hasCompletedOnboarding)
        XCTAssertTrue(shell.showsCameraSetupRecovery)
        XCTAssertEqual(shell.cameraVerificationPreference, .undecided)
    }

    func testCompleteOnboardingSkippedLeavesRemindersUsable() {
        let defaults = UserDefaults(suiteName: "unchair.tests.onboarding.flow.\(UUID().uuidString)")!
        let store = UserDefaultsOnboardingPreferences(defaults: defaults)
        let shell = makeShell(camera: .notDetermined, onboarding: store)

        shell.completeOnboarding(camera: .skipped)

        XCTAssertTrue(shell.hasCompletedOnboarding)
        XCTAssertEqual(shell.cameraVerificationPreference, .skipped)
        XCTAssertTrue(shell.showsCameraSetupRecovery)
        XCTAssertNoThrow(shell.startBreakNow())
    }

    func testPreferCameraVerificationIsReversible() async {
        let defaults = UserDefaults(suiteName: "unchair.tests.onboarding.flow.\(UUID().uuidString)")!
        let store = UserDefaultsOnboardingPreferences(defaults: defaults)
        let shell = makeShell(camera: .notDetermined, onboarding: store)
        shell.completeOnboarding(camera: .skipped)

        shell.preferCameraVerification(true)
        await Task.yield()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(shell.cameraVerificationPreference, .enabled)

        shell.preferCameraVerification(false)
        XCTAssertEqual(shell.cameraVerificationPreference, .skipped)
    }

    func testExistingAuthorizedInstallMigratesWithoutOnboardingWindow() {
        let defaults = UserDefaults(suiteName: "unchair.tests.onboarding.flow.\(UUID().uuidString)")!
        let store = UserDefaultsOnboardingPreferences(defaults: defaults)
        let shell = makeShell(
            camera: .authorized,
            onboarding: store,
            presentsOnboardingAtLaunch: true
        )

        XCTAssertTrue(shell.hasCompletedOnboarding)
        XCTAssertEqual(shell.cameraVerificationPreference, .enabled)
        XCTAssertFalse(shell.showsCameraSetupRecovery)
    }

    func testSkippedCameraAllowsCompleteWithoutStartingCapture() async {
        let defaults = UserDefaults(suiteName: "unchair.tests.onboarding.flow.\(UUID().uuidString)")!
        let store = UserDefaultsOnboardingPreferences(defaults: defaults)
        let clock = ControllableClock(now: Date(timeIntervalSince1970: 0))
        let capture = FakeCameraCapture(emitsFramesOnStart: 3)
        let authorizer = FakeCameraAuthorizer(initial: .authorized, grantOnRequest: .authorized)
        let shell = MenuBarShell(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: ControllablePresentationGuard()
            ),
            overlayController: NullBreakOverlayController(),
            cameraCoordinator: BreakCameraCoordinator(authorizer: authorizer, capture: capture),
            history: BreakHistoryRecorder(store: InMemoryBreakHistoryStore(), clock: clock),
            launchAtLogin: ControllableLaunchAtLogin(isEnabled: false),
            onboarding: store,
            updateController: NoOpUpdateController(),
            observesMenuTracking: false,
            startsPeriodicTicker: false,
            primesCameraAtLaunch: false,
            presentsOnboardingAtLaunch: false
        )
        shell.completeOnboarding(camera: .skipped)
        shell.startBreakNow()
        shell.beginTimedBreak()
        shell.performPeriodicTick()
        await Task.yield()
        await Task.yield()
        try? await Task.sleep(for: .milliseconds(80))

        XCTAssertFalse(capture.isRunning, "skipped verification must not start the camera")
        XCTAssertEqual(shell.overlayModel.verificationStatus, .verificationOptedOut)
        XCTAssertTrue(shell.overlayModel.isPrimaryEnabled)
        XCTAssertNoThrow(shell.completeBreak())
    }
}
