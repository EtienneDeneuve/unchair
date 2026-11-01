import CoreVideo
import XCTest
@testable import Unchair

final class SubjectLifterTests: XCTestCase {
    func testCoverageCountsBrightMaskPixels() throws {
        let width = 32
        let height = 32
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_OneComponent8,
            nil,
            &buffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        let mask = try XCTUnwrap(buffer)

        CVPixelBufferLockBaseAddress(mask, [])
        defer { CVPixelBufferUnlockBaseAddress(mask, []) }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let base = try XCTUnwrap(CVPixelBufferGetBaseAddress(mask)).assumingMemoryBound(to: UInt8.self)

        // Left half subject, right half background.
        for y in 0..<height {
            for x in 0..<width {
                base[y * bytesPerRow + x] = x < width / 2 ? 255 : 0
            }
        }

        let coverage = VisionPersonSubjectLifter.coverage(of: mask, stride: 1)
        XCTAssertEqual(coverage, 0.5, accuracy: 0.02)
    }

    func testStubLifterReportsCoverageWithoutMasking() {
        var stub = StubSubjectLifter(coverage: 0.33, maskEnabled: false)
        // Empty tiny buffer — stub ignores contents.
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            8,
            8,
            kCVPixelFormatType_32BGRA,
            nil,
            &buffer
        )
        guard let buffer else {
            XCTFail("buffer")
            return
        }

        XCTAssertEqual(stub.subjectCoverage(in: buffer), 0.33)
        XCTAssertNil(stub.maskedPixelBuffer(from: buffer))

        stub.maskEnabled = true
        let lifted = stub.maskedPixelBuffer(from: buffer)
        XCTAssertEqual(lifted?.coverage, 0.33)
    }

    func testPoseSampleCarriesSubjectCoverage() {
        let sample = PoseSample(
            joints: [.root: .init(x: 0.5, y: 0.5, confidence: 0.9)],
            subjectCoverage: 0.42
        )
        XCTAssertEqual(sample.subjectCoverage, 0.42)
    }

    func testEstimatorWithoutLifterStillBuildsSamplePath() {
        // Ensures wiring compiles with lifter disabled (hardware pose not asserted).
        let estimator = VisionBodyPoseEstimator(subjectLifter: nil)
        XCTAssertNil(estimator.subjectLifter)
    }
}
