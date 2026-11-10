import SwiftUI

/// First-run setup: local-only, no account. Camera verification is optional.
struct OnboardingView: View {
    @Bindable var shell: MenuBarShell
    @State private var wantsLaunchAtLogin = false
    @State private var isWorking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                UnchairAppIcon(side: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Welcome to Unchair")
                        .font(.title2.weight(.semibold))
                    Text("Local-first break reminders for your Mac. No account. No cloud.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Break reminders", systemImage: "figure.stand")
                        .font(.headline)
                    Text(
                        "When a break is due, Unchair shows a hard-to-ignore overlay on this Mac. Reminders work without the camera."
                    )
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Launch Unchair at login", isOn: $wantsLaunchAtLogin)
                        .font(.headline)
                    Text("Keeps the break loop running after restart. You can change this anytime in Settings → General.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let launchError = shell.launchAtLoginError {
                        Text(launchError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Optional movement verification", systemImage: "camera.fill")
                        .font(.headline)
                    Text(CameraUsageRationale.text)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Where things live", systemImage: "menubar.rectangle")
                        .font(.headline)
                    Text("Menu bar icon → Today, Settings, or Quit. Settings also holds launch-at-login and camera recovery.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            HStack(spacing: 10) {
                Button("Reminders only") {
                    finish(camera: .skipped)
                }
                .disabled(isWorking)
                .keyboardShortcut(.cancelAction)

                Spacer(minLength: 0)

                Button("Enable camera verification") {
                    finish(camera: .enabled)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isWorking)
                .keyboardShortcut(.defaultAction)
            }

            Text("You can enable or disable camera verification later in Settings → Camera.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(width: 520, alignment: .topLeading)
        .onAppear {
            // Opt-in: mirror current OS state; never silently register a login item.
            wantsLaunchAtLogin = shell.isLaunchAtLoginEnabled
        }
    }

    private func finish(camera preference: CameraVerificationPreference) {
        isWorking = true
        shell.setLaunchAtLoginEnabled(wantsLaunchAtLogin)
        switch preference {
        case .enabled:
            shell.completeOnboardingEnablingCamera()
        case .skipped, .undecided:
            shell.completeOnboarding(camera: .skipped)
        }
    }
}
