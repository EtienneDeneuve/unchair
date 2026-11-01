import SwiftUI

struct SettingsView: View {
    @Bindable var shell: MenuBarShell
    @State private var workMinutes: Double = 50
    @State private var breakSeconds: Double = 90
    @State private var postponeUntil: Date = Date().addingTimeInterval(30 * 60)
    @State private var mqttPasswordDraft = ""
    @State private var mqttTestStatus: String?

    var body: some View {
        // Touch revision so AppKit-hosted SwiftUI refreshes on pose ticks.
        let _ = shell.statusRevision

        Form {
            Section("Schedule") {
                LabeledContent("Work interval") {
                    HStack {
                        Slider(value: $workMinutes, in: 5...120, step: 5)
                        Text("\(Int(workMinutes)) min")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                LabeledContent("Break duration") {
                    HStack {
                        Slider(value: $breakSeconds, in: 30...300, step: 15)
                        Text("\(Int(breakSeconds)) s")
                            .monospacedDigit()
                            .frame(width: 56, alignment: .trailing)
                    }
                }
                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: { shell.isLaunchAtLoginEnabled },
                        set: { shell.setLaunchAtLoginEnabled($0) }
                    )
                )
                Text("Uses the system Service Management API (no legacy login-item hacks).")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                if let launchError = shell.launchAtLoginError {
                    Text(launchError)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
                Text("Changes apply to the next completed or skipped break cycle.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Posture") {
                LivePosePreview(
                    session: shell.posturePreviewSession,
                    joints: shell.posturePreviewJoints
                )
                LabeledContent("Current") {
                    Text(shell.postureStatusText)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(postureColor)
                }
                Text(shell.postureDetailText)
                    .foregroundStyle(.secondary)
                    .font(.caption)

                if shell.cameraAuthorizationStatus == .denied
                    || shell.cameraAuthorizationStatus == .restricted
                {
                    Text("Permission was denied at launch. Re-enable Unchair under System Settings → Privacy & Security → Camera, then reopen Settings.")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Text("Lid cameras usually see shoulders→hips only; sit/stand uses that framing. Knees help when visible. Nothing is recorded.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Camera") {
                Text(shell.cameraProbeStatusText)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Button {
                    shell.runCameraProbe()
                } label: {
                    Label(
                        shell.isCameraProbeRunning ? "Testing…" : "Test camera",
                        systemImage: "checkmark.circle"
                    )
                }
                .disabled(shell.isCameraProbeRunning || shell.cameraAuthorizationStatus != .authorized)
                Text("Confirms frames stay in memory. Does not re-ask permission if already allowed.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Postpone until exact time") {
                DatePicker(
                    "Until",
                    selection: $postponeUntil,
                    displayedComponents: [.hourAndMinute]
                )
                Button("Postpone to selected time") {
                    shell.postpone(until: postponeUntil)
                }
                .disabled(!shell.canPostpone)
            }

            Section("History") {
                LabeledContent("Stored breaks") {
                    Text("\(shell.historyEntryCount)")
                        .monospacedDigit()
                }
                Text("Local only — timestamps, outcomes, and tiny derived verification numbers. No images, video, audio, or body landmarks.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Button("Clear break history…", role: .destructive) {
                    shell.clearBreakHistory()
                }
                .disabled(shell.historyEntryCount == 0)
            }

            Section("MQTT / Home Assistant") {
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
                TextField(
                    "Broker host",
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
                Text("TLS is recommended for remote brokers. Default port is 8883.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                SecureField(
                    "Password (Keychain)",
                    text: $mqttPasswordDraft
                )
                .onSubmit {
                    shell.saveMQTTPassword(mqttPasswordDraft)
                }
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
                LabeledContent("Status") {
                    Text(shell.mqttConnectionStatusText)
                        .foregroundStyle(.secondary)
                }
                Button {
                    shell.saveMQTTPassword(mqttPasswordDraft)
                    Task {
                        mqttTestStatus = "Testing…"
                        mqttTestStatus = await shell.testMQTTConnection()
                    }
                } label: {
                    Label("Test Connection", systemImage: "network")
                }
                .disabled(!shell.mqttConfiguration.isEnabled)
                if let mqttTestStatus {
                    Text(mqttTestStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Password is stored in the macOS Keychain only — never in UserDefaults or logs. MQTT is optional; breaks keep working when the broker is down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Operating mode") {
                LabeledContent("Active") {
                    Text(shell.activeOperatingMode.title)
                        .fontWeight(.semibold)
                }
                Text(shell.activeOperatingMode.summary)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Text("Mac-only Standalone is a complete product. Optional companions are capabilities, never prerequisites.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            Section("Capabilities") {
                ForEach(shell.capabilityCatalog.capabilities) { capability in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Image(systemName: capabilityGlyph(capability.availability))
                                .foregroundStyle(capabilityColor(capability.availability))
                            Text(capability.title)
                                .fontWeight(.medium)
                            if capability.isCore {
                                Text("Core")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(capabilityStatusLabel(capability.availability))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(capability.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if case .unavailable(let reason) = capability.availability {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 1100)
        .navigationTitle("Unchair Settings")
        .onAppear {
            workMinutes = shell.settings.workInterval.seconds / 60
            breakSeconds = shell.settings.breakDuration.seconds
            postponeUntil = Date().addingTimeInterval(30 * 60)
            // Never prompt here — only resume if already authorized.
            if shell.cameraAuthorizationStatus == .authorized {
                shell.startPosturePreview()
            }
        }
        .onDisappear {
            shell.stopPosturePreview()
        }
        .onChange(of: workMinutes) { _, newValue in
            shell.updateSettings(
                BreakSettings(
                    workInterval: .minutes(newValue),
                    breakDuration: .seconds(breakSeconds)
                )
            )
        }
        .onChange(of: breakSeconds) { _, newValue in
            shell.updateSettings(
                BreakSettings(
                    workInterval: .minutes(workMinutes),
                    breakDuration: .seconds(newValue)
                )
            )
        }
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
        case .unavailable: return .secondary
        case .comingSoon: return .secondary
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
