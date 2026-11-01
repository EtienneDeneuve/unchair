import Foundation

/// In-memory camera frame handle. Intentionally carries no image bytes and no file URL.
final class EphemeralFrame {
    let pixelCount: Int
    private let onDeinit: (() -> Void)?

    init(pixelCount: Int, onDeinit: (() -> Void)? = nil) {
        self.pixelCount = pixelCount
        self.onDeinit = onDeinit
    }

    deinit {
        onDeinit?()
    }
}

/// Test-only seam to prove the pipeline never asks to persist frames.
protocol FrameDiskWriting: AnyObject {
    func writeFrameData(_ data: Data, to path: String) throws
}

/// Processes frames in memory and retains none after `process` returns.
@MainActor
final class InMemoryFramePipeline {
    private let disk: FrameDiskWriting?
    private(set) var processedFrameCount = 0
    private(set) var lastPixelCount: Int?

    init(disk: FrameDiskWriting? = nil) {
        self.disk = disk
    }

    func process(_ frame: EphemeralFrame) {
        // Derived signal only. Never encode, write, or stash the frame.
        lastPixelCount = frame.pixelCount
        processedFrameCount += 1
        // Deliberately do not call disk. Presence of the optional is for spies in tests.
        _ = disk
    }

    var retainsFramesAfterProcessing: Bool { false }
}
