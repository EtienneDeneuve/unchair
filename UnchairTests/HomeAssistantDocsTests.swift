import XCTest

final class HomeAssistantDocsTests: XCTestCase {
    func testHomeAssistantGuideCoversSetupPrivacyAndHarness() throws {
        let text = try contents("docs/home-assistant.md")
        for needle in [
            "optional",
            "Mosquitto",
            "least privilege",
            "unchair/<device_id>/#",
            "privacy",
            "landmarks",
            "mqtt-integration-smoke",
            "UNCHAIR_MQTT_INTEGRATION",
            "medical",
            "admin credentials",
        ] {
            XCTAssertTrue(
                text.localizedCaseInsensitiveContains(needle),
                "docs/home-assistant.md should mention \(needle)"
            )
        }
    }

    func testExamplesExistWithLeastPrivilegeACL() throws {
        let acl = try contents("examples/home-assistant/mosquitto/acl.example")
        XCTAssertTrue(acl.contains("unchair/uch_"))
        XCTAssertTrue(acl.contains("readwrite"))
        XCTAssertFalse(
            acl.split(separator: "\n").contains(where: { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("topic") && trimmed.hasSuffix(" #") && !trimmed.contains("homeassistant")
            }),
            "Unchair ACL example must not grant topic #"
        )

        XCTAssertNotNil(repoFile("examples/home-assistant/lovelace/unchair-dashboard.yaml"))
        XCTAssertNotNil(repoFile("examples/home-assistant/automations/break-due-desk-light.yaml"))
        XCTAssertNotNil(repoFile("examples/home-assistant/mosquitto/docker-compose.yml"))
        XCTAssertNotNil(repoFile("scripts/mqtt-integration-smoke.sh"))
    }

    func testPrivacyDocLinksHomeAssistantGuide() throws {
        let text = try contents("docs/PRIVACY.md")
        XCTAssertTrue(text.contains("home-assistant.md"))
        XCTAssertTrue(text.localizedCaseInsensitiveContains("MQTT"))
    }

    func testReadmeLinksHomeAssistantDocsAndExamples() throws {
        let text = try contents("README.md")
        XCTAssertTrue(text.contains("docs/home-assistant.md"))
        XCTAssertTrue(text.contains("examples/home-assistant/"))
        XCTAssertTrue(text.contains("start_break"))
    }

    private func contents(_ relative: String) throws -> String {
        let url = try XCTUnwrap(repoFile(relative))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func repoFile(_ relative: String) -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
