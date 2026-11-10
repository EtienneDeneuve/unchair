import XCTest
@testable import Unchair

final class ControlCLIParserTests: XCTestCase {
    func testParsesCoreCommands() {
        XCTAssertEqual(
            ControlCLIParser.parse(["status"]),
            .request(ControlRequest(command: .status, minutes: nil))
        )
        XCTAssertEqual(
            ControlCLIParser.parse(["postpone", "15m"]),
            .request(ControlRequest(command: .postpone, minutes: 15))
        )
        XCTAssertEqual(
            ControlCLIParser.parse(["presentation", "1h"]),
            .request(ControlRequest(command: .presentationOn, minutes: 60))
        )
        XCTAssertEqual(
            ControlCLIParser.parse(["presentation", "off"]),
            .request(ControlRequest(command: .presentationOff, minutes: nil))
        )
        XCTAssertEqual(
            ControlCLIParser.parse(["break", "start"]),
            .request(ControlRequest(command: .breakStart, minutes: nil))
        )
        XCTAssertEqual(
            ControlCLIParser.parse(["history", "today"]),
            .request(ControlRequest(command: .historyToday, minutes: nil))
        )
        XCTAssertEqual(
            ControlCLIParser.parse(["doctor"]),
            .request(ControlRequest(command: .doctor, minutes: nil))
        )
        XCTAssertEqual(
            ControlCLIParser.parse(["debt"]),
            .request(ControlRequest(command: .debt, minutes: nil))
        )
    }

    func testHelpFlagsAndEmptyArgs() {
        for args in [[], ["help"], ["-h"], ["--help"]] {
            guard case let .help(text) = ControlCLIParser.parse(args) else {
                return XCTFail("expected help for \(args)")
            }
            XCTAssertTrue(text.contains("unchair status"))
            XCTAssertTrue(text.contains("unchair help"))
            XCTAssertTrue(text.contains("control.sock"))
        }
    }

    func testRejectsUnknownAndBadUsage() {
        guard case let .failure(unknown) = ControlCLIParser.parse(["complete"]) else {
            return XCTFail("expected failure for complete")
        }
        XCTAssertTrue(unknown.contains("unknown command complete"))

        guard case .failure = ControlCLIParser.parse(["break", "complete"]) else {
            return XCTFail("expected failure for break complete")
        }
        guard case let .failure(postpone) = ControlCLIParser.parse(["postpone"]) else {
            return XCTFail("expected failure for postpone without duration")
        }
        XCTAssertTrue(postpone.contains("usage: unchair postpone"))
    }
}
