import AVFoundation
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
    private var detector: SitToStandDetector
    private var movementProof: MovementProofTracker
    private var breakWantsCamera = false
    /// While a Settings probe owns the session, phase ticks must not tear it down.
    private var probeInFlight = false
    /// Live posture preview while the Settings window is open.
    private var settingsPreviewInFlight = false

    private(set) var state: BreakCameraState = .idle
    private(set) var lastProbeResult: CameraProbeResult?
    private(set) var postureEstimate: PostureEstimate = .unknown
    private(set) var lastSitToStand: SitToStandEvent?
    private(set) var lastPoseJointCount = 0
    private(set) var previewFrameCount = 0
    private(set) var lastPoseJoints: [BodyJoint: PoseJoint] = [:]
    private(set) var movementProofStatus: MovementProofStatus = .inactive

    /// Fired on the main actor whenever a new pose updates the published estimate.
    var onPostureChange: (() -> Void)?

    var posture: PostureState { postureEstimate.state }

    /// Shared capture session for the Settings skeleton preview (nil in tests).
    var previewSession: AVCaptureSession? { capture.previewSession }

    var cameraAuthorizationStatus: CameraAuthorizationStatus { authorizer.status }

    /// When camera cannot verify, completion stays allowed so the loop never soft-locks.
    var allowsUnverifiedCompletion: Bool {
        switch state {
        case .permissionDenied, .unavailable:
            return true
        case .idle, .running:
            return false
        }
    }

    var canCompleteBreak: Bool {
        movementProofStatus.isVerified || allowsUnverifiedCompletion
    }

    /// Arm before the async camera start so menu-bar ticks cannot win the race.
    func armSettingsPreview() {
        settingsPreviewInFlight = true
    }

    init(
        authorizer: any CameraAuthorizing,
        capture: any CameraCapturing,
        pipeline: InMemoryFramePipeline = InMemoryFramePipeline(),
        detector: SitToStandDetector = SitToStandDetector(),
        movementProof: MovementProofTracker = MovementProofTracker()
    ) {
        self.authorizer = authorizer
        self.capture = capture
        self.pipeline = pipeline
        self.detector = detector
        self.movementProof = movementProof
    }

    func handlePhaseChange(_ phase: BreakPhase) async {
        switch phase {
        case .onBreak:
            let enteringBreak = !breakWantsCamera
            breakWantsCamera = true
            if enteringBreak {
                movementProof.beginBreak()
                movementProofStatus = movementProof.status
            }
            // Never prompt here — permission is primed once at app launch.
            await startIfNeeded(requestPermission: false)
        case .idle, .working, .breakDue, .postponed, .deferredForPresentation, .paused:
            if breakWantsCamera {
                movementProof.reset()
                movementProofStatus = .inactive
            }
            breakWantsCamera = false
            stopIfNeeded()
        }
    }

    /// Resume a live preview only when camera access is already granted.
    /// Never triggers the system permission sheet — Settings must not nag.
    func startSettingsPreview() async {
        settingsPreviewInFlight = true
        previewFrameCount = 0
        await startIfNeeded(requestPermission: false)
        onPostureChange?()
    }

    /// One-shot system prompt at process start when status is still undecided.
    /// Breaks and Settings must not call `requestAccess` themselves.
    @discardableResult
    func primeCameraAccessAtLaunch() async -> CameraAuthorizationStatus {
        let status: CameraAuthorizationStatus
        if authorizer.status == .notDetermined {
            status = await authorizer.requestAccess()
        } else {
            status = authorizer.status
        }
        if status != .authorized {
            state = (status == .notDetermined) ? .idle : .permissionDenied
        }
        onPostureChange?()
        return status
    }

    /// Settings recovery path if launch priming was skipped/denied.
    @discardableResult
    func enableCameraAccess() async -> CameraAuthorizationStatus {
        settingsPreviewInFlight = true
        previewFrameCount = 0
        let status = await authorizer.requestAccess()
        if status == .authorized {
            await startIfNeeded(requestPermission: false)
        } else {
            state = .permissionDenied
            onPostureChange?()
        }
        return status
    }

    func stopSettingsPreview() {
        settingsPreviewInFlight = false
        stopIfNeeded()
    }

    /// Manual validation helper: request permission, confirm frames arrive in memory, then
    /// stop unless a break still needs the camera.
    func runProbe(timeoutSeconds: TimeInterval = 3) async -> CameraProbeResult {
        probeInFlight = true
        defer {
            probeInFlight = false
            if !breakWantsCamera && !settingsPreviewInFlight {
                stopIfNeeded()
            }
        }

        let status = await authorizer.requestAccess()
        guard status == .authorized else {
            let result = CameraProbeResult.permissionDenied
            lastProbeResult = result
            state = .permissionDenied
            return result
        }

        let alreadyRunning = capture.isRunning
        let baseline = capture.framesReceivedSinceStart
        attachHandlers()

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

        // Warm up: first frames can take >1s after startRunning.
        let deadline = Date().addingTimeInterval(max(timeoutSeconds, 5))
        while Date() < deadline {
            if capture.framesReceivedSinceStart > baseline {
                break
            }
            try? await Task.sleep(for: .milliseconds(50))
        }

        let received = capture.framesReceivedSinceStart - baseline
        let result: CameraProbeResult = received > 0
            ? .ok(framesReceived: received)
            : .timeout
        lastProbeResult = result
        return result
    }

    private func startIfNeeded(requestPermission: Bool) async {
        if capture.isRunning {
            state = .running
            attachHandlers()
            return
        }

        let status: CameraAuthorizationStatus
        if requestPermission {
            status = await authorizer.requestAccess()
        } else {
            status = authorizer.status
        }

        guard status == .authorized else {
            // Stay idle when still undecided so Settings can show an Enable button
            // without looking like a hard denial.
            state = (status == .notDetermined) ? .idle : .permissionDenied
            if status != .notDetermined {
                capture.stop()
            }
            return
        }

        do {
            detector.reset()
            postureEstimate = .unknown
            lastSitToStand = nil
            attachHandlers()
            try capture.start()
            state = .running
            onPostureChange?()
        } catch CameraCaptureError.unavailable(let reason) {
            state = .unavailable(reason)
            capture.stop()
        } catch {
            state = .unavailable(error.localizedDescription)
            capture.stop()
        }
    }

    private func attachHandlers() {
        capture.frameHandler = { [weak self] frame in
            Task { @MainActor in
                guard let self else { return }
                self.pipeline.process(frame)
                if self.settingsPreviewInFlight || self.breakWantsCamera {
                    self.previewFrameCount += 1
                    self.onPostureChange?()
                }
            }
        }
        capture.poseHandler = { [weak self] sample in
            Task { @MainActor in
                self?.ingestPose(sample)
            }
        }
    }

    private func ingestPose(_ sample: PoseSample) {
        postureEstimate = detector.process(sample)
        lastPoseJoints = detector.lastSmoothedJoints
        lastPoseJointCount = lastPoseJoints.count
        lastSitToStand = detector.lastSitToStand
        if breakWantsCamera {
            movementProofStatus = movementProof.process(
                sample: sample,
                posture: postureEstimate.state,
                sitToStand: lastSitToStand
            )
        }
        onPostureChange?()
    }

    private var shouldKeepCamera: Bool {
        breakWantsCamera || probeInFlight || settingsPreviewInFlight
    }

    private func stopIfNeeded() {
        if shouldKeepCamera {
            return
        }
        // Avoid spamming posture observers every scheduler tick while already idle —
        // that republished MenuBarExtra and stole the highlighted menu row.
        let shouldNotify = capture.isRunning || state == .running
        capture.stop()
        detector.reset()
        // Keep the last estimate visible in Settings until the next session.
        if !breakWantsCamera {
            lastSitToStand = nil
        }
        if state == .running {
            state = .idle
        } else if case .permissionDenied = state {
            // Keep denied visible until a later successful start.
        } else if case .unavailable = state {
            // Keep unavailable visible until a later successful start.
        } else {
            state = .idle
        }
        if shouldNotify {
            onPostureChange?()
        }
    }
}
