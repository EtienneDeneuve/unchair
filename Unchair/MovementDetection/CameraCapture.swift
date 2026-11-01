import AVFoundation
import Foundation

enum CameraCaptureError: Error, Equatable {
    case unavailable(String)
    case permissionDenied
    case persistenceForbidden
}

@MainActor
protocol CameraCapturing: AnyObject {
    var isRunning: Bool { get }
    var frameHandler: ((EphemeralFrame) -> Void)? { get set }
    func prepare() throws
    func start() throws
    func stop()
}

/// Local AVFoundation capture. Frames are handed to `frameHandler` as ephemeral
/// in-memory values only — this type never writes media to disk.
@MainActor
final class AVCameraCapture: NSObject, CameraCapturing, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue(label: "com.etiennedeneuve.unchair.camera")
    private(set) var isRunning = false
    var frameHandler: ((EphemeralFrame) -> Void)?

    func prepare() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard
            let device = AVCaptureDevice.default(for: .video),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            throw CameraCaptureError.unavailable("No camera available")
        }

        session.addInput(input)
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]
        output.setSampleBufferDelegate(self, queue: sampleQueue)

        guard session.canAddOutput(output) else {
            throw CameraCaptureError.unavailable("Camera output unavailable")
        }
        session.addOutput(output)
    }

    func start() throws {
        if session.inputs.isEmpty {
            try prepare()
        }
        guard !session.isRunning else {
            isRunning = true
            return
        }
        session.startRunning()
        isRunning = session.isRunning
        if !isRunning {
            throw CameraCaptureError.unavailable("Camera failed to start")
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
        isRunning = false
        frameHandler = nil
    }

    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        // Copy only a derived size metric — not the pixel bytes — into the ephemeral frame.
        // Vision processing (#5/#6) will consume buffers in-memory at the call site later.
        let frame = EphemeralFrame(pixelCount: width * height)
        Task { @MainActor in
            self.frameHandler?(frame)
        }
        // sampleBuffer/pixelBuffer remain scoped to this callback and are released by AVFoundation.
    }
}
