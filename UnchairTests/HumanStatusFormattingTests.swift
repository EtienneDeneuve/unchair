import XCTest
@testable import Unchair

final class HumanStatusFormattingTests: XCTestCase {
    func testFriendlyDurationUsesSemanticUnits() {
        XCTAssertEqual(HumanStatusFormatting.friendlyDuration(36), "36s")
        XCTAssertEqual(HumanStatusFormatting.friendlyDuration(36 * 60), "36 min")
        XCTAssertEqual(HumanStatusFormatting.friendlyDuration(72 * 60), "1h 12m")
        XCTAssertEqual(HumanStatusFormatting.friendlyDuration(50 * 3600 + 18 * 60), "50h 18m")
        XCTAssertFalse(HumanStatusFormatting.friendlyDuration(50 * 3600 + 18 * 60).contains(":"))
    }

    func testNextBreakLineSurfacesDebtSemantically() {
        let line = HumanStatusFormatting.nextBreakLine(
            remainingSeconds: 36 * 60,
            debtSeconds: 50 * 3600 + 18 * 60,
            debtActive: true
        )
        XCTAssertEqual(line, "Next break in 36 min · Movement debt 50h 18m")
    }

    func testLongestSessionLine() {
        XCTAssertEqual(
            HumanStatusFormatting.longestSessionLine(minutes: 50 * 60 + 18),
            "Longest session 50h 18m"
        )
    }

    func testCompactOrDashHidesZeroDebugDuration() {
        XCTAssertEqual(HumanStatusFormatting.compactOrDash(0), "—")
        XCTAssertEqual(HumanStatusFormatting.compactOrDash(90), "1 min")
    }

    func testNextBreakOmitsDebtWhenCallerDisablesIt() {
        let line = HumanStatusFormatting.nextBreakLine(
            remainingSeconds: 16 * 60,
            debtSeconds: 50 * 3600,
            debtActive: false
        )
        XCTAssertEqual(line, "Next break in 16 min")
        XCTAssertFalse(line.contains("debt"))
    }
}
