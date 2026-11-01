import Foundation

enum BreakCameraState: Equatable, Sendable {
    case idle
    case running
    case permissionDenied
    case unavailable(String)
}

/// Starts local camera capture only while a timed break is active, and always
/// stops it when the break ends so the system camera indicator clears.
@MainActor
final class BreakCameraCoordinator {
    private let authorizer: any CameraAuthorizing
    private let capture: any CameraCapturing
    private let pipeline: InMemoryFramePipeline

    private(set) var state: BreakCameraState = .idle

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
            await startIfNeeded()
        case .idle, .working, .breakDue, .postponed, .deferredForPresentation, .paused:
            stopIfNeeded()
        }
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
