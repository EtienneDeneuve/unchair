import XCTest
@testable import Unchair

@MainActor
final class FramePipelineTests: XCTestCase {
    func testProcessedFramesAreReleasedAndNeverPersisted() async {
        let disk = SpyFrameDisk()
        let pipeline = InMemoryFramePipeline(disk: disk)
        var released = 0

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let frame = EphemeralFrame(pixelCount: 12) {
                released += 1
                continuation.resume()
            }
            pipeline.process(frame)
        }

        XCTAssertEqual(released, 1)
        XCTAssertEqual(pipeline.processedFrameCount, 1)
        XCTAssertFalse(pipeline.retainsFramesAfterProcessing)
        XCTAssertEqual(disk.writeAttempts, 0)
        XCTAssertTrue(disk.writtenPaths.isEmpty)
    }
}
