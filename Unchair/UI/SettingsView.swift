import SwiftUI

enum SettingsPane: String, Hashable, CaseIterable, Identifiable {
    case general
    case camera
    case integrations
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .camera: return "Camera"
        case .integrations: return "Integrations"
        case .about: return "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .camera: return "camera.fill"
        case .integrations: return "homekit"
        case .about: return "info.circle"
        }
    }
}

struct SettingsView: View {
    @Bindable var shell: MenuBarShell
    @State private var pane: SettingsPane
    @State private var workMinutes: Double = 50
    @State private var breakSeconds: Double = 90
    @State private var idleFreezeMinutes: Double = 5
    @State private var postponeUntil: Date = Date().addingTimeInterval(30 * 60)
    @State private var mqttPasswordDraft = ""
    @State private var mqttTestStatus: String?

    init(shell: MenuBarShell, initialPane: SettingsPane = .general) {
        self.shell = shell
        _pane = State(initialValue: initialPane)
    }

    var body: some View {
        // Touch revision so AppKit-hosted SwiftUI refreshes on pose ticks.
        let _ = shell.statusRevision

        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { item in
                Label(item.title, systemImage: item.symbol)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 168, ideal: 178, max: 200)
        } detail: {
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 700, height: 480)
        .onAppear {
            workMinutes = shell.settings.workInterval.seconds / 60
            breakSeconds = shell.settings.breakDuration.seconds
            idleFreezeMinutes = shell.settings.idleFreezeAfter.seconds / 60
            postponeUntil = Date().addingTimeInterval(30 * 60)
            syncPreview(for: pane)
        }
        .onDisappear {
            shell.stopPosturePreview()
        }
        .onChange(of: pane) { _, next in
            syncPreview(for: next)
        }
        .onChange(of: workMinutes) { _, newValue in
            shell.updateSettings(currentSettings(workMinutes: newValue))
        }
        .onChange(of: breakSeconds) { _, newValue in
            shell.updateSettings(currentSettings(breakSeconds: newValue))
        }
        .onChange(of: idleFreezeMinutes) { _, newValue in
            shell.updateSettings(currentSettings(idleFreezeMinutes: newValue))
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch pane {
        case .general: generalPane
        case .camera: cameraPane
        case .integrations: integrationsPane
        case .about: aboutPane
        }
    }

    // MARK: - Panes

