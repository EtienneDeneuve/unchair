import XCTest
@testable import Unchair

final class PosePreviewCoordinateMappingTests: XCTestCase {
    func testLetterboxedContentRectCentersSixteenByNineInTallView() {
        let view = CGSize(width: 560, height: 320)
        // Taller-than-16:9 slot → letterbox (bars top/bottom).
        let tall = CGSize(width: 400, height: 400)
        let rect = PosePreviewCoordinateMapping.aspectFitContentRect(
            in: tall,
            contentAspect: 16.0 / 9.0
        )
        XCTAssertEqual(rect.width, 400, accuracy: 0.001)
        XCTAssertEqual(rect.height, 400 * 9.0 / 16.0, accuracy: 0.001)
        XCTAssertEqual(rect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(rect.minY, (400 - rect.height) / 2, accuracy: 0.001)

        let fitted = PosePreviewCoordinateMapping.aspectFitContentRect(
            in: view,
            contentAspect: 16.0 / 9.0
        )
        XCTAssertEqual(fitted.width, 560, accuracy: 0.001)
        XCTAssertEqual(fitted.height, 560 * 9.0 / 16.0, accuracy: 0.001)
    }

    func testPillarboxedContentRectCentersSixteenByNineInWideView() {
        let wide = CGSize(width: 800, height: 300)
        let rect = PosePreviewCoordinateMapping.aspectFitContentRect(
            in: wide,
            contentAspect: 16.0 / 9.0
        )
        XCTAssertEqual(rect.height, 300, accuracy: 0.001)
        XCTAssertEqual(rect.width, 300 * 16.0 / 9.0, accuracy: 0.001)
        XCTAssertEqual(rect.minY, 0, accuracy: 0.001)
        XCTAssertEqual(rect.minX, (800 - rect.width) / 2, accuracy: 0.001)
    }

    func testCenterJointLandsAtViewCenterWhenAspectMatches() {
        let size = CGSize(width: 640, height: 360)
        let content = PosePreviewCoordinateMapping.aspectFitContentRect(
            in: size,
            contentAspect: 16.0 / 9.0
        )
        let point = PosePreviewCoordinateMapping.viewPoint(
            for: PoseJoint(x: 0.5, y: 0.5, confidence: 1),
            contentRect: content,
            mirrored: false
        )
        XCTAssertEqual(point.x, 320, accuracy: 0.001)
        XCTAssertEqual(point.y, 180, accuracy: 0.001)
    }

    func testCornerJointUsesContentRectNotFullViewWhenLetterboxed() {
        let view = CGSize(width: 400, height: 400)
        let content = PosePreviewCoordinateMapping.aspectFitContentRect(
            in: view,
            contentAspect: 16.0 / 9.0
        )
        let topLeft = PosePreviewCoordinateMapping.viewPoint(
            for: PoseJoint(x: 0, y: 0, confidence: 1),
            contentRect: content,
            mirrored: false
        )
        XCTAssertEqual(topLeft.x, content.minX, accuracy: 0.001)
        XCTAssertEqual(topLeft.y, content.minY, accuracy: 0.001)
        XCTAssertGreaterThan(content.minY, 0)
    }

    func testMirroringFlipsXInsideContentRect() {
        let content = CGRect(x: 100, y: 40, width: 200, height: 100)
        let joint = PoseJoint(x: 0.25, y: 0.5, confidence: 1)
        let normal = PosePreviewCoordinateMapping.viewPoint(
            for: joint,
            contentRect: content,
            mirrored: false
        )
        let mirrored = PosePreviewCoordinateMapping.viewPoint(
            for: joint,
            contentRect: content,
            mirrored: true
        )
        XCTAssertEqual(normal.x, 150, accuracy: 0.001)
        XCTAssertEqual(mirrored.x, 250, accuracy: 0.001)
        XCTAssertEqual(normal.y, mirrored.y, accuracy: 0.001)
    }

    func testContentAspectFromMappedMetadataRect() {
        let mapped = CGRect(x: 10, y: 20, width: 320, height: 180)
        XCTAssertEqual(
            PosePreviewCoordinateMapping.contentAspect(fromMetadataMappedRect: mapped),
            320.0 / 180.0,
            accuracy: 0.0001
        )
    }
}
