import SwiftUI

struct SettingsView: View {
    @Bindable var shell: MenuBarShell
    @State private var workMinutes: Double = 50
    @State private var breakSeconds: Double = 90
    @State private var postponeUntil: Date = Date().addingTimeInterval(30 * 60)

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
        .frame(width: 480, height: 920)
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