    private var generalPane: some View {
        Form {
            Section {
                durationRow("Work interval", value: $workMinutes, range: 5...120, step: 5) {
                    "\(Int($0)) min"
                }
                durationRow("Break duration", value: $breakSeconds, range: 30...300, step: 15) {
                    "\(Int($0)) s"
                }
                durationRow("Pause when idle", value: $idleFreezeMinutes, range: 0...30, step: 1) {
                    $0 < 0.5 ? "Off" : "\(Int($0)) min"
                }
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { shell.isLaunchAtLoginEnabled },
                        set: { shell.setLaunchAtLoginEnabled($0) }
                    )
                )
                if let launchError = shell.launchAtLoginError {
                    Text(launchError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            } header: {
                Text("Schedule")
            } footer: {
                Text("Idle pause follows keyboard/mouse while unlocked. Sleep and lock always pause.")
            }

            Section {
                HStack(alignment: .center, spacing: 12) {
                    DatePicker(
                        "Postpone until",
                        selection: $postponeUntil,
                        displayedComponents: [.hourAndMinute]
                    )
                    .labelsHidden()
                    .frame(maxWidth: 120)

                    Button("Postpone") {
                        shell.postpone(until: postponeUntil)
                    }
                    .disabled(!shell.canPostpone)
                    .keyboardShortcut(.defaultAction)

                    Spacer(minLength: 0)
                }

                HStack {
                    Text("History")
                    Spacer()
                    Text("\(shell.historyEntryCount)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button("Clear…", role: .destructive) {
                        shell.clearBreakHistory()
                    }
                    .disabled(shell.historyEntryCount == 0)
                }
            } header: {
                Text("Quick actions")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
        .navigationTitle("General")
    }

    private var cameraPane: some View {
        Form {
            Section {
                LivePosePreview(
                    session: shell.posturePreviewSession,
                    joints: shell.posturePreviewJoints
                )
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                LabeledContent("Posture") {
                    Text(shell.postureStatusText)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(postureColor)
                }
                if !shell.postureDetailText.isEmpty {
                    Text(shell.postureDetailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Preview")
            } footer: {
                Text("On-device only — frames never leave this Mac.")
            }

            Section {
                Toggle(
                    "Verify sit → stand with camera",
                    isOn: Binding(
                        get: { shell.cameraVerificationPreference == .enabled },
                        set: { shell.preferCameraVerification($0) }
                    )
                )
                Text("Optional. Break reminders keep working without the camera. Frames stay in memory on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if shell.cameraAuthorizationStatus == .denied
                    || shell.cameraAuthorizationStatus == .restricted
                {
                    Text("Camera access denied. Enable Unchair in System Settings → Privacy & Security → Camera.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Camera Privacy Settings") {
                        shell.openCameraPrivacySettings()
                    }
                } else if shell.showsCameraSetupRecovery,
                    shell.cameraAuthorizationStatus == .authorized
                {
                    Text(shell.cameraSetupRecoverySummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open Camera Settings") {
                        shell.openCameraPrivacySettings()
                    }
                } else if shell.cameraAuthorizationStatus == .notDetermined {
                    Button("Enable camera access…") {
                        shell.enableCameraAccess()
                    }
                } else {
                    Text(shell.cameraProbeStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button {
                    shell.runCameraProbe()
                } label: {
                    Label(
                        shell.isCameraProbeRunning ? "Testing…" : "Test camera",
                        systemImage: "checkmark.circle"
                    )
                }
                .disabled(shell.isCameraProbeRunning || shell.cameraAuthorizationStatus != .authorized)
            } header: {
                Text("Camera")
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
        .navigationTitle("Camera")
    }

    private var integrationsPane: some View {
        Form {
            Section {
                Toggle(
                    "Enable MQTT",
                    isOn: Binding(
                        get: { shell.mqttConfiguration.isEnabled },
                        set: { enabled in
                            var config = shell.mqttConfiguration
                            config.isEnabled = enabled
                            shell.updateMQTTConfiguration(config)
                        }
                    )
                )
            } header: {
                Text("Home Assistant")
            } footer: {
                Text("Optional. Breaks keep working offline. Password stays in Keychain.")
            }

            if shell.mqttConfiguration.isEnabled {
                Section("Broker") {
                    TextField(
                        "Host",
                        text: Binding(
                            get: { shell.mqttConfiguration.host },
                            set: { host in
                                var config = shell.mqttConfiguration
                                config.host = host
                                shell.updateMQTTConfiguration(config)
                            }
                        )
                    )
                    TextField(
                        "Port",
                        value: Binding(
                            get: { shell.mqttConfiguration.port },
                            set: { port in
                                var config = shell.mqttConfiguration
                                config.port = port
                                shell.updateMQTTConfiguration(config)
                            }
                        ),
                        format: .number
                    )
                    Toggle(
                        "Use TLS",
                        isOn: Binding(
                            get: { shell.mqttConfiguration.useTLS },
                            set: { tls in
                                var config = shell.mqttConfiguration
                                config.useTLS = tls
                                shell.updateMQTTConfiguration(config)
                            }
                        )
                    )
                    TextField(
                        "Username",
                        text: Binding(
                            get: { shell.mqttConfiguration.username },
                            set: { username in
                                var config = shell.mqttConfiguration
                                config.username = username
                                shell.updateMQTTConfiguration(config)
                            }
                        )
                    )
                    SecureField("Password (Keychain)", text: $mqttPasswordDraft)
                        .onSubmit { shell.saveMQTTPassword(mqttPasswordDraft) }
                }

                Section("Status") {
                    Toggle(
                        "Home Assistant Discovery",
                        isOn: Binding(
                            get: { shell.mqttConfiguration.homeAssistantDiscoveryEnabled },
                            set: { discovery in
                                var config = shell.mqttConfiguration
                                config.homeAssistantDiscoveryEnabled = discovery
                                shell.updateMQTTConfiguration(config)
                            }
                        )
                    )
                    LabeledContent("Connection") {
                        Text(shell.mqttConnectionStatusText)
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("Device ID") {
                        Text(shell.mqttDeviceId)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Button {
                        shell.saveMQTTPassword(mqttPasswordDraft)
                        Task {
                            mqttTestStatus = "Testing…"
                            mqttTestStatus = await shell.testMQTTConnection()
                        }
                    } label: {
                        Label("Test connection", systemImage: "network")
                    }
                    if let mqttTestStatus {
                        Text(mqttTestStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Toggle(
                    "Enable OpenMetrics",
                    isOn: Binding(
                        get: { shell.openMetricsConfiguration.isEnabled },
                        set: { enabled in
                            var config = shell.openMetricsConfiguration
                            config.isEnabled = enabled
                            shell.updateOpenMetricsConfiguration(config)
                        }
                    )
                )
            } header: {
                Text("Observability")
            } footer: {
                Text(
                    "Optional Prometheus/OpenMetrics scrape endpoint. Off by default. Localhost only unless LAN is enabled. No camera or identity labels."
                )
            }

            if shell.openMetricsConfiguration.isEnabled {
                Section("OpenMetrics") {
                    TextField(
                        "Port",
                        value: Binding(
                            get: { Int(shell.openMetricsConfiguration.port) },
                            set: { port in
                                var config = shell.openMetricsConfiguration
                                config.port = UInt16(clamping: max(1, port))
                                shell.updateOpenMetricsConfiguration(config)
                            }
                        ),
                        format: .number
                    )
                    Toggle(
                        "Allow LAN exposure",
                        isOn: Binding(
                            get: { shell.openMetricsConfiguration.allowLANExposure },
                            set: { lan in
                                var config = shell.openMetricsConfiguration
                                config.allowLANExposure = lan
                                shell.updateOpenMetricsConfiguration(config)
                            }
                        )
                    )
                    LabeledContent("Status") {
                        Text(shell.openMetricsStatusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
        .navigationTitle("Integrations")
    }

    private var aboutPane: some View {
        Form {
            Section {
                LabeledContent("Version") {
                    Text(
                        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
                            ?? "—"
                    )
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                }
                LabeledContent("Channel") {
                    Text(shell.distributionChannelDisplayName)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Mode") {
                    Text(shell.activeOperatingMode.title)
                        .foregroundStyle(.secondary)
                }
                if DistributionChannel.current.offersInAppUpdates {
                    Button {
                        shell.checkForUpdates()
                    } label: {
                        Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            } header: {
                Text("Unchair")
            }

            Section {
                Text("Liked Unchair? Desk health is only one piece — Omnivya also helps developer teams stay saner by making complex systems simpler.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    shell.openAuthorSite()
                } label: {
                    Label("etienne.deneuve.xyz", systemImage: "person.crop.circle")
                }
                Button {
                    shell.openOmnivyaSite()
                } label: {
                    Label("omnivya.fr", systemImage: "globe")
                }
            } header: {
                Text("Beyond the desk")
            }

            Section("Capabilities") {
                ForEach(shell.capabilityCatalog.capabilities) { capability in
                    LabeledContent {
                        Text(capabilityStatusLabel(capability.availability))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label {
                            Text(capability.title)
                        } icon: {
                            Image(systemName: capabilityGlyph(capability.availability))
                                .foregroundStyle(capabilityColor(capability.availability))
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 4)
        .navigationTitle("About")
    }

    // MARK: - Helpers

    private func syncPreview(for pane: SettingsPane) {
        if pane == .camera, shell.cameraAuthorizationStatus == .authorized {
            shell.startPosturePreview()
        } else {
            shell.stopPosturePreview()
        }
    }

    private func durationRow(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        label: @escaping (Double) -> String
    ) -> some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                Slider(value: value, in: range, step: step)
                Text(label(value.wrappedValue))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }
            .frame(minWidth: 220)
        }
    }

    private func currentSettings(
        workMinutes: Double? = nil,
        breakSeconds: Double? = nil,
        idleFreezeMinutes: Double? = nil
    ) -> BreakSettings {
        BreakSettings(
            workInterval: .minutes(workMinutes ?? self.workMinutes),
            breakDuration: .seconds(breakSeconds ?? self.breakSeconds),
            idleFreezeAfter: .minutes(idleFreezeMinutes ?? self.idleFreezeMinutes)
        )
    }

    private var postureColor: Color {
        let text = shell.postureStatusText
        if text.hasPrefix("Standing") { return .green }
        if text.hasPrefix("Sitting") { return .orange }
        return .secondary
    }

    private func capabilityGlyph(_ availability: CapabilityAvailability) -> String {
        switch availability {
        case .available: return "checkmark.circle.fill"
        case .unavailable: return "xmark.circle"
        case .comingSoon: return "clock"
        }
    }

    private func capabilityColor(_ availability: CapabilityAvailability) -> Color {
        switch availability {
        case .available: return .green
        case .unavailable, .comingSoon: return .secondary
        }
    }

    private func capabilityStatusLabel(_ availability: CapabilityAvailability) -> String {
        switch availability {
        case .available: return "Available"
        case .unavailable: return "Unavailable"
        case .comingSoon: return "Coming soon"
        }
    }
}
