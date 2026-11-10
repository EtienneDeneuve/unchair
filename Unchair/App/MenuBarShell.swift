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
    case about
    case checkForUpdates
    case quit
}

@MainActor
@Observable
final class MenuBarShell: MQTTCommandPerforming {
    static var commands: [MenuBarCommand] {
        var items: [MenuBarCommand] = [
            .nextBreakStatus,
            .startBreakNow,
            .postponeMenu,
            .presentationModeMenu,
            .pauseResume,
            .today,
            .settings,
            .about,
        ]
        if DistributionChannel.current.offersInAppUpdates {
            items.append(.checkForUpdates)
        }
        items.append(.quit)
        return items
    }

    private let scheduler: BreakScheduler
    private let overlayController: any BreakOverlayPresenting
    private let cameraCoordinator: BreakCameraCoordinator
    private let manualPresentationMode: ManualPresentationMode?
    private let history: BreakHistoryRecorder
    private let launchAtLogin: any LaunchAtLoginControlling
    private let onboarding: UserDefaultsOnboardingPreferences
    private let evidenceEngine: EvidenceEngine
    private let eventBus: DomainEventBus
    private let mqttClient: MQTTClientController
    private let mqttPublisher: MQTTHomeAssistantPublisher
    private let mqttCommandRouter: MQTTCommandRouter
    private let openMetrics: OpenMetricsController
    private let lifecycleTracer: BreakLifecycleTracer
    private let controlServer = LocalControlServer()
    private let updateController: any AppUpdateControlling
    private let presentsOnboardingAtLaunch: Bool

    /// While the status-item menu is open, skip `@Observable` publishes that
    /// rebuild MenuBarExtra and steal the highlighted/selected row each second.
    private var isStatusMenuTracking = false
    private var menuTrackingObservers: [NSObjectProtocol] = []

    private(set) var isSettingsPresented = false
    private(set) var statusRevision = 0
    private(set) var cameraProbeStatusText = "Not tested yet"
    private(set) var isCameraProbeRunning = false
    private(set) var launchAtLoginError: String?
    /// Preferred operating mode. Companions may still promote Standalone → Apple Enhanced.
    private(set) var operatingModePreference: UnchairOperatingMode
    /// Optional runtime override for tests / future sensors adapters.
    private var capabilityRuntimeOverride: CapabilityRuntimeSnapshot?

