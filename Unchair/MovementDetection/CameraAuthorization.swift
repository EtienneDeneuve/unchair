import AVFoundation
import Foundation

enum CameraAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum CameraUsageRationale {
    static let text = """
    Unchair uses the camera only during a movement break to verify that you stood up and moved. \
    Frames are processed in memory on this Mac and are never saved or uploaded.
    """

    static let infoPlistKey = "NSCameraUsageDescription"
}

@MainActor
protocol CameraAuthorizing: AnyObject {
    var status: CameraAuthorizationStatus { get }
    func requestAccess() async -> CameraAuthorizationStatus
}

@MainActor
final class AVCameraAuthorizer: CameraAuthorizing {
    var status: CameraAuthorizationStatus {
        Self.map(AVCaptureDevice.authorizationStatus(for: .video))
    }

    func requestAccess() async -> CameraAuthorizationStatus {
        switch status {
        case .authorized, .denied, .restricted:
            return status
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            return granted ? .authorized : .denied
        }
    }

    private static func map(_ status: AVAuthorizationStatus) -> CameraAuthorizationStatus {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}
