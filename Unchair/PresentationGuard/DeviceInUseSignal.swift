import AVFoundation
import Foundation

protocol MediaDeviceInspecting: AnyObject {
    var isCameraInUseByAnotherApplication: Bool { get }
    var isMicrophoneInUseByAnotherApplication: Bool { get }
}

/// Reads `AVCaptureDevice.isInUseByAnotherApplication` for default video/audio devices.
///
/// Results are TTL-cached — AVCapture default-device lookup is expensive and was
/// dominating idle CPU when PresentationGuard ran every menu-bar / scheduler tick.
final class AVMediaDeviceInspector: MediaDeviceInspecting {
    private let lock = NSLock()
    private let ttl: TimeInterval
    private let now: () -> Date
    private var cachedAt: Date?
    private var cachedCamera = false
    private var cachedMicrophone = false

    init(ttl: TimeInterval = 2.0, now: @escaping () -> Date = Date.init) {
        self.ttl = ttl
        self.now = now
    }

    var isCameraInUseByAnotherApplication: Bool {
        refreshIfNeeded()
        lock.lock()
        defer { lock.unlock() }
        return cachedCamera
    }

    var isMicrophoneInUseByAnotherApplication: Bool {
        refreshIfNeeded()
        lock.lock()
        defer { lock.unlock() }
        return cachedMicrophone
    }

    private func refreshIfNeeded() {
        lock.lock()
        let instant = now()
        if let cachedAt, instant.timeIntervalSince(cachedAt) < ttl {
            lock.unlock()
            return
        }
        lock.unlock()

        // Probe outside the lock — AVFoundation can block briefly.
        let camera = AVCaptureDevice.default(for: .video)?.isInUseByAnotherApplication == true
        let microphone = AVCaptureDevice.default(for: .audio)?.isInUseByAnotherApplication == true

        lock.lock()
        cachedCamera = camera
        cachedMicrophone = microphone
        cachedAt = instant
        lock.unlock()
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
