import XCTest
@testable import Unchair

final class AccessibilitySurfaceTests: XCTestCase {
    func testOverlayRequiredLabelsStayNonEmptyAcrossStates() {
        let due = BreakOverlayModel.due(
            sittingSeconds: 50 * 60,
            breakDuration: .seconds(90),
            verificationStatus: .waitingToStart
        )
        assertNonEmpty(due.requiredAccessibilityLabels, context: "due")
        XCTAssertFalse(due.primaryAccessibilityHint.isEmpty)
        XCTAssertFalse(due.postponeAccessibilityHint.isEmpty)

        let statuses: [BreakVerificationStatus] = [
            .pendingMovement,
            .capturing,
            .standingDetected,
            .permissionDenied,
            .cameraBusy,
            .cameraUnavailable,
            .verificationOptedOut,
            .verified,
        ]
        for status in statuses {
            let canComplete = status == .verified
                || status == .permissionDenied
                || status == .cameraBusy
                || status == .cameraUnavailable
                || status == .verificationOptedOut
            let model = BreakOverlayModel.active(
                remaining: .seconds(40),
                verificationStatus: status,
                canComplete: canComplete
            )
            assertNonEmpty(model.requiredAccessibilityLabels, context: "\(status)")
            XCTAssertFalse(model.accessibilityStatusLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            if model.recoveryActionTitle != nil {
                XCTAssertFalse(model.recoveryAccessibilityHint.isEmpty)
            }
        }
    }

    func testOverlayAccessibilityActionCatalogCoversMainFlow() {
        let actions = BreakOverlayModel.accessibilityActions
        XCTAssertEqual(
            actions,
            [.startOrComplete, .skip, .postpone15, .openCameraSettings, .quit]
        )
    }

    func testTodayRequiredLabelsStayNonEmpty() {
        let model = TodayDashboardModel(
            heroEyebrow: "At desk",
            heroValue: "52 min",
            heroCaption: "Schedule running — no breaks logged yet.",
            nextAction: "Next break in about 8 minutes",
            todayCompleted: 2,
            todaySkipped: 1,
            todayMovedMinutes: 3,
            todayLongest: "52 min",
            week: HumanRuntimeWeeklySummaryCalculator.make(records: [], now: Date()),
            dayLabel: "Tue, Nov 10"
        )
        assertNonEmpty(model.requiredAccessibilityLabels, context: "today")
        XCTAssertTrue(model.heroAccessibilityLabel.contains("At desk"))
        XCTAssertTrue(model.heroAccessibilityLabel.contains("52 min"))
    }

    func testAccessibilityDocCoversRequiredTopics() throws {
        let url = try XCTUnwrap(Self.repoFile("docs/accessibility.md"))
        let text = try String(contentsOf: url, encoding: .utf8)
        for needle in ["VoiceOver", "Dynamic Type", "Increase Contrast", "Today", "overlay"] {
            XCTAssertTrue(
                text.localizedCaseInsensitiveContains(needle),
                "accessibility.md should mention \(needle)"
            )
        }
    }

    private func assertNonEmpty(_ labels: [String], context: String) {
        XCTAssertFalse(labels.isEmpty, context)
        for label in labels {
            XCTAssertFalse(
                label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                "\(context): empty label"
            )
        }
    }

    private static func repoFile(_ relative: String) -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
