import AVFoundation
import Foundation

protocol MediaDeviceInspecting: AnyObject {
    var isCameraInUseByAnotherApplication: Bool { get }
    var isMicrophoneInUseByAnotherApplication: Bool { get }
}

/// Reads `AVCaptureDevice.isInUseByAnotherApplication` for default video/audio devices.
final class AVMediaDeviceInspector: MediaDeviceInspecting {
    var isCameraInUseByAnotherApplication: Bool {
        AVCaptureDevice.default(for: .video)?.isInUseByAnotherApplication == true
    }

    var isMicrophoneInUseByAnotherApplication: Bool {
        AVCaptureDevice.default(for: .audio)?.isInUseByAnotherApplication == true
    }
}

final class CameraInUseSignal: PresentationSignalSource {
    private let inspector: any MediaDeviceInspecting
    var reason: PresentationBlockReason { .cameraInUseByAnotherApp }
    var isActive: Bool { inspector.isCameraInUseByAnotherApplication }

    init(inspector: any MediaDeviceInspecting) {
        self.inspector = inspector
    }
}

final class MicrophoneInUseSignal: PresentationSignalSource {
    private let inspector: any MediaDeviceInspecting
    var reason: PresentationBlockReason { .microphoneInUseByAnotherApp }
    var isActive: Bool { inspector.isMicrophoneInUseByAnotherApplication }

    init(inspector: any MediaDeviceInspecting) {
        self.inspector = inspector
    }
}
