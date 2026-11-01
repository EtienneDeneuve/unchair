import AVFoundation
import Foundation
@testable import Unchair

@MainActor
final class FakeCameraAuthorizer: CameraAuthorizing {
    private(set) var status: CameraAuthorizationStatus
    private let grantOnRequest: CameraAuthorizationStatus
    private(set) var requestCount = 0

    init(initial: CameraAuthorizationStatus, grantOnRequest: CameraAuthorizationStatus) {
        self.status = initial
        self.grantOnRequest = grantOnRequest
    }

    func requestAccess() async -> CameraAuthorizationStatus {
        requestCount += 1
        status = grantOnRequest
        return status
    }
}

final class FakeCameraCapture: CameraCapturing {
    enum Availability {
        case available
        case unavailable(reason: String)
    }

    private let availability: Availability
    private let emitsFramesOnStart: Int
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var framesReceivedSinceStart = 0
    var previewSession: AVCaptureSession? { nil }
    private let emitsPosesOnStart: [PoseSample]
    var frameHandler: ((EphemeralFrame) -> Void)? {
        didSet {
            // Probe may attach a handler while capture is already running for a break.
            if isRunning {
                emitFrames()
            }
        }
    }
    var poseHandler: ((PoseSample) -> Void)? {
        didSet {
            if isRunning {
                emitPoses()
            }
        }
    }

    init(
        availability: Availability = .available,
        emitsFramesOnStart: Int = 0,
        emitsPosesOnStart: [PoseSample] = []
    ) {
        self.availability = availability
        self.emitsFramesOnStart = emitsFramesOnStart
        self.emitsPosesOnStart = emitsPosesOnStart
    }

    func prepare() throws {
        if case .unavailable(let reason) = availability {
            throw CameraCaptureError.unavailable(reason)
        }
    }

    func start() throws {
        try prepare()
        isRunning = true
        startCount += 1
        framesReceivedSinceStart = 0
        emitConfiguredFrames()
    }

    private func emitConfiguredFrames() {
        emitPoses()
        emitFrames()
    }

    private func emitPoses() {
        guard let poseHandler, !emitsPosesOnStart.isEmpty else { return }
        for pose in emitsPosesOnStart {
            poseHandler(pose)
        }
    }

    private func emitFrames() {
        guard emitsFramesOnStart > 0, let frameHandler else { return }
        for index in 0..<emitsFramesOnStart {
            framesReceivedSinceStart += 1
            frameHandler(EphemeralFrame(pixelCount: 100 + index))
        }
    }

    func stop() {
        if isRunning {
            stopCount += 1
        }
        isRunning = false
        frameHandler = nil
        poseHandler = nil
    }
}

final class SpyFrameDisk: FrameDiskWriting {
    private(set) var writeAttempts = 0
    private(set) var writtenPaths: [String] = []

    func writeFrameData(_ data: Data, to path: String) throws {
        writeAttempts += 1
        writtenPaths.append(path)
    }
}
