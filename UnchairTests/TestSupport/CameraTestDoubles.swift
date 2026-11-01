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

@MainActor
final class FakeCameraCapture: CameraCapturing {
    enum Availability {
        case available
        case unavailable(reason: String)
    }

    private let availability: Availability
    private(set) var isRunning = false
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var frameHandler: ((EphemeralFrame) -> Void)?

    init(availability: Availability = .available) {
        self.availability = availability
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
    }

    func stop() {
        if isRunning {
            stopCount += 1
        }
        isRunning = false
        frameHandler = nil
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
