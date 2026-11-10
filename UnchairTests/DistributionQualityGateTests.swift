import XCTest
@testable import Unchair

/// #115 — keep Direct distribution bits (version, Sparkle, cask, release script, docs) coherent.
final class DistributionQualityGateTests: XCTestCase {
    func testMarketingVersionMatchesHomebrewCask() throws {
        let version = try marketingVersion()
        let cask = try String(contentsOf: try XCTUnwrap(Self.repoFile("Casks/unchair.rb")), encoding: .utf8)
        XCTAssertTrue(
            cask.contains("version \"\(version)\""),
            "Casks/unchair.rb must ship the same SemVer as project.yml (\(version))"
        )
        XCTAssertTrue(
            cask.contains("releases/download/v#{version}/Unchair-#{version}-macos.dmg"),
            "cask URL must point at the notarized GitHub Releases DMG"
        )
        XCTAssertTrue(cask.contains("auto_updates true"))
        XCTAssertTrue(cask.contains("depends_on macos: :sonoma"))
    }

    func testChangelogHasSectionForMarketingVersion() throws {
        let version = try marketingVersion()
        let changelog = try String(contentsOf: try XCTUnwrap(Self.repoFile("CHANGELOG.md")), encoding: .utf8)
        XCTAssertTrue(
            changelog.contains("## [\(version)]"),
            "CHANGELOG.md must include ## [\(version)] before that version is tagged"
        )
        XCTAssertTrue(changelog.contains("## [Unreleased]"))
    }

    func testDirectInfoPlistWiresSparkleFeed() throws {
        let plist = try String(contentsOf: try XCTUnwrap(Self.repoFile("Unchair/Info.plist")), encoding: .utf8)
        XCTAssertTrue(plist.contains("SUFeedURL"))
        XCTAssertTrue(
            plist.contains("https://github.com/EtienneDeneuve/unchair/releases/latest/download/appcast.xml")
        )
        XCTAssertTrue(plist.contains("SUPublicEDKey"))
        XCTAssertTrue(plist.contains("SUEnableAutomaticChecks"))
    }

    func testAppStoreInfoPlistHasNoSparkleKeys() throws {
        let plist = try String(contentsOf: try XCTUnwrap(Self.repoFile("Unchair/Info-AppStore.plist")), encoding: .utf8)
        for key in ["SUFeedURL", "SUPublicEDKey", "SUEnableAutomaticChecks", "SUScheduledCheckInterval"] {
            XCTAssertFalse(plist.contains(key), "MAS Info.plist must not embed \(key)")
        }
    }

    func testReleaseScriptCoversNotarizeStapleSpctlAndAppcast() throws {
        let script = try String(contentsOf: try XCTUnwrap(Self.repoFile("scripts/release.sh")), encoding: .utf8)
        for needle in [
            "notarytool",
            "stapler staple",
            "spctl -a -vv",
            "package-dmg.sh",
            "sign_update",
            "appcast.xml",
            "bump-homebrew-cask",
        ] {
            XCTAssertTrue(script.contains(needle), "release.sh should include \(needle)")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: try XCTUnwrap(Self.repoFile("scripts/package-dmg.sh")).path))
    }

    func testPublicDocsCrossLinkDistributionGate() throws {
        let readme = try String(contentsOf: try XCTUnwrap(Self.repoFile("README.md")), encoding: .utf8)
        let distribution = try String(contentsOf: try XCTUnwrap(Self.repoFile("docs/DISTRIBUTION.md")), encoding: .utf8)
        let release = try String(contentsOf: try XCTUnwrap(Self.repoFile("docs/RELEASE.md")), encoding: .utf8)
        let gate = try String(
            contentsOf: try XCTUnwrap(Self.repoFile("docs/distribution-quality-gate.md")),
            encoding: .utf8
        )
        let checklist = try String(
            contentsOf: try XCTUnwrap(Self.repoFile("docs/release-communication-checklist.md")),
            encoding: .utf8
        )

        XCTAssertTrue(readme.contains("Unchair-latest-macos.dmg"))
        XCTAssertTrue(readme.contains("brew install --cask"))
        XCTAssertTrue(readme.contains("docs/distribution-quality-gate.md"))

        XCTAssertTrue(distribution.localizedCaseInsensitiveContains("Sparkle"))
        XCTAssertTrue(distribution.localizedCaseInsensitiveContains("Homebrew"))
        XCTAssertTrue(distribution.contains("release-communication-checklist.md"))

        XCTAssertTrue(release.localizedCaseInsensitiveContains("notar"))
        XCTAssertTrue(release.contains("spctl"))

        for needle in ["Clean Mac install", "Sparkle", "spctl", "CHANGELOG", "Known limitations"] {
            XCTAssertTrue(gate.localizedCaseInsensitiveContains(needle), "gate doc should mention \(needle)")
        }

        XCTAssertTrue(checklist.contains("spctl -a -vv"))
        XCTAssertTrue(checklist.contains("Homebrew"))
    }

    func testDistributionChannelURLsStayOnHttpsGitHub() {
        XCTAssertEqual(DistributionChannel.latestDirectReleaseURL.scheme, "https")
        XCTAssertEqual(DistributionChannel.latestDirectReleaseURL.host, "github.com")
        XCTAssertTrue(DistributionChannel.current.offersInAppUpdates)
        XCTAssertEqual(DistributionChannel.current.displayName, "Direct (GitHub)")
    }

    // MARK: - Helpers

    private func marketingVersion() throws -> String {
        let yaml = try String(contentsOf: try XCTUnwrap(Self.repoFile("project.yml")), encoding: .utf8)
        let pattern = #"MARKETING_VERSION:\s*"([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(yaml.startIndex..<yaml.endIndex, in: yaml)
        let match = try XCTUnwrap(regex.firstMatch(in: yaml, range: range))
        let capture = try XCTUnwrap(Range(match.range(at: 1), in: yaml))
        return String(yaml[capture])
    }

    private static func repoFile(_ relative: String) -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()
        url.deleteLastPathComponent()
        let candidate = url.appendingPathComponent(relative)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
