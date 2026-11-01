import XCTest
@testable import Unchair

final class BreakOverlayModelTests: XCTestCase {
    func testOverlayIsVisibleOnlyWhileBreakIsDueOrActive() {
        XCTAssertFalse(BreakOverlayModel.shouldPresent(phase: .idle))
        XCTAssertFalse(BreakOverlayModel.shouldPresent(phase: .working(until: Date())))
        XCTAssertFalse(BreakOverlayModel.shouldPresent(phase: .postponed(until: Date())))
        XCTAssertFalse(BreakOverlayModel.shouldPresent(phase: .paused))
        XCTAssertFalse(
            BreakOverlayModel.shouldPresent(phase: .deferredForPresentation(pendingSince: Date()))
        )

        XCTAssertTrue(BreakOverlayModel.shouldPresent(phase: .breakDue))
        XCTAssertTrue(BreakOverlayModel.shouldPresent(phase: .onBreak(endsAt: Date())))
    }

    func testCopyIsMildlyAnnoyingNotAbusive() {
        let model = BreakOverlayModel.due(
            sittingSeconds: 52 * 60,
            breakDuration: .seconds(90),
            verificationStatus: .waitingToStart
        )

        XCTAssertEqual(model.headline, "You've been sitting for 52 minutes.")
        XCTAssertEqual(model.subheadline, "Move your ass.")
        XCTAssertFalse(model.subheadline.lowercased().contains("idiot"))
        XCTAssertFalse(model.subheadline.lowercased().contains("stupid"))
        XCTAssertEqual(model.primaryActionTitle, "Start 90s break")
        XCTAssertEqual(model.secondaryActionTitle, "Skip for now")
        XCTAssertEqual(model.escapeHint, "Esc postpones 15 minutes · ⌘Q quits Unchair")
    }

    func testActiveBreakShowsRemainingTimeAndVerificationPlaceholder() {
        let model = BreakOverlayModel.active(
            remaining: .seconds(74),
            verificationStatus: .pendingMovement
        )

        XCTAssertEqual(model.headline, "Break in progress")
        XCTAssertEqual(model.subheadline, "74s left. Stand up. Move.")
        XCTAssertEqual(model.verificationText, "Movement verification: pending")
        XCTAssertEqual(model.primaryActionTitle, "Mark complete")
        XCTAssertTrue(model.showsVerificationSlot)
    }

    func testAccessibilityActionsAlwaysIncludeQuitPath() {
        let actions = BreakOverlayModel.accessibilityActions
        XCTAssertTrue(actions.contains(.startOrComplete))
        XCTAssertTrue(actions.contains(.skip))
        XCTAssertTrue(actions.contains(.postpone15))
        XCTAssertTrue(actions.contains(.quit))
    }
}
