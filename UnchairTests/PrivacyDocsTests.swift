import XCTest

final class PrivacyDocsTests: XCTestCase {
    func testPrivacyDocumentExistsAndCoversRequiredTopics() throws {
        let url = try XCTUnwrap(Self.repoFile("docs/PRIVACY.md"))
        let text = try String(contentsOf: url, encoding: .utf8)

        for needle in [
            "ephemeral",
            "Camera data flow",
            "never persisted",
            "Network behavior",
            "Permissions",
            "Debug logging",
            "landmarks",
        ] {
            XCTAssertTrue(
                text.localizedCaseInsensitiveContains(needle),
                "PRIVACY.md should mention \(needle)"
            )
        }
    }

    func testReadmeLinksToPrivacyDocument() throws {
        let url = try XCTUnwrap(Self.repoFile("README.md"))
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("docs/PRIVACY.md"))
    }

    private static func repoFile(_ relative: String) -> URL? {
        // UnchairTests/PrivacyDocsTests.swift → repo root
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent() // UnchairTests
        url.deleteLastPathComponent() // repo root
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
