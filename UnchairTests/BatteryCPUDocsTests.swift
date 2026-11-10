import XCTest

final class BatteryCPUDocsTests: XCTestCase {
    func testBatteryCPUDocumentCoversBudgetTopics() throws {
        let url = try XCTUnwrap(Self.repoFile("docs/battery-cpu.md"))
        let text = try String(contentsOf: url, encoding: .utf8)

        for needle in [
            "Cost posture",
            "Vision session",
            "lock",
            "MQTT",
            "OpenMetrics",
            "power-suspended",
        ] {
            XCTAssertTrue(
                text.localizedCaseInsensitiveContains(needle),
                "battery-cpu.md should mention \(needle)"
            )
        }
    }

    func testReadmeLinksToBatteryCPUDocument() throws {
        let url = try XCTUnwrap(Self.repoFile("README.md"))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("docs/battery-cpu.md"))
    }

    private static func repoFile(_ relative: String) -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
