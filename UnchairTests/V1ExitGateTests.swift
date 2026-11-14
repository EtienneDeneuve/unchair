import XCTest

/// #116 — repo-side exit criteria for Mac standalone 1.0.0 (artifacts still need release.sh).
final class V1ExitGateTests: XCTestCase {
    func testMarketingVersionIsOneZeroZero() throws {
        let yaml = try String(contentsOf: try XCTUnwrap(Self.repoFile("project.yml")), encoding: .utf8)
        XCTAssertTrue(yaml.contains("MARKETING_VERSION: \"1.0.0\""))
        let cask = try String(contentsOf: try XCTUnwrap(Self.repoFile("Casks/unchair.rb")), encoding: .utf8)
        XCTAssertTrue(cask.contains("version \"1.0.0\""))
    }

    func testChangelogHasOneZeroZeroSection() throws {
        let changelog = try String(contentsOf: try XCTUnwrap(Self.repoFile("CHANGELOG.md")), encoding: .utf8)
        XCTAssertTrue(changelog.contains("## [1.0.0]"))
        XCTAssertTrue(changelog.localizedCaseInsensitiveContains("standalone"))
        XCTAssertFalse(changelog.localizedCaseInsensitiveContains("diagnos"))
        XCTAssertFalse(changelog.localizedCaseInsensitiveContains("cure"))
        XCTAssertFalse(changelog.localizedCaseInsensitiveContains("medical device"))
    }

    func testExitGateDocTracksClosedChildren() throws {
        let gate = try String(contentsOf: try XCTUnwrap(Self.repoFile("docs/v1.0-exit-gate.md")), encoding: .utf8)
        for issue in ["#109", "#110", "#111", "#112", "#113", "#114", "#115", "#116"] {
            XCTAssertTrue(gate.contains(issue), "exit gate should list \(issue)")
        }
        XCTAssertTrue(gate.contains("release.sh 1.0.0"))
        XCTAssertTrue(gate.localizedCaseInsensitiveContains("No child deferred"))
    }

    func testRoadmapMarksV1TrainComplete() throws {
        let roadmap = try String(contentsOf: try XCTUnwrap(Self.repoFile("ROADMAP.md")), encoding: .utf8)
        for needle in [
            "- [x] #108",
            "- [x] #115",
            "- [x] #116",
            "docs/v1.0-exit-gate.md",
        ] {
            XCTAssertTrue(roadmap.contains(needle), "ROADMAP should contain \(needle)")
        }
    }

    private static func repoFile(_ relative: String) -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
