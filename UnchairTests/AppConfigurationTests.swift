import XCTest
@testable import Unchair

final class AppConfigurationTests: XCTestCase {
    func testAppRunsAsMenuBarAgentWithoutDockIcon() {
        XCTAssertTrue(AppConfiguration.suppressesDockIcon)
        XCTAssertEqual(AppConfiguration.activationPolicy, .accessory)
    }

    func testBundleModulesMatchArchitectureBoundaries() {
        XCTAssertEqual(
            AppConfiguration.sourceModules,
            [
                "App",
                "BreakEngine",
                "MovementDetection",
                "History",
                "UI",
            ]
        )
    }
}
