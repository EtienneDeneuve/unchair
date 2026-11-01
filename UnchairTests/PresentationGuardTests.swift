import XCTest
@testable import Unchair

private final class StubSignal: PresentationSignalSource {
    let reason: PresentationBlockReason
    var isActive: Bool

    init(reason: PresentationBlockReason, isActive: Bool) {
        self.reason = reason
        self.isActive = isActive
    }
}

private final class StubDevices: MediaDeviceInspecting {
    var isCameraInUseByAnotherApplication = false
    var isMicrophoneInUseByAnotherApplication = false
}

private final class StubApps: RunningApplicationInspecting {
    var runningBundleIdentifiers: Set<String> = []
}

private final class StubScreen: ScreenSessionInspecting {
    var isScreenLockedOrAsleep = false
}

final class PresentationGuardTests: XCTestCase {
    private var clock: ControllableClock!

    override func setUp() {
        clock = ControllableClock(now: Date(timeIntervalSince1970: 1_700_000_000))
    }

    func testManualPresentationModeBlocksForDurationThenClears() {
        let manual = ManualPresentationMode(clock: clock)
        let sut = PresentationGuard(signals: [manual], manualMode: manual)

        XCTAssertFalse(sut.isBlocking)
        manual.enable(for: .minutes(45))
        XCTAssertTrue(sut.isBlocking)
        XCTAssertEqual(sut.activeReasons, [.manualPresentationMode])

        clock.advance(by: 45 * 60)
        XCTAssertFalse(sut.isBlocking)
        XCTAssertFalse(manual.isActive)
    }

    func testManualUntilDisabledRequiresExplicitOff() {
        let manual = ManualPresentationMode(clock: clock)
        manual.enableUntilDisabled()
        XCTAssertTrue(manual.isActive)
        clock.advance(by: 24 * 60 * 60)
        XCTAssertTrue(manual.isActive)
        manual.disable()
        XCTAssertFalse(manual.isActive)
    }

    func testCameraInUseIsStrongSignal() {
        let devices = StubDevices()
        devices.isCameraInUseByAnotherApplication = true
        let signal = CameraInUseSignal(inspector: devices)
        XCTAssertTrue(signal.isActive)
        XCTAssertEqual(signal.reason, .cameraInUseByAnotherApp)
    }

    func testMeetingAppAloneDoesNotBlock() {
        let devices = StubDevices()
        let apps = StubApps()
        apps.runningBundleIdentifiers = ["us.zoom.xos"]
        let signal = MeetingAppWithDeviceUseSignal(apps: apps, devices: devices)
        XCTAssertFalse(signal.isActive)

        devices.isMicrophoneInUseByAnotherApplication = true
        XCTAssertTrue(signal.isActive)
        XCTAssertEqual(signal.reason, .meetingAppWithDeviceUse)
    }

    func testScreenLockBlocks() {
        let screen = StubScreen()
        screen.isScreenLockedOrAsleep = true
        let signal = ScreenLockSignal(inspector: screen)
        XCTAssertTrue(signal.isActive)
    }

    func testCompositeReportsAnyActiveReason() {
        let manual = ManualPresentationMode(clock: clock)
        let camera = StubSignal(reason: .cameraInUseByAnotherApp, isActive: true)
        let sut = PresentationGuard(signals: [manual, camera], manualMode: manual)

        XCTAssertTrue(sut.isBlocking)
        XCTAssertEqual(sut.activeReasons, [.cameraInUseByAnotherApp])

        camera.isActive = false
        manual.enable(until: clock.now.addingTimeInterval(60))
        XCTAssertEqual(sut.activeReasons, [.manualPresentationMode])
    }

    func testBreakDueDefersWhenGuardBecomesBlocking() {
        let presentation = ControllablePresentationGuard()
        let scheduler = BreakScheduler(
            clock: clock,
            presentationGuard: presentation,
            restoreOnInit: false
        )
        scheduler.start()
        scheduler.startBreakNow()
        XCTAssertEqual(scheduler.snapshot.phase, .breakDue)

        presentation.isBlocking = true
        scheduler.evaluate()

        XCTAssertEqual(
            scheduler.snapshot.phase,
            .deferredForPresentation(pendingSince: clock.now)
        )
    }

    func testOnBreakDefersWhenGuardBecomesBlocking() {
        let presentation = ControllablePresentationGuard()
        let scheduler = BreakScheduler(
            clock: clock,
            presentationGuard: presentation,
            restoreOnInit: false
        )
        scheduler.start()
        scheduler.startBreakNow()
        scheduler.beginTimedBreak()
        XCTAssertTrue(scheduler.snapshot.phase.isOnBreak)

        presentation.isBlocking = true
        scheduler.evaluate()

        XCTAssertEqual(
            scheduler.snapshot.phase,
            .deferredForPresentation(pendingSince: clock.now)
        )
        XCTAssertTrue(scheduler.snapshot.hasMovementDebt)
    }

    func testPresentationModePresetsIncludeThirtyFortyFiveSixty() {
        XCTAssertEqual(
            ManualPresentationMode.durationPresets,
            [.minutes(30), .minutes(45), .minutes(60)]
        )
    }
}
