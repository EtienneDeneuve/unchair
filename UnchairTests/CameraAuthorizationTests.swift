import XCTest
@testable import Unchair

@MainActor
final class CameraAuthorizationTests: XCTestCase {
    func testFirstUseRequestsAccessWithRationaleAvailable() async {
        let authorizer = FakeCameraAuthorizer(initial: .notDetermined, grantOnRequest: .authorized)
        XCTAssertEqual(authorizer.status, .notDetermined)
        XCTAssertFalse(CameraUsageRationale.text.isEmpty)
        XCTAssertTrue(CameraUsageRationale.text.lowercased().contains("break"))
        XCTAssertTrue(CameraUsageRationale.text.lowercased().contains("memory"))

        let status = await authorizer.requestAccess()
        XCTAssertEqual(status, .authorized)
        XCTAssertEqual(authorizer.requestCount, 1)
    }

    func testDeniedPermissionIsReportedWithoutThrowing() async {
        let authorizer = FakeCameraAuthorizer(initial: .denied, grantOnRequest: .denied)
        let status = await authorizer.requestAccess()
        XCTAssertEqual(status, .denied)
        XCTAssertEqual(authorizer.status, .denied)
    }
}
