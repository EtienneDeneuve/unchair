import XCTest
@testable import Unchair

final class MenuBarContentViewTests: XCTestCase {
    func testNextRoundHourReturnsUpcomingWallClockHour() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let date = calendar.date(
            from: DateComponents(year: 2026, month: 11, day: 1, hour: 14, minute: 20)
        )!

        let until = MenuBarContentView.nextRoundHour(from: date, calendar: calendar)
        let components = calendar.dateComponents([.hour, .minute], from: until)
        XCTAssertEqual(components.hour, 15)
        XCTAssertEqual(components.minute, 0)
    }
}
