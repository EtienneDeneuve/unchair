import AppKit
import AVFoundation
import Foundation
import Observation

enum MenuBarCommand: Equatable, Hashable {
    case nextBreakStatus
    case startBreakNow
    case postponeMenu
    case presentationModeMenu
    case pauseResume
    case today
    case settings
    case quit
}

@MainActor
@Observable
final class MenuBarShell {
    static let commands: [MenuBarCommand] = [
        .nextBreakStatus,
        .startBreakNow,
        .postponeMenu,
        .presentationModeMenu,
        .pauseResume,
        .today,
        .settings,
        .quit,
    ]

    private let scheduler: BreakScheduler
    private let overlayController: any BreakOverlayPresenting
    private let cameraCoordinator: BreakCameraCoordinator
    private let manualPresentationMode: ManualPresentationMode?
    private let history: BreakHistoryRecorder
    private let launchAtLogin: any LaunchAtLoginControlling

    /// While the status-item menu is open, skip `@Observable` publishes that
    /// rebuild MenuBarExtra and steal the highlighted/selected row each second.
    private var isStatusMenuTracking = false
    private var menuTrackingObservers: [NSObjectProtocol] = []

    private(set) var isSettingsPresented = false
    private(set) var statusRevision = 0
    private(set) var cameraProbeStatusText = "Not tested yet"
    private(set) var isCameraProbeRunning = false
    private(set) var launchAtLoginError: String?

    init(
        scheduler: BreakScheduler,
        overlayController: any BreakOverlayPresenting = BreakOverlayController(),
        cameraCoordinator: BreakCameraCoordinator? = nil,
        manualPresentationMode: ManualPresentationMode? = nil,
        history: BreakHistoryRecorder? = nil,
        launchAtLogin: (any LaunchAtLoginControlling)? = nil,
        observesMenuTracking: Bool = true,
        startsPeriodicTicker: Bool = true,
        primesCameraAtLaunch: Bool = true
    ) {
        self.scheduler = scheduler
        self.overlayController = overlayController
        self.manualPresentationMode = manualPresentationMode
        self.history = history ?? BreakHistoryRecorder(
            store: InMemoryBreakHistoryStore(),
            clock: SystemBreakClock()
        )
        self.launchAtLogin = launchAtLogin ?? SMAppLaunchAtLoginController()
        let resolvedCamera = cameraCoordinator ?? BreakCameraCoordinator(
            authorizer: AVCameraAuthorizer(),
            capture: AVCameraCapture()
        )
        self.cameraCoordinator = resolvedCamera
        resolvedCamera.onPostureChange = { [weak self] in
            guard let self else { return }
            // Keep Settings live while previewing; otherwise respect menu-tracking
            // so countdown ticks don't rebuild MenuBarExtra under the cursor.
            self.publishMenuBarObservation(force: self.isPosturePreviewActive)
        }
        overlayController.attach(shell: self)
        scheduler.start()
        if observesMenuTracking {
            startMenuTrackingObservers()
        }
        if startsPeriodicTicker {
            startTicking()
        }
        syncOverlay()
        if primesCameraAtLaunch {
            primeCameraAccessAtLaunch()
        }
    }

    /// Test seam: simulate status-item menu open/closed.
    func setStatusMenuTracking(_ tracking: Bool) {
        isStatusMenuTracking = tracking
        if !tracking {
            publishMenuBarObservation(force: true)
        }
    }

    /// Test seam: one scheduler/overlay tick.
    func performPeriodicTick() {
        bumpStatus()
    }