    init(
        scheduler: BreakScheduler,
        overlayController: any BreakOverlayPresenting = BreakOverlayController(),
        cameraCoordinator: BreakCameraCoordinator? = nil,
        manualPresentationMode: ManualPresentationMode? = nil,
        history: BreakHistoryRecorder? = nil,
        launchAtLogin: (any LaunchAtLoginControlling)? = nil,
        onboarding: UserDefaultsOnboardingPreferences? = nil,
        operatingModePreference: UnchairOperatingMode = .standalone,
        capabilityRuntimeOverride: CapabilityRuntimeSnapshot? = nil,
        evidenceEngine: EvidenceEngine = EvidenceEngine(),
        eventBus: DomainEventBus = DomainEventBus(),
        mqttClient: MQTTClientController? = nil,
        openMetrics: OpenMetricsController? = nil,
        lifecycleTracer: BreakLifecycleTracer? = nil,
        updateController: (any AppUpdateControlling)? = nil,
        observesMenuTracking: Bool = true,
        startsPeriodicTicker: Bool = true,
        primesCameraAtLaunch: Bool = true,
        presentsOnboardingAtLaunch: Bool = true
    ) {
        self.scheduler = scheduler
        self.overlayController = overlayController
        self.manualPresentationMode = manualPresentationMode
        self.history = history ?? BreakHistoryRecorder(
            store: InMemoryBreakHistoryStore(),
            clock: SystemBreakClock()
        )
        self.launchAtLogin = launchAtLogin ?? SMAppLaunchAtLoginController()
        self.onboarding = onboarding ?? UserDefaultsOnboardingPreferences()
        self.operatingModePreference = operatingModePreference
        self.capabilityRuntimeOverride = capabilityRuntimeOverride
        self.evidenceEngine = evidenceEngine
        self.eventBus = eventBus
        let resolvedMQTT = mqttClient ?? Self.makeDefaultMQTTClient()
        self.mqttClient = resolvedMQTT
        let publisher = MQTTHomeAssistantPublisher(client: resolvedMQTT, deviceId: resolvedMQTT.deviceId)
        self.mqttPublisher = publisher
        let commandRouter = MQTTCommandRouter()
        self.mqttCommandRouter = commandRouter
        let metrics = openMetrics ?? OpenMetricsController()
        self.openMetrics = metrics
        let tracer = lifecycleTracer ?? BreakLifecycleTracer()
        self.lifecycleTracer = tracer
        self.updateController = updateController ?? AppUpdateControllerFactory.make()
        self.presentsOnboardingAtLaunch = presentsOnboardingAtLaunch
        eventBus.addSink(publisher)
        eventBus.addSink(metrics.eventSinkAsDomainSink)
        eventBus.addSink(tracer)
        resolvedMQTT.onConnected = { [weak publisher] in
            await publisher?.noteConnected()
        }
        resolvedMQTT.onCommandPayload = { [weak commandRouter] data in
            commandRouter?.handle(payload: data)
        }
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
        publisher.stateProvider = { [weak self] in
            guard let self else {
                return (
                    BreakSnapshot(
                        phase: .idle,
                        settings: .default,
                        breakID: nil,
                        sittingStartedAt: nil,
                        sittingDuration: nil,
                        hasMovementDebt: false,
                        movementDebt: .cleared,
                        remainingWork: nil,
                        remainingBreak: nil
                    ),
                    TodayStats(
                        dayStart: Date(),
                        completedCount: 0,
                        skippedCount: 0,
                        postponedCount: 0,
                        movementSeconds: 0,
                        longestDeskSeconds: 0,
                        nextBreakSummary: "",
                        isEmpty: true
                    ),
                    false
                )
            }
            return (self.scheduler.snapshot, self.todayStats, self.isPresentationModeEnabled)
        }
        commandRouter.performer = self
        scheduler.start()
        self.mqttClient.startIfEnabled()
        self.openMetrics.startIfEnabled()
        if observesMenuTracking {
            startMenuTrackingObservers()
        }
        if startsPeriodicTicker {
            startTicking()
        }
        syncOverlay()
        refreshOpenMetricsGauges()
        // Local CLI control socket first — must not wait on camera priming / menu open.
        controlServer.start(shell: self)
        if primesCameraAtLaunch {
            syncCameraAuthorizationAtLaunch()
        }
        if presentsOnboardingAtLaunch {
            prepareFirstRunExperience()
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

    /// Refresh camera state without prompting. Onboarding / Settings own the system sheet.
    private func syncCameraAuthorizationAtLaunch() {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.cameraCoordinator.syncCameraAuthorizationAtLaunch()
            self.publishMenuBarObservation(force: true)
            self.syncOverlay()
        }
    }

    /// Existing installs skip the welcome window; fresh installs get guided setup.
    private func prepareFirstRunExperience() {
        onboarding.migrateIfNeeded(cameraStatus: cameraAuthorizationStatus)
        guard !onboarding.hasCompletedOnboarding else { return }
        DispatchQueue.main.async { [weak self] in
            self?.openOnboarding()
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
            return "Camera optional — enable verification in Settings → Camera when you want it."
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
        case .busy(let reason):
            return "Camera busy · \(reason)"
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
        let eventBus = DomainEventBus()
        self.init(
            scheduler: BreakScheduler(
                clock: clock,
                presentationGuard: presentationGuard,
                store: UserDefaultsBreakLifecycleStore(),
                eventPublisher: eventBus
            ),
            manualPresentationMode: presentationGuard.manualPresentationMode,
            history: BreakHistoryRecorder(
                store: FileBreakHistoryStore(),
                clock: clock
            ),
            eventBus: eventBus
        )
    }

    /// Integration adapters subscribe here; core behavior does not depend on sinks.
    var domainEventBus: DomainEventBus { eventBus }

    var mqttDeviceId: String { mqttClient.deviceId }

    var mqttConfiguration: MQTTConfiguration {
        _ = statusRevision
        return mqttClient.configuration
    }

    var mqttConnectionState: MQTTConnectionState {
        _ = statusRevision
        return mqttClient.connectionState
    }

    var mqttConnectionStatusText: String {
        switch mqttConnectionState {
        case .disabled: return "Disabled"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .reconnecting(let attempt): return "Reconnecting (attempt \(attempt))…"
        case .failed(let message): return "Failed — \(message)"
        }
    }

    func updateMQTTConfiguration(_ configuration: MQTTConfiguration) {
        mqttClient.updateConfiguration(configuration)
        if configuration.isEnabled {
            mqttClient.startIfEnabled()
        } else {
            mqttPublisher.noteStopped()
        }
        publishMenuBarObservation(force: true)
    }

    func saveMQTTPassword(_ password: String) {
        do {
            try mqttClient.savePassword(password)
        } catch {
            // Keychain failures are non-fatal for the break loop.
        }
        publishMenuBarObservation(force: true)
    }

    var openMetricsConfiguration: OpenMetricsConfiguration {
        _ = statusRevision
        return openMetrics.configuration
    }

    var openMetricsStatusText: String {
        _ = statusRevision
        return openMetrics.statusText
    }

    func updateOpenMetricsConfiguration(_ configuration: OpenMetricsConfiguration) {
        openMetrics.updateConfiguration(configuration)
        publishMenuBarObservation(force: true)
    }

    /// Local CLI control plane. Cannot complete a break or fake verification.
    func handleControlRequest(_ request: ControlRequest) -> ControlResponse {
        switch request.command {
        case .status:
            return .success(
                """
                phase: \(scheduler.snapshot.phase)
                next: \(nextBreakStatusText)
                presentation: \(isPresentationModeEnabled ? "on" : "off")
                channel: \(distributionChannelDisplayName)
                """
            )
        case .debt:
            let debt = scheduler.snapshot.movementDebt
            let minutes = Int((debt.currentDuration.seconds / 60).rounded())
            return .success(
                debt.isActive
                    ? "movement debt: \(minutes)m (active)"
                    : "movement debt: cleared"
            )
        case .breakStart:
            startBreakNow()
            return .success("break started / due")
        case .postpone:
            guard let minutes = request.minutes, minutes > 0 else {
                return .failure("postpone requires minutes > 0")
            }
            postpone(by: .minutes(TimeInterval(minutes)))
            return .success("postponed \(minutes)m")
        case .presentationOn:
            guard let minutes = request.minutes, minutes > 0 else {
                return .failure("presentation requires minutes > 0")
            }
            enablePresentationMode(for: .minutes(TimeInterval(minutes)))
            return .success("presentation on for \(minutes)m")
        case .presentationOff:
            disablePresentationMode()
            return .success("presentation off")
        case .historyToday:
            let stats = todayStats
            return .success(
                """
                today completed: \(stats.completedCount)
                today skipped: \(stats.skippedCount)
                today postponed: \(stats.postponedCount)
                movement minutes: \(stats.movementMinutesRounded)
                longest desk minutes: \(stats.longestDeskMinutesRounded)
                """
            )
        case .doctor:
            return .success(doctorReport())
        }
    }

    private func doctorReport() -> String {
        func pad(_ label: String, _ value: String) -> String {
            let dots = String(repeating: ".", count: max(2, 22 - label.count))
            return "\(label) \(dots) \(value)"
        }
        let camera: String = {
            switch cameraAuthorizationStatus {
            case .authorized: return "OK"
            case .denied, .restricted: return "DENIED"
            case .notDetermined: return "NOT DETERMINED"
            }
        }()
        let vision = cameraAuthorizationStatus == .authorized ? "OK" : "DEGRADED"
        let mqtt: String = {
            switch mqttConnectionState {
            case .disabled: return "OFF"
            case .connected: return "OK"
            case .connecting, .reconnecting: return "CONNECTING"
            case .disconnected: return "DISCONNECTED"
            case .failed: return "FAILED"
            }
        }()
        let debt = scheduler.snapshot.movementDebt
        let debtText = debt.isActive
            ? "\(Int((debt.currentDuration.seconds / 60).rounded()))m"
            : "cleared"
        let human = debt.isActive ? "questionable" : "probably fine"
        return [
            pad("Camera", camera),
            pad("Vision", vision),
            pad("Scheduler", scheduler.snapshot.phase == .paused ? "PAUSED" : "OK"),
            pad("History", "\(historyEntryCount) records"),
            pad("MQTT", mqtt),
            pad("OpenMetrics", openMetrics.configuration.isEnabled ? openMetrics.statusText : "OFF"),
            pad("Movement debt", debtText),
            pad("Human", human),
        ].joined(separator: "\n")
    }

    func testMQTTConnection() async -> String {
        let status = await mqttClient.testConnection()
        publishMenuBarObservation(force: true)
        return status.userMessage
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
        let snap = scheduler.snapshot
        return TodayStatsCalculator.make(
            records: history.records,
            now: Date(),
            sittingStartedAt: snap.sittingStartedAt,
            currentSittingSeconds: snap.sittingDuration?.seconds,
            nextBreakSummary: nextBreakStatusText
        )
    }

    /// Privacy-safe weekly Human Runtime card — local history only.
    var weeklyHumanRuntimeSummary: HumanRuntimeWeeklySummary {
        _ = statusRevision
        return HumanRuntimeWeeklySummaryCalculator.make(
            records: history.records,
            now: Date()
        )
    }

    /// Live fields for the Today dashboard (presentation only).
    var statusSnapshot: TodayStatusSnapshot {
        _ = statusRevision
        let snap = scheduler.snapshot
        return TodayStatusSnapshot(
            phase: snap.phase,
            sittingSeconds: snap.sittingDuration?.seconds,
            remainingWorkSeconds: snap.remainingWork?.seconds,
            remainingBreakSeconds: snap.remainingBreak?.seconds,
            debtActive: snap.movementDebt.isActive,
            debtSeconds: snap.movementDebt.currentDuration.seconds
        )
    }

    /// Live capability catalog — BreakEngine never reads this.
    var capabilityCatalog: CapabilityCatalog {
        _ = statusRevision
        let runtime = capabilityRuntimeOverride ?? CapabilityRuntimeSnapshot.mac(
            cameraAuthorized: cameraAuthorizationStatus == .authorized
        )
        return .make(runtime: runtime, preference: operatingModePreference)
    }

    var activeOperatingMode: UnchairOperatingMode {
        capabilityCatalog.activeMode
    }

    func setOperatingModePreference(_ mode: UnchairOperatingMode) {
        operatingModePreference = mode
        publishMenuBarObservation(force: true)
    }

    func setCapabilityRuntimeOverride(_ snapshot: CapabilityRuntimeSnapshot?) {
        capabilityRuntimeOverride = snapshot
        publishMenuBarObservation(force: true)
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
        publishPresentationEnabled(until: Date().addingTimeInterval(duration.seconds))
        bumpStatus()
    }

    func enablePresentationMode(until date: Date) {
        manualPresentationMode?.enable(until: date)
        publishPresentationEnabled(until: date)
        bumpStatus()
    }

    func enablePresentationModeUntilDisabled() {
        manualPresentationMode?.enableUntilDisabled()
        publishPresentationEnabled(until: nil)
        bumpStatus()
    }

    func disablePresentationMode() {
        manualPresentationMode?.disable()
        eventBus.publish(
            DomainEvent(
                name: .presentationDisabled,
                occurredAt: Date(),
                breakID: nil,
                payload: .presentationDisabled
            )
        )
        bumpStatus()
    }

    private func publishPresentationEnabled(until date: Date?) {
        eventBus.publish(
            DomainEvent(
                name: .presentationEnabled,
                occurredAt: Date(),
                breakID: nil,
                payload: .presentationEnabled(until: date)
            )
        )
    }

    var phase: BreakPhase {
        _ = statusRevision
        // Do not evaluate here — SwiftUI/menu reads this often; the 1 Hz ticker
        // (and explicit actions) own lifecycle advancement.
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
            if wantsCameraVerification {
                return .active(
                    remaining: snapshot.remainingBreak ?? .seconds(0),
                    verificationStatus: verificationStatus(for: cameraCoordinator.state),
                    canComplete: cameraCoordinator.canCompleteBreak,
                    proofProgressText: cameraCoordinator.movementProofStatus.progressText()
                )
            }
            return .active(
                remaining: snapshot.remainingBreak ?? .seconds(0),
                verificationStatus: .verificationOptedOut,
                canComplete: true,
                proofProgressText: nil
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

    func performMQTTCommand(_ command: MQTTAcceptedCommand) {
        switch command {
        case .startBreak:
            startBreakNow()
        case .postpone(let minutes):
            postpone(by: .minutes(TimeInterval(minutes)))
        case .skip:
            skipBreak()
        case .presentationOn(let minutes):
            if let minutes {
                enablePresentationMode(for: .minutes(TimeInterval(minutes)))
            } else {
                enablePresentationModeUntilDisabled()
            }
        case .presentationOff:
            disablePresentationMode()
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
        let optedOut = !wantsCameraVerification
        guard optedOut || cameraCoordinator.canCompleteBreak else { return }
        if optedOut || cameraCoordinator.allowsUnverifiedCompletion {
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
        if !wantsCameraVerification || cameraCoordinator.allowsUnverifiedCompletion {
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

    func openSettings(pane: SettingsPane = .general) {
        isSettingsPresented = true
        SettingsWindowController.shared.show(shell: self, pane: pane)
    }

    func openAbout() {
        isSettingsPresented = true
        SettingsWindowController.shared.show(shell: self, pane: .about)
    }

    var hasCompletedOnboarding: Bool {
        _ = statusRevision
        return onboarding.hasCompletedOnboarding
    }

    var cameraVerificationPreference: CameraVerificationPreference {
        _ = statusRevision
        return onboarding.cameraVerificationPreference
    }

    /// Camera sits idle during breaks until the user opts into verification.
    var wantsCameraVerification: Bool {
        _ = statusRevision
        return onboarding.cameraVerificationPreference == .enabled
    }

    /// True when Today / Settings should offer a recovery path for camera verification.
    var showsCameraSetupRecovery: Bool {
        _ = statusRevision
        switch cameraAuthorizationStatus {
        case .denied, .restricted:
            return true
        case .notDetermined:
            return onboarding.cameraVerificationPreference != .enabled
        case .authorized:
            switch cameraCoordinator.state {
            case .busy, .unavailable:
                return true
            case .idle, .running, .permissionDenied:
                return false
            }
        }
    }

    var cameraSetupRecoverySummary: String {
        _ = statusRevision
        switch cameraAuthorizationStatus {
        case .denied, .restricted:
            return "Camera access is off. Reminders still work — re-enable Unchair in System Settings to verify movement."
        case .notDetermined:
            return "Movement verification is optional. Reminders work now; enable the camera when you want sit→stand proof."
        case .authorized:
            switch cameraCoordinator.state {
            case .busy:
                return "Camera is busy in another app. Reminders still work — close the other app or mark complete without verification."
            case .unavailable:
                return "Camera is unavailable. Reminders still work — you can mark breaks complete without verification."
            case .idle, .running, .permissionDenied:
                return ""
            }
        }
    }

    /// Overlay / Today recovery CTA — opens the Camera privacy pane when useful.
    func handleOverlayCameraRecovery() {
        openCameraPrivacySettings()
    }

    /// App became active: re-sync TCC and retry capture without prompting.
    func refreshCameraAuthorizationAfterForeground() {
        Task { [weak self] in
            guard let self else { return }
            _ = await self.cameraCoordinator.refreshAfterForeground()
            self.publishMenuBarObservation(force: true)
            self.syncOverlay()
        }
    }

    func openOnboarding() {
        OnboardingWindowController.shared.show(shell: self)
    }

    func completeOnboarding(camera preference: CameraVerificationPreference) {
        onboarding.complete(camera: preference)
        publishMenuBarObservation(force: true)
        OnboardingWindowController.shared.close()
        restoreAccessoryPolicyIfIdle()
    }

    /// Opt into verification: may show the system camera sheet, then mark onboarding done.
    func completeOnboardingEnablingCamera() {
        cameraCoordinator.armSettingsPreview()
        publishMenuBarObservation(force: true)
        Task { [weak self] in
            guard let self else { return }
            let status = await self.cameraCoordinator.enableCameraAccess()
            if status == .authorized {
                self.onboarding.complete(camera: .enabled)
            } else {
                // User dismissed or denied — keep reminders usable; preference stays reversible.
                self.onboarding.complete(camera: .skipped)
            }
            self.publishMenuBarObservation(force: true)
            self.syncOverlay()
            OnboardingWindowController.shared.close()
            restoreAccessoryPolicyIfIdle()
        }
    }

    /// Reversible Settings path after skipping camera during onboarding.
    func preferCameraVerification(_ enabled: Bool) {
        if enabled {
            onboarding.cameraVerificationPreference = .enabled
            enableCameraAccess()
        } else {
            onboarding.cameraVerificationPreference = .skipped
            stopPosturePreview()
            publishMenuBarObservation(force: true)
        }
    }

    func openCameraPrivacySettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    var distributionChannelDisplayName: String {
        DistributionChannel.current.displayName
    }

    func checkForUpdates() {
        updateController.checkForUpdates()
    }

    func openAuthorSite() {
        NSWorkspace.shared.open(DistributionChannel.authorSiteURL)
    }

    func openOmnivyaSite() {
        NSWorkspace.shared.open(DistributionChannel.omnivyaSiteURL)
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
        case .busy(let reason):
            return "Busy · \(reason)"
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

    private var mqttStateTick = 0

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
        mqttStateTick += 1
        if mqttStateTick % 15 == 0 {
            Task { [weak self] in
                await self?.mqttPublisher.publishStateIfPossible()
            }
        }
        refreshOpenMetricsGauges()
        Task { [weak self] in
            guard let self else { return }
            let priorState = self.cameraCoordinator.state
            let priorProof = self.cameraCoordinator.movementProofStatus
            // Reminders-only: keep the break loop, never start capture.
            let phaseForCamera: BreakPhase = {
                if self.wantsCameraVerification { return currentPhase }
                if case .onBreak = currentPhase { return .idle }
                return currentPhase
            }()
            await self.cameraCoordinator.handlePhaseChange(phaseForCamera)
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

    private func refreshOpenMetricsGauges() {
        let snap = scheduler.snapshot
        let stats = todayStats
        openMetrics.refreshGauges(
            debtSeconds: snap.movementDebt.currentDuration.seconds,
            sittingSeconds: snap.sittingDuration?.seconds ?? 0,
            presentationEnabled: isPresentationModeEnabled,
            todayCompleted: stats.completedCount,
            todaySkipped: stats.skippedCount
        )
    }

    private func publishMenuBarObservation(force: Bool = false) {
        guard force || !isStatusMenuTracking else { return }
        statusRevision &+= 1
    }

    /// Evidence engine → lifecycle events. Sensors never set `break.completed`.
    private func syncVerificationIntoStateMachine() {
        guard scheduler.snapshot.phase.isOnBreak else {
            evidenceEngine.reset()
            return
        }

        let now = Date()
        if cameraCoordinator.allowsUnverifiedCompletion {
            evidenceEngine.noteFailedOpen(true)
            evidenceEngine.removeSource(.macVision)
        } else {
            evidenceEngine.noteFailedOpen(false)
            if let vision = VisionEvidenceMapper.evidence(
                from: cameraCoordinator.movementProofStatus,
                at: now
            ) {
                evidenceEngine.ingest(vision)
            } else {
                evidenceEngine.removeSource(.macVision)
            }
        }

        switch evidenceEngine.evaluate(at: now) {
        case .insufficient:
            break
        case .standingDetected:
            scheduler.noteStandDetected()
        case .movementVerified:
            scheduler.noteStandDetected()
            scheduler.noteMovementVerified()
        case .failedOpen:
            scheduler.noteVerificationFailed()
        }
    }

    private func syncOverlay() {
        overlayController.sync(with: self)
    }

    private func verificationStatus(for cameraState: BreakCameraState) -> BreakVerificationStatus {
        switch cameraState {
        case .permissionDenied:
            return .permissionDenied
        case .busy:
            return .cameraBusy
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

    /// XCTest host shares the app bundle id / UserDefaults with the installed app.
    /// Never touch the real MQTT Keychain item from tests (ACL prompts × N shells).
    private static func makeDefaultMQTTClient() -> MQTTClientController {
        if UnchairProcess.isRunningUnderXCTest {
            return MQTTClientController(
                configurationStore: InMemoryMQTTConfigurationStore(configuration: .default),
                credentials: InMemoryMQTTCredentialStore(),
                transport: FakeMQTTTransport()
            )
        }
        return MQTTClientController()
    }
}
