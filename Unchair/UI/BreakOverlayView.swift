import SwiftUI

struct BreakOverlayView: View {
    let model: BreakOverlayModel
    let onPrimary: () -> Void
    let onSkip: () -> Void
    let onPostpone15: () -> Void
    let onQuit: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.09, blue: 0.12),
                    Color(red: 0.14, green: 0.16, blue: 0.22),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "figure.stand")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text(model.headline)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(model.subheadline)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .combine)

                if model.showsVerificationSlot {
                    Text(model.verificationText)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white.opacity(0.85))
                        .accessibilityLabel(model.verificationText)
                }

                HStack(spacing: 16) {
                    Button(model.primaryActionTitle, action: onPrimary)
                        .buttonStyle(OverlayPrimaryButtonStyle())
                        .keyboardShortcut(.defaultAction)
                        .disabled(!model.isPrimaryEnabled)
                        .opacity(model.isPrimaryEnabled ? 1 : 0.45)

                    Button(model.secondaryActionTitle, action: onSkip)
                        .buttonStyle(OverlaySecondaryButtonStyle())
                }

                HStack(spacing: 20) {
                    Button("Postpone 15 min", action: onPostpone15)
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.8))
                        .keyboardShortcut(.escape, modifiers: [])

                    Button("Quit Unchair", action: onQuit)
                        .buttonStyle(.plain)
                        .foregroundStyle(.white.opacity(0.55))
                        .keyboardShortcut("q", modifiers: .command)
                }
                .font(.system(size: 14, weight: .medium))

                Text(model.escapeHint)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: 720)
            .padding(40)
        }
        .focusable()
    }
}

private struct OverlayPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OverlaySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.16))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
