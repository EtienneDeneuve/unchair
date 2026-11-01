import XCTest
@testable import Unchair

final class TodayStatsTests: XCTestCase {
    private var calendar: Calendar!

    override func setUp() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    func testEmptyDayHasCleanEmptyState() {
        let now = date(2026, 11, 1, 15, 0)
        let stats = TodayStatsCalculator.make(
            records: [],
            now: now,
            calendar: calendar,
            sittingStartedAt: date(2026, 11, 1, 9, 0),
            nextBreakSummary: "Next break: 20:00"
        )

        XCTAssertTrue(stats.isEmpty)
        XCTAssertEqual(stats.completedCount, 0)
        XCTAssertEqual(stats.skippedCount, 0)
        XCTAssertEqual(stats.movementMinutesRounded, 0)
        XCTAssertEqual(stats.longestDeskMinutesRounded, 6 * 60) // 09:00 → 15:00
        XCTAssertEqual(stats.nextBreakSummary, "Next break: 20:00")
    }

    func testMetricsDeriveOnlyFromTodaysLocalHistory() {
        let now = date(2026, 11, 1, 18, 0)
        let records = [
            record(result: .completed, ended: date(2026, 11, 1, 10, 0), duration: 90),
            record(result: .skipped, ended: date(2026, 11, 1, 12, 0), duration: 0),
            record(result: .postponed, ended: date(2026, 11, 1, 13, 0), duration: 0),
            record(result: .completed, ended: date(2026, 11, 1, 14, 0), duration: 120),
            // Yesterday — ignored
            record(result: .completed, ended: date(2026, 10, 31, 18, 0), duration: 90),
        ]

        let stats = TodayStatsCalculator.make(
            records: records,
            now: now,
            calendar: calendar,
            sittingStartedAt: date(2026, 11, 1, 14, 0),
            nextBreakSummary: "Next break: 10:00"
        )

        XCTAssertFalse(stats.isEmpty)
        XCTAssertEqual(stats.completedCount, 2)
        XCTAssertEqual(stats.skippedCount, 1)
        XCTAssertEqual(stats.postponedCount, 1)
        XCTAssertEqual(stats.movementMinutesRounded, 4) // 210s → 3.5 → 4
        // Longest: 10:00→14:00 = 4h between completes, or dayStart→10:00 = 10h
        XCTAssertEqual(stats.longestDeskMinutesRounded, 10 * 60)
    }

    func testLongestDeskUsesGapBetweenCompletes() {
        let dayStart = date(2026, 11, 1, 0, 0)
        let longest = TodayStatsCalculator.longestDeskIntervalSeconds(
            completed: [
                record(result: .completed, ended: date(2026, 11, 1, 1, 0), duration: 60),
                record(result: .completed, ended: date(2026, 11, 1, 5, 0), duration: 60),
            ],
            dayStart: dayStart,
            now: date(2026, 11, 1, 5, 30),
            sittingStartedAt: nil
        )
        // Gaps: 0→1h = 1h, 1→5 = 4h, 5→5:30 = 0.5h → 4h
        XCTAssertEqual(longest, 4 * 3600, accuracy: 0.5)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func record(result: BreakHistoryResult, ended: Date, duration: TimeInterval) -> BreakHistoryRecord {
        BreakHistoryRecord(
            id: UUID(),
            recordedAt: ended,
            breakID: UUID(),
            scheduledAt: ended.addingTimeInterval(-duration),
            startedAt: ended.addingTimeInterval(-duration),
            endedAt: ended,
            result: result,
            durationSeconds: duration,
            verification: nil
        )
    }
}
