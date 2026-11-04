import XCTest
@testable import Unchair

final class ControlCLIParserTests: XCTestCase {
    func testParsesCoreCommands() {
        XCTAssertEqual(
            try ControlCLIParser.parse(["status"]).get(),
            ControlRequest(command: .status, minutes: nil)
        )
        XCTAssertEqual(
            try ControlCLIParser.parse(["postpone", "15m"]).get(),
            ControlRequest(command: .postpone, minutes: 15)
        )
        XCTAssertEqual(
            try ControlCLIParser.parse(["presentation", "1h"]).get(),
            ControlRequest(command: .presentationOn, minutes: 60)
        )
        XCTAssertEqual(
            try ControlCLIParser.parse(["presentation", "off"]).get(),
            ControlRequest(command: .presentationOff, minutes: nil)
        )
        XCTAssertEqual(
            try ControlCLIParser.parse(["break", "start"]).get(),
            ControlRequest(command: .breakStart, minutes: nil)
        )
        XCTAssertEqual(
            try ControlCLIParser.parse(["history", "today"]).get(),
            ControlRequest(command: .historyToday, minutes: nil)
        )
    }

    func testRejectsUnknown() {
        XCTAssertThrowsError(try ControlCLIParser.parse(["complete"]).get())
        XCTAssertThrowsError(try ControlCLIParser.parse(["break", "complete"]).get())
    }
}

private extension Result {
    func get() throws -> Success {
        switch self {
        case let .success(value): return value
        case let .failure(error): throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(error)"])
        }
    }
}
