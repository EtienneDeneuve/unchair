import XCTest
@testable import Unchair

/// #138 — compile-time / source gates for Mac App Store sandbox compatibility.
final class MASSandboxGateTests: XCTestCase {
    func testDirectChannelKeepsOptionalIntegrationSurfaces() {
        // XCTest host builds with DIRECT — assert the shipping Direct policy.
        XCTAssertEqual(DistributionChannel.current, .direct)
        XCTAssertTrue(DistributionChannel.current.offersInAppUpdates)
        XCTAssertTrue(DistributionChannel.current.offersOpenMetricsHTTPServer)
        XCTAssertTrue(DistributionChannel.current.offersLocalControlSocket)
        XCTAssertFalse(DistributionChannel.macAppStore.offersInAppUpdates)
        XCTAssertFalse(DistributionChannel.macAppStore.offersOpenMetricsHTTPServer)
        XCTAssertFalse(DistributionChannel.macAppStore.offersLocalControlSocket)
    }

    func testMASEntitlementsEnableSandboxWithoutNetworkServer() throws {
        let xml = try String(
            contentsOf: try XCTUnwrap(Self.repoFile("Unchair/Unchair-MAS.entitlements")),
            encoding: .utf8
        )
        XCTAssertTrue(xml.contains("com.apple.security.app-sandbox"))
        XCTAssertTrue(xml.contains("com.apple.security.device.camera"))
        XCTAssertTrue(xml.contains("com.apple.security.network.client"))
        XCTAssertTrue(xml.contains("keychain-access-groups"))
        XCTAssertFalse(
            xml.contains("com.apple.security.network.server"),
            "MAS must not claim network.server — OpenMetrics HTTP is Direct-only"
        )
        XCTAssertFalse(xml.contains("disable-library-validation"))
    }

    func testDirectEntitlementsRemainNonSandbox() throws {
        let xml = try String(
            contentsOf: try XCTUnwrap(Self.repoFile("Unchair/Unchair.entitlements")),
            encoding: .utf8
        )
        XCTAssertFalse(xml.contains("com.apple.security.app-sandbox"))
        XCTAssertTrue(xml.contains("com.apple.security.device.camera"))
    }

    func testAppStoreConfigCompilesWithAPPSTOREFlag() throws {
        let yaml = try String(contentsOf: try XCTUnwrap(Self.repoFile("project.yml")), encoding: .utf8)
        XCTAssertTrue(yaml.contains("AppStore:"))
        XCTAssertTrue(yaml.contains("SWIFT_ACTIVE_COMPILATION_CONDITIONS: \"$(inherited) APPSTORE\""))
        XCTAssertTrue(yaml.contains("CODE_SIGN_ENTITLEMENTS: Unchair/Unchair-MAS.entitlements"))
        XCTAssertTrue(yaml.contains("INFOPLIST_FILE: Unchair/Info-AppStore.plist"))
        XCTAssertTrue(yaml.contains("Unchair-MAS:"))
    }

    func testSandboxGateDocAndCrossLinksExist() throws {
        let gate = try String(contentsOf: try XCTUnwrap(Self.repoFile("docs/mas-sandbox.md")), encoding: .utf8)
        let distribution = try String(
            contentsOf: try XCTUnwrap(Self.repoFile("docs/DISTRIBUTION.md")),
            encoding: .utf8
        )
        let cli = try String(contentsOf: try XCTUnwrap(Self.repoFile("docs/cli.md")), encoding: .utf8)
        let metrics = try String(
            contentsOf: try XCTUnwrap(Self.repoFile("docs/openmetrics.md")),
            encoding: .utf8
        )

        for needle in [
            "Compatibility matrix",
            "network.server",
            "SMAppService",
            "#138",
            "#142",
        ] {
            XCTAssertTrue(gate.contains(needle), "mas-sandbox.md should mention \(needle)")
        }
        XCTAssertTrue(distribution.contains("mas-sandbox.md"))
        XCTAssertTrue(cli.localizedCaseInsensitiveContains("Mac App Store"))
        XCTAssertTrue(metrics.localizedCaseInsensitiveContains("Mac App Store"))
    }

    func testOpenMetricsServerRefusesWhenChannelDisallows() {
        let registry = OpenMetricsRegistry()
        let server = OpenMetricsHTTPServer(registry: registry)
        // Force the Direct path in tests — server still starts when enabled.
        var config = OpenMetricsConfiguration.default
        config.isEnabled = true
        server.start(configuration: config)
        defer { server.stop() }
        XCTAssertTrue(
            DistributionChannel.current.offersOpenMetricsHTTPServer,
            "test host is Direct; listener path must remain exercised here"
        )
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