    /// Ask for camera access once when the app starts — never during a break.
    private func primeCameraAccessAtLaunch() {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.cameraCoordinator.primeCameraAccessAtLaunch()
            self.publishMenuBarObservation(force: true)
            self.syncOverlay()
        }
    }

    /// Live sit/stand reading for Settings (updates while the preview camera runs).
    var postureStatusText: String {
        _ = statusRevision
        return cameraCoordinator.postureEstimate.statusText
    }

    var posturePreviewSession: AVCaptureSession? {
        _ = statusRevision
        return cameraCoordinator.previewSession
    }

    var posturePreviewJoints: [BodyJoint: PoseJoint] {
        _ = statusRevision
        return cameraCoordinator.lastPoseJoints
    }

    var postureDetailText: String {
        _ = statusRevision
        let joints = cameraCoordinator.lastPoseJointCount
        let frames = cameraCoordinator.previewFrameCount
        switch cameraAuthorizationStatus {
        case .notDetermined:
            return "Waiting for the launch camera prompt…"
        case .denied, .restricted:
            return "Camera blocked — enable Unchair in System Settings → Privacy & Security → Camera."
        case .authorized:
            break
        }
        switch cameraCoordinator.state {
        case .running:
            if frames == 0 {
                return "Camera warming up…"
            }
            if joints == 0 {
                return "Camera live · \(frames) frames · no body pose yet (center yourself)"
            }
            return "Camera live · \(joints) joints · \(frames) frames"
        case .permissionDenied:
            return "Camera permission denied"
        case .unavailable(let reason):
            return "Camera unavailable · \(reason)"
        case .idle:
            return "Camera idle · last reading kept"
        }
    }

    var isPosturePreviewActive: Bool {
        _ = statusRevision
        if case .running = cameraCoordinator.state {
            return true
        }
        return false
    }

    var cameraAuthorizationStatus: CameraAuthorizationStatus {
        _ = statusRevision
        return cameraCoordinator.cameraAuthorizationStatus
    }

    /// Starts the Settings preview only if camera access was already granted.
    func startPosturePreview() {
        cameraCoordinator.armSettingsPreview()
        publishMenuBarObservation(force: true)
        Task { [weak self] in
            await self?.cameraCoordinator.startSettingsPreview()
            self?.publishMenuBarObservation(force: true)
            self?.syncOverlay()
        }
    }

    /// User-initiated: may show the system camera prompt once.
    func enableCameraAccess() {
        cameraCoordinator.armSettingsPreview()
        publishMenuBarObservation(force: true)
        Task { [weak self] in
            _ = await self?.cameraCoordinator.enableCameraAccess()
            self?.publishMenuBarObservation(force: true)
            self?.syncOverlay()
        }
    }

    func stopPosturePreview() {
        cameraCoordinator.stopSettingsPreview()
        publishMenuBarObservation(force: true)
        syncOverlay()
    }

    convenience init() {
        let clock = SystemBreakClock()
        let presentationGuard = PresentationGuard.makeSystem(clock: clock)
        self.init(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: presentationGuard,
                store: UserDefaultsBreakLifecycleStore()
            ),
            manualPresentationMode: presentationGuard.manualPresentationMode,
            history: BreakHistoryRecorder(
                store: FileBreakHistoryStore(),
                clock: clock
            )
        )
    }

    var historyRecords: [BreakHistoryRecord] {
        _ = statusRevision
        return history.records
    }

    var historyEntryCount: Int {
        _ = statusRevision
        return history.records.count
    }

    var todayStats: TodayStats {
        _ = statusRevision
        return TodayStatsCalculator.make(
            records: history.records,
            now: Date(),
            sittingStartedAt: scheduler.snapshot.sittingStartedAt,
            nextBreakSummary: nextBreakStatusText
        )
    }

    /// Compact menu-bar line: "Today · 2 done" or empty-state friendly.
    var todayMenuSummary: String {
        let stats = todayStats
        if stats.isEmpty {
            return "Today · no breaks yet"
        }
        return "Today · \(stats.completedCount) done · \(stats.skippedCount) skipped"
    }

    func clearBreakHistory() {
        history.clearAll()
        publishMenuBarObservation(force: true)
    }

    var isLaunchAtLoginEnabled: Bool {
        _ = statusRevision
        return launchAtLogin.isEnabled
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        publishMenuBarObservation(force: true)
    }

    func openToday() {
        TodayWindowController.shared.show(shell: self)
    }

    var isPresentationModeEnabled: Bool {
        _ = statusRevision
        manualPresentationMode?.tick()
        return manualPresentationMode?.isActive == true
    }

    var presentationModePresets: [BreakDuration] {
        ManualPresentationMode.durationPresets
    }

    func enablePresentationMode(for duration: BreakDuration) {
        manualPresentationMode?.enable(for: duration)
        bumpStatus()
    }

    func enablePresentationMode(until date: Date) {
        manualPresentationMode?.enable(until: date)
        bumpStatus()
    }

    func enablePresentationModeUntilDisabled() {
        manualPresentationMode?.enableUntilDisabled()
        bumpStatus()
    }

    func disablePresentationMode() {
        manualPresentationMode?.disable()
        bumpStatus()
    }

    var phase: BreakPhase {
        _ = statusRevision
        scheduler.evaluate()
        return scheduler.snapshot.phase
    }

    var nextBreakStatusText: String {
        switch phase {
        case .idle:
            return "Next break: —"
        case .working:
            if let remaining = scheduler.snapshot.remainingWork {
                let base = "Next break: \(Self.formatCountdown(remaining.seconds))"
                return Self.appendDebtSuffix(base, debt: scheduler.snapshot.movementDebt)
            }
            return "Next break: —"
        case .breakDue:
            let debt = scheduler.snapshot.movementDebt
            if debt.isActive, debt.currentDuration.seconds > 0 {
                return "Break due now · debt \(Self.formatCountdown(debt.currentDuration.seconds))"
            }
            return "Break due now"
        case .onBreak:
            if let remaining = scheduler.snapshot.remainingBreak {
                return "On break: \(Self.formatCountdown(remaining.seconds))"
            }
            return "On break"
        case .postponed:
            if let remaining = scheduler.snapshot.remainingWork {
                let base = "Postponed: \(Self.formatCountdown(remaining.seconds))"
                return Self.appendDebtSuffix(base, debt: scheduler.snapshot.movementDebt)
            }
            return "Postponed"
        case .deferredForPresentation:
            if isPresentationModeEnabled {
                return "Deferred (Presentation Mode)"
            }
            return "Deferred (presentation)"
        case .paused:
            if let remaining = scheduler.snapshot.remainingWork {
                return "Paused (\(Self.formatCountdown(remaining.seconds)) left)"
            }
            return "Paused"
        }
    }

    /// Compact title shown directly in the macOS menu bar item.
    var menuBarTitleText: String {
        switch phase {
        case .idle:
            return "—"
        case .working:
            if let remaining = scheduler.snapshot.remainingWork {
                return Self.formatCountdown(remaining.seconds)
            }
            return "—"
        case .breakDue:
            return "DUE"
        case .onBreak:
            if let remaining = scheduler.snapshot.remainingBreak {
                return Self.formatCountdown(remaining.seconds)
            }
            return "0:00"
        case .postponed:
            if let remaining = scheduler.snapshot.remainingWork {
                return Self.formatCountdown(remaining.seconds)
            }
            return "…"
        case .deferredForPresentation:
            return "HOLD"
        case .paused:
            if let remaining = scheduler.snapshot.remainingWork {
                return Self.formatCountdown(remaining.seconds)
            }
            return "⏸"
        }
    }

    var menuBarSymbolName: String {
        switch phase {
        case .breakDue, .onBreak:
            return "figure.stand"
        case .postponed, .deferredForPresentation:
            return "clock.badge.exclamationmark"
        case .paused:
            return "pause.fill"
        case .idle, .working:
            return "timer"
        }
    }

    var isPaused: Bool {
        if case .paused = phase { return true }
        return false
    }

    var canPostpone: Bool {
        switch phase {
        case .breakDue, .onBreak, .postponed, .deferredForPresentation:
            return true
        case .idle, .working, .paused:
            return false
        }
    }

    var postponePresets: [BreakDuration] {
        BreakScheduler.postponePresets
    }

    var settings: BreakSettings {
        scheduler.settings
    }

    var overlayModel: BreakOverlayModel {
        let snapshot = scheduler.snapshot
        switch snapshot.phase {
        case .onBreak:
            return .active(
                remaining: snapshot.remainingBreak ?? .seconds(0),
                verificationStatus: verificationStatus(for: cameraCoordinator.state),
                canComplete: cameraCoordinator.canCompleteBreak,
                proofProgressText: cameraCoordinator.movementProofStatus.progressText()
            )
        case .breakDue:
            return .due(
                sittingSeconds: snapshot.sittingDuration?.seconds
                    ?? snapshot.settings.workInterval.seconds,
                breakDuration: snapshot.settings.breakDuration,
                verificationStatus: .waitingToStart
            )
        default:
            return .due(
                sittingSeconds: snapshot.settings.workInterval.seconds,
                breakDuration: snapshot.settings.breakDuration,
                verificationStatus: .waitingToStart
            )
        }
    }

    func startBreakNow() {
        scheduler.startBreakNow()
        noteHistoryPrompt()
        bumpStatus()
    }

    func beginTimedBreak() {
        scheduler.beginTimedBreak()
        let snap = scheduler.snapshot
        history.noteTimedBreakStarted(
            breakID: snap.breakID,
            scheduledAt: snap.sittingStartedAt
        )
        bumpStatus()
    }

    func skipBreak() {
        history.recordSkipped()
        scheduler.skipBreak()
        bumpStatus()
    }

    func completeBreak() {
        guard cameraCoordinator.canCompleteBreak else { return }
        if cameraCoordinator.allowsUnverifiedCompletion {
            scheduler.noteVerificationFailed()
        } else {
            scheduler.noteMovementVerified()
        }
        history.recordCompleted(verification: currentHistoryVerification())
        scheduler.completeBreak()
        bumpStatus()
    }

    func handleOverlayPrimary() {
        switch phase {
        case .breakDue:
            beginTimedBreak()
        case .onBreak:
            completeBreak()
        default:
            break
        }
    }

    func postpone(by duration: BreakDuration) {
        noteHistoryPromptIfNeeded()
        history.recordPostponed()
        scheduler.postpone(by: duration)
        bumpStatus()
    }

    func postpone(until date: Date) {
        noteHistoryPromptIfNeeded()
        history.recordPostponed()
        scheduler.postpone(until: date)
        bumpStatus()
    }

    private func noteHistoryPrompt() {
        let snap = scheduler.snapshot
        history.noteBreakPrompted(
            breakID: snap.breakID,
            scheduledAt: snap.sittingStartedAt
        )
    }

    private func noteHistoryPromptIfNeeded() {
        // Postpone from due/on-break/deferred should attribute the owed break.
        noteHistoryPrompt()
    }

    private func currentHistoryVerification() -> BreakHistoryVerification {
        if cameraCoordinator.allowsUnverifiedCompletion {
            return BreakHistoryVerification(
                stoodForSeconds: nil,
                motionScore: nil,
                failedOpen: true
            )
        }
        switch cameraCoordinator.movementProofStatus {
        case .verified(let stoodFor, let motionScore):
            return BreakHistoryVerification(
                stoodForSeconds: stoodFor,
                motionScore: motionScore,
                failedOpen: false
            )
        case .standing(let elapsed, let motionScore):
            return BreakHistoryVerification(
                stoodForSeconds: elapsed,
                motionScore: motionScore,
                failedOpen: false
            )
        case .inactive, .awaitingStand:
            return BreakHistoryVerification(
                stoodForSeconds: nil,
                motionScore: nil,
                failedOpen: false
            )
        }
    }

    func togglePause() {
        if isPaused {
            scheduler.resume()
        } else {
            scheduler.pause()
        }
        bumpStatus()
    }

    func updateSettings(_ settings: BreakSettings) {
        scheduler.updateSettings(settings)
        bumpStatus()
    }

    func openSettings() {
        isSettingsPresented = true
        SettingsWindowController.shared.show(shell: self)
    }

    func runCameraProbe() {
        guard !isCameraProbeRunning else { return }
        isCameraProbeRunning = true
        cameraProbeStatusText = "Testing camera…"
        publishMenuBarObservation(force: true)

        Task { [weak self] in
            guard let self else { return }
            let result = await self.cameraCoordinator.runProbe(timeoutSeconds: 6)
            self.cameraProbeStatusText = Self.describe(probe: result)
            self.isCameraProbeRunning = false
            self.publishMenuBarObservation(force: true)
            self.syncOverlay()
        }
    }

    private static func describe(probe: CameraProbeResult) -> String {
        switch probe {
        case .ok(let frames):
            return "OK · \(frames) in-memory frame\(frames == 1 ? "" : "s") received · camera stopped"
        case .permissionDenied:
            return "Permission denied · enable Camera for Unchair in System Settings"
        case .unavailable(let reason):
            return "Unavailable · \(reason)"
        case .timeout:
            return "Timeout · no frames received (check that another app isn’t holding the camera)"
        }
    }

    private func startMenuTrackingObservers() {
        let center = NotificationCenter.default
        menuTrackingObservers.append(
            center.addObserver(
                forName: NSMenu.didBeginTrackingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isStatusMenuTracking = true
                }
            }
        )
        menuTrackingObservers.append(
            center.addObserver(
                forName: NSMenu.didEndTrackingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.isStatusMenuTracking = false
                    self?.publishMenuBarObservation(force: true)
                    self?.syncOverlay()
                }
            }
        )
    }

    private func startTicking() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                await self.bumpStatus()
            }
        }
    }

    private func bumpStatus() {
        scheduler.evaluate()
        syncVerificationIntoStateMachine()
        let currentPhase = scheduler.snapshot.phase
        if case .breakDue = currentPhase {
            noteHistoryPrompt()
        }
        // Overlay keeps ticking; menu-bar SwiftUI only republishes when safe.
        publishMenuBarObservation()
        syncOverlay()
        Task { [weak self] in
            guard let self else { return }
            let priorState = self.cameraCoordinator.state
            let priorProof = self.cameraCoordinator.movementProofStatus
            await self.cameraCoordinator.handlePhaseChange(currentPhase)
            self.syncVerificationIntoStateMachine()
            let cameraChanged =
                priorState != self.cameraCoordinator.state
                || priorProof != self.cameraCoordinator.movementProofStatus
            if cameraChanged {
                self.publishMenuBarObservation()
            }
            self.syncOverlay()
        }
    }

    private func publishMenuBarObservation(force: Bool = false) {
        guard force || !isStatusMenuTracking else { return }
        statusRevision &+= 1
    }

    /// Movement detector reports into the lifecycle — never mutates phase directly.
    private func syncVerificationIntoStateMachine() {
        guard scheduler.snapshot.phase.isOnBreak else { return }
        if cameraCoordinator.allowsUnverifiedCompletion {
            scheduler.noteVerificationFailed()
            return
        }
        switch cameraCoordinator.movementProofStatus {
        case .inactive, .awaitingStand:
            break
        case .standing:
            scheduler.noteStandDetected()
        case .verified:
            scheduler.noteStandDetected()
            scheduler.noteMovementVerified()
        }
    }

    private func syncOverlay() {
        overlayController.sync(with: self)
    }

    private func verificationStatus(for cameraState: BreakCameraState) -> BreakVerificationStatus {
        switch cameraState {
        case .permissionDenied:
            return .permissionDenied
        case .unavailable:
            return .cameraUnavailable
        case .idle, .running:
            break
        }

        switch cameraCoordinator.movementProofStatus {
        case .verified:
            return .verified
        case .standing:
            return .standingDetected
        case .awaitingStand:
            return cameraState == .running ? .capturing : .pendingMovement
        case .inactive:
            return cameraState == .running ? .capturing : .pendingMovement
        }
    }

    static func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }

    static func appendDebtSuffix(_ base: String, debt: MovementDebt) -> String {
        guard debt.isActive, debt.currentDuration.seconds > 0 else { return base }
        return "\(base) · debt \(formatCountdown(debt.currentDuration.seconds))"
    }
}
