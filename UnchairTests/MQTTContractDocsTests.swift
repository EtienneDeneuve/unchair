import XCTest

final class MQTTContractDocsTests: XCTestCase {
    func testMQTTContractDocumentCoversRequiredTopics() throws {
        let url = try XCTUnwrap(Self.repoFile("docs/mqtt-contract.md"))
        let text = try String(contentsOf: url, encoding: .utf8)

        for needle in [
            "contractVersion",
            "unchair/<device_id>/state",
            "unchair/<device_id>/event",
            "unchair/<device_id>/availability",
            "unchair/<device_id>/command",
            "Last Will",
            "uniq_id",
            "MQTT Discovery",
            "landmarks",
            "device_id",
            "QoS",
            "retain",
        ] {
            XCTAssertTrue(
                text.localizedCaseInsensitiveContains(needle),
                "mqtt-contract.md should mention \(needle)"
            )
        }

        // Retention semantics must be explicit for state vs event.
        XCTAssertTrue(text.contains("non-retained") || text.contains("**no**"))
        XCTAssertTrue(text.contains("retain"))
    }

    func testReadmeLinksMQTTContract() throws {
        let url = try XCTUnwrap(Self.repoFile("README.md"))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("docs/mqtt-contract.md"))
    }

    private static func repoFile(_ relative: String) -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
