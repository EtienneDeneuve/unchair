import XCTest
@testable import Unchair

/// #139 — source gates for the Mac App Store signing / export pipeline.
final class MASReleasePipelineTests: XCTestCase {
    func testProjectDefinesSparkleFreeAppStoreTarget() throws {
        let yaml = try String(contentsOf: try XCTUnwrap(Self.repoFile("project.yml")), encoding: .utf8)
        XCTAssertTrue(yaml.contains("UnchairAppStore:"))
        XCTAssertTrue(yaml.contains("UnchairAppCommon"))
        // Scheme Unchair-MAS must archive the Sparkle-free target.
        XCTAssertTrue(yaml.contains("Unchair-MAS:"))
        let masRange = try XCTUnwrap(yaml.range(of: "Unchair-MAS:"))
        let after = yaml[masRange.lowerBound...]
        XCTAssertTrue(after.contains("UnchairAppStore: all"))
    }

    func testReleaseMasScriptIsFailClosed() throws {
        let script = try String(contentsOf: try XCTUnwrap(Self.repoFile("scripts/release-mas.sh")), encoding: .utf8)
        for needle in [
            "MARKETING_VERSION",
            "CHANGELOG.md",
            "xcodebuild archive",
            "exportArchive",
            "Sparkle.framework",
            "network.server",
            "UPLOAD",
            "whats-new",
            "FAILED",
        ] {
            XCTAssertTrue(script.contains(needle), "release-mas.sh should include \(needle)")
        }
        XCTAssertTrue(script.contains("fail()"), "script must fail closed before claiming success")
    }

    func testExportOptionsAreAppStoreConnect() throws {
        let plist = try String(
            contentsOf: try XCTUnwrap(Self.repoFile("scripts/ExportOptions-mas.plist")),
            encoding: .utf8
        )
        XCTAssertTrue(plist.contains("app-store-connect"))
        XCTAssertTrue(plist.contains("H3QDKGAJ35"))
        XCTAssertTrue(plist.contains("manageAppVersionAndBuildNumber"))
    }

    func testReleaseMasDocsAndWorkflowExist() throws {
        let docs = try String(contentsOf: try XCTUnwrap(Self.repoFile("docs/RELEASE-MAS.md")), encoding: .utf8)
        let workflow = try String(
            contentsOf: try XCTUnwrap(Self.repoFile(".github/workflows/release-mas.yml")),
            encoding: .utf8
        )
        let ci = try String(contentsOf: try XCTUnwrap(Self.repoFile(".github/workflows/ci.yml")), encoding: .utf8)

        XCTAssertTrue(docs.contains("mas-release"))
        XCTAssertTrue(docs.contains("Apple Distribution"))
        XCTAssertTrue(docs.contains("CHANGELOG.md"))
        XCTAssertTrue(workflow.contains("environment: mas-release"))
        XCTAssertTrue(workflow.contains("unsigned-gate"))
        XCTAssertTrue(workflow.contains("signed-release"))
        XCTAssertTrue(workflow.contains("refusing to report a successful MAS release"))
        XCTAssertTrue(ci.contains("Unchair-MAS"))
        XCTAssertTrue(ci.contains("Sparkle.framework must not ship"))
    }

    // MARK: - Helpers

    private static func repoFile(_ relative: String) -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
