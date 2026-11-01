import Foundation

enum BreakCameraState: Equatable, Sendable {
    case idle
    case running
    case permissionDenied
    case unavailable(String)
}

enum CameraProbeResult: Equatable, Sendable {
    case ok(framesReceived: Int)
    case permissionDenied
    case unavailable(String)
    case timeout
}

/// Starts local camera capture only while a timed break is active, and always
/// stops it when the break ends so the system camera indicator clears.
@MainActor
final class BreakCameraCoordinator {
    private let authorizer: any CameraAuthorizing
    private let capture: any CameraCapturing
    private let pipeline: InMemoryFramePipeline
    private var breakWantsCamera = false

    private(set) var state: BreakCameraState = .idle
    private(set) var lastProbeResult: CameraProbeResult?

    init(
        authorizer: any CameraAuthorizing,
        capture: any CameraCapturing,
        pipeline: InMemoryFramePipeline = InMemoryFramePipeline()
    ) {
        self.authorizer = authorizer
        self.capture = capture
        self.pipeline = pipeline
    }

    func handlePhaseChange(_ phase: BreakPhase) async {
        switch phase {
        case .onBreak:
            breakWantsCamera = true
            await startIfNeeded()
        case .idle, .working, .breakDue, .postponed, .deferredForPresentation, .paused:
            breakWantsCamera = false
            stopIfNeeded()
        }
    }

    /// Manual validation helper: request permission, confirm frames arrive in memory, then
    /// stop unless a break still needs the camera.
    func runProbe(timeoutSeconds: TimeInterval = 3) async -> CameraProbeResult {
        let status = await authorizer.requestAccess()
        guard status == .authorized else {
            let result = CameraProbeResult.permissionDenied
            lastProbeResult = result
            state = .permissionDenied
            return result
        }

        let alreadyRunning = capture.isRunning
        let baseline = pipeline.processedFrameCount

        capture.frameHandler = { [pipeline] frame in
            pipeline.process(frame)
        }

        if !alreadyRunning {
            do {
                try capture.start()
                state = .running
            } catch CameraCaptureError.unavailable(let reason) {
                let result = CameraProbeResult.unavailable(reason)
                lastProbeResult = result
                state = .unavailable(reason)
                capture.stop()
                return result
            } catch {
                let result = CameraProbeResult.unavailable(error.localizedDescription)
                lastProbeResult = result
                state = .unavailable(error.localizedDescription)
                capture.stop()
                return result
            }
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if pipeline.processedFrameCount > baseline {
                break
            }
            try? await Task.sleep(for: .milliseconds(50))
        }

        let received = pipeline.processedFrameCount - baseline
        let result: CameraProbeResult = received > 0
            ? .ok(framesReceived: received)
            : .timeout
        lastProbeResult = result

        if !breakWantsCamera {
            stopIfNeeded()
        }

        return result
    }

    private func startIfNeeded() async {
        if capture.isRunning {
            state = .running
            return
        }

        let status = await authorizer.requestAccess()
        guard status == .authorized else {
            state = .permissionDenied
            capture.stop()
            return
        }

        do {
            capture.frameHandler = { [pipeline] frame in
                pipeline.process(frame)
            }
            try capture.start()
            state = .running
        } catch CameraCaptureError.unavailable(let reason) {
            state = .unavailable(reason)
            capture.stop()
        } catch {
            state = .unavailable(error.localizedDescription)
            capture.stop()
        }
    }

    private func stopIfNeeded() {
        capture.stop()
        if state == .running {
            state = .idle
        } else if case .permissionDenied = state {
            // Keep denied visible until a later successful start.
        } else if case .unavailable = state {
            // Keep unavailable visible until a later successful start.
        } else {
            state = .idle
        }
    }
}
