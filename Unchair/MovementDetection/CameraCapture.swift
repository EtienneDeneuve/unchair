import AVFoundation
import Foundation

enum CameraCaptureError: Error, Equatable {
    case unavailable(String)
    case permissionDenied
    case persistenceForbidden
}

protocol CameraCapturing: AnyObject {
    var isRunning: Bool { get }
    var frameHandler: ((EphemeralFrame) -> Void)? { get set }
    /// Thread-safe count of frames observed since the last `start()`.
    var framesReceivedSinceStart: Int { get }
    func prepare() throws
    func start() throws
    func stop()
}

/// Local AVFoundation capture. Frames are handed to `frameHandler` as ephemeral
/// in-memory values only — this type never writes media to disk.
final class AVCameraCapture: NSObject, CameraCapturing, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.etiennedeneuve.unchair.camera.session")
    private let sampleQueue = DispatchQueue(label: "com.etiennedeneuve.unchair.camera.sample")
    private let frameCounter = FrameCounter()
    private let handlerStorage = HandlerStorage()
    private let stateLock = NSLock()
    private var _isRunning = false

    var isRunning: Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return _isRunning
    }

    var frameHandler: ((EphemeralFrame) -> Void)? {
        get { handlerStorage.handler }
        set { handlerStorage.handler = newValue }
    }

    var framesReceivedSinceStart: Int { frameCounter.current() }

    func prepare() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        } else if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let device = Self.preferredVideoDevice() else {
            throw CameraCaptureError.unavailable("No camera available")
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            throw CameraCaptureError.unavailable(error.localizedDescription)
        }
        guard session.canAddInput(input) else {
            throw CameraCaptureError.unavailable("Cannot attach camera input")
        }
        session.addInput(input)

        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
        ]
        output.setSampleBufferDelegate(self, queue: sampleQueue)

        guard session.canAddOutput(output) else {
            throw CameraCaptureError.unavailable("Camera output unavailable")
        }
        session.addOutput(output)

        if let connection = output.connection(with: .video) {
            connection.isEnabled = true
        }
    }

    func start() throws {
        frameCounter.reset()

        if session.inputs.isEmpty || session.outputs.isEmpty {
            try prepare()
        }
        if session.isRunning {
            stateLock.lock()
            _isRunning = true
            stateLock.unlock()
            return
        }

        let session = self.session
        let started = sessionQueue.sync { () -> Bool in
            session.startRunning()
            return session.isRunning
        }
        stateLock.lock()
        _isRunning = started
        stateLock.unlock()
        if !started {
            throw CameraCaptureError.unavailable("Camera failed to start")
        }
    }

    func stop() {
        if session.isRunning {
            let session = self.session
            sessionQueue.sync {
                session.stopRunning()
            }
        }
        stateLock.lock()
        _isRunning = false
        stateLock.unlock()
        handlerStorage.handler = nil
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        // Derived size only — never retain/encode pixel bytes here.
        let pixelCount = width * height
        frameCounter.increment()
        let storage = handlerStorage
        DispatchQueue.main.async {
            storage.handler?(EphemeralFrame(pixelCount: pixelCount))
        }
    }

    private static func preferredVideoDevice() -> AVCaptureDevice? {
        let builtIn = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
        if let device = builtIn.first {
            return device
        }

        let external = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.continuityCamera, .external],
            mediaType: .video,
            position: .unspecified
        ).devices
        return external.first ?? AVCaptureDevice.default(for: .video)
    }
}

private final class FrameCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func reset() {
        lock.lock()
        value = 0
        lock.unlock()
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }

    func current() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

private final class HandlerStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var _handler: ((EphemeralFrame) -> Void)?

    var handler: ((EphemeralFrame) -> Void)? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _handler
        }
        set {
            lock.lock()
            _handler = newValue
            lock.unlock()
        }
    }
}
