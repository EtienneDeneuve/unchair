import XCTest
@testable import Unchair

final class HumanRuntimeWeeklySummaryTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        cal.firstWeekday = 2
        calendar = cal
    }

    func testEmptyWeekIsPrivacySafeEmptyCard() {
        let now = date(2026, 11, 10, 12, 0) // Tuesday
        let summary = HumanRuntimeWeeklySummaryCalculator.make(
            records: [],
            now: now,
            calendar: calendar
        )

        XCTAssertTrue(summary.isEmpty)
        XCTAssertEqual(summary.completedCount, 0)
        XCTAssertEqual(summary.postponedCount, 0)
        XCTAssertEqual(summary.sittingSLOPercent, 100, accuracy: 0.01)
        XCTAssertNil(summary.sevLine)
        XCTAssertNil(summary.meanTimeToButtOffSeconds)
    }

    func testWeeklyMetricsIgnoreOtherWeeksAndExcludeCameraFields() {
        // Monday 2026-11-09 → Sunday 2026-11-15
        let now = date(2026, 11, 12, 18, 0)
        let records = [
            record(
                result: .completed,
                ended: date(2026, 11, 10, 10, 0),
                started: date(2026, 11, 10, 9, 50),
                duration: 90
            ),
            record(
                result: .postponed,
                ended: date(2026, 11, 10, 12, 0),
                started: nil,
                duration: 0
            ),
            record(
                result: .completed,
                ended: date(2026, 11, 11, 11, 0),
                started: date(2026, 11, 11, 10, 54),
                duration: 120
            ),
            record(
                result: .skipped,
                ended: date(2026, 11, 11, 15, 0),
                started: nil,
                duration: 0
            ),
            // Previous week — ignored
            record(
                result: .completed,
                ended: date(2026, 11, 2, 10, 0),
                started: date(2026, 11, 2, 9, 55),
                duration: 90
            ),
        ]

        let summary = HumanRuntimeWeeklySummaryCalculator.make(
            records: records,
            now: now,
            calendar: calendar
        )

        XCTAssertFalse(summary.isEmpty)
        XCTAssertEqual(summary.completedCount, 2)
        XCTAssertEqual(summary.postponedCount, 1)
        XCTAssertEqual(summary.skippedCount, 1)
        // 2 completed / (2 completed + 1 skipped) = 66.7%
        XCTAssertEqual(summary.sittingSLOPercent, 66.666, accuracy: 0.1)
        // MTTB = mean(600s, 360s) = 480s
        XCTAssertEqual(summary.meanTimeToButtOffSeconds ?? -1, 480, accuracy: 0.1)

        let lines = HumanRuntimeWeeklySummaryFormatting.cardLines(summary).joined(separator: "\n")
        XCTAssertTrue(lines.contains("Sitting SLO"))
        XCTAssertFalse(lines.localizedCaseInsensitiveContains("camera"))
        XCTAssertFalse(lines.localizedCaseInsensitiveContains("landmark"))
        XCTAssertFalse(lines.localizedCaseInsensitiveContains("health"))
    }

    func testSevLineWhenDebtPeakExceedsOneHour() {
        let now = date(2026, 11, 10, 18, 0)
        // One completion Monday morning, then long gap until "now"
        let records = [
            record(
                result: .completed,
                ended: date(2026, 11, 9, 9, 0),
                started: date(2026, 11, 9, 8, 55),
                duration: 60
            ),
        ]
        let summary = HumanRuntimeWeeklySummaryCalculator.make(
            records: records,
            now: now,
            calendar: calendar
        )
        XCTAssertGreaterThanOrEqual(summary.movementDebtPeakSeconds, 3600)
        XCTAssertEqual(summary.sevLine, "SEV-2: Glute Availability Degradation")
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        var components = DateComponents()
        components.year = y
        components.month = m
        components.day = d
        components.hour = h
        components.minute = min
        return calendar.date(from: components)!
    }

    private func record(
        result: BreakHistoryResult,
        ended: Date,
        started: Date?,
        duration: TimeInterval
    ) -> BreakHistoryRecord {
        BreakHistoryRecord(
            id: UUID(),
            recordedAt: ended,
            breakID: nil,
            scheduledAt: started,
            startedAt: started,
            endedAt: ended,
            result: result,
            durationSeconds: duration,
            verification: BreakHistoryVerification(stoodForSeconds: nil, motionScore: nil, failedOpen: false)
        )
    }
}
