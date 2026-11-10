import XCTest
@testable import Unchair

final class OnboardingPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: UserDefaultsOnboardingPreferences!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "unchair.tests.onboarding.\(UUID().uuidString)")
        store = UserDefaultsOnboardingPreferences(defaults: defaults!)
    }

    override func tearDown() {
        store = nil
        defaults = nil
        super.tearDown()
    }

    func testDefaultsToIncompleteAndUndecidedCamera() {
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertEqual(store.cameraVerificationPreference, .undecided)
    }

    func testCompleteWithSkippedCameraIsReversible() {
        store.complete(camera: .skipped)
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertEqual(store.cameraVerificationPreference, .skipped)

        store.cameraVerificationPreference = .enabled
        XCTAssertEqual(store.cameraVerificationPreference, .enabled)
        XCTAssertTrue(store.hasCompletedOnboarding)
    }

    func testMigrateMarksCompleteWhenCameraAlreadyAuthorized() {
        store.migrateIfNeeded(cameraStatus: .authorized)
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertEqual(store.cameraVerificationPreference, .enabled)
    }

    func testMigrateMarksCompleteWhenCameraAlreadyDenied() {
        store.migrateIfNeeded(cameraStatus: .denied)
        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertEqual(store.cameraVerificationPreference, .skipped)
    }

    func testMigrateLeavesFreshInstallAlone() {
        store.migrateIfNeeded(cameraStatus: .notDetermined)
        XCTAssertFalse(store.hasCompletedOnboarding)
        XCTAssertEqual(store.cameraVerificationPreference, .undecided)
    }
}
