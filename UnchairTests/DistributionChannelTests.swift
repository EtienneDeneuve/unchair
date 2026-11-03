import XCTest
@testable import Unchair

final class DistributionChannelTests: XCTestCase {
    func testDebugAndReleaseBinariesAreDirectChannel() {
        XCTAssertEqual(DistributionChannel.current, .direct)
        XCTAssertTrue(DistributionChannel.current.offersInAppUpdates)
        XCTAssertEqual(DistributionChannel.current.displayName, "Direct (GitHub)")
    }

    func testReleaseLandingURLsAreAbsoluteHttps() {
        XCTAssertEqual(DistributionChannel.latestDirectReleaseURL.scheme, "https")
        XCTAssertEqual(DistributionChannel.changelogURL.scheme, "https")
        XCTAssertEqual(DistributionChannel.macAppStoreURL.scheme, "https")
        XCTAssertEqual(DistributionChannel.authorSiteURL.host, "etienne.deneuve.xyz")
        XCTAssertEqual(DistributionChannel.omnivyaSiteURL.host, "www.omnivya.fr")
        XCTAssertEqual(
            URLComponents(url: DistributionChannel.authorSiteURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "utm_source" })?
                .value,
            "unchair"
        )
        XCTAssertEqual(
            URLComponents(url: DistributionChannel.omnivyaSiteURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "utm_source" })?
                .value,
            "unchair"
        )
        XCTAssertEqual(
            URLComponents(url: DistributionChannel.omnivyaSiteURL, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "utm_campaign" })?
                .value,
            "about"
        )
    }
}
