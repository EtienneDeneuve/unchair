import XCTest
@testable import Unchair

final class LocalControlServerTests: XCTestCase {
    func testFirstLineReturnsWholePayloadWithoutNewline() {
        let data = Data(#"{"command":"status"}"#.utf8)

        XCTAssertEqual(
            LocalControlServer.firstLine(in: data),
            data
        )
    }

    func testFirstLineStopsAtFirstNewline() {
        let first = Data(#"{"command":"status"}"#.utf8)
        let second = Data(#"{"command":"debt"}"#.utf8)

        var payload = first
        payload.append(0x0A)
        payload.append(second)
        payload.append(0x0A)

        XCTAssertEqual(
            LocalControlServer.firstLine(in: payload),
            first
        )
    }

    func testFirstLineHandlesLeadingNewline() {
        var payload = Data()
        payload.append(0x0A)
        payload.append(contentsOf: Data(#"{"command":"status"}"#.utf8))

        XCTAssertTrue(
            LocalControlServer.firstLine(in: payload).isEmpty
        )
    }
}
