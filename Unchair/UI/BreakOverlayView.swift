import AVFoundation
import SwiftUI

struct BreakOverlayView: View {
    let model: BreakOverlayModel
    var previewSession: AVCaptureSession? = nil
    var previewJoints: [BodyJoint: PoseJoint] = [:]
    let onPrimary: () -> Void
    let onSkip: () -> Void
    let onPostpone15: () -> Void
    var onRecovery: (() -> Void)? = nil
    let onQuit: () -> Void

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .largeTitle) private var heroIconSize: CGFloat = 56
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize: CGFloat = 34
    @ScaledMetric(relativeTo: .title) private var subheadlineSize: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 16
    @ScaledMetric(relativeTo: .callout) private var calloutSize: CGFloat = 14
    @ScaledMetric(relativeTo: .caption) private var captionSize: CGFloat = 12

    var body: some View {
        ZStack {
            background

            VStack(spacing: 22) {
                if model.showsCameraPreview {
                    cameraPreviewSlot
                } else {
                    Image(systemName: "figure.stand")
                        .font(.system(size: heroIconSize, weight: .semibold))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 10) {
                    Text(model.headline)
                        .font(.system(size: headlineSize, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(3)
                    Text(model.subheadline)
                        .font(.system(size: subheadlineSize, weight: .semibold, design: .rounded))
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                        .lineLimit(3)
                }
                .foregroundStyle(.white)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.accessibilityStatusLabel)
                .accessibilityAddTraits(.isHeader)

                if model.showsVerificationSlot {
                    Text(model.verificationText)
                        .font(.system(size: bodySize, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(chipBackground, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(primaryText)
                        .accessibilityLabel(model.verificationText)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                HStack(spacing: 16) {
                    Button(action: onPrimary) {
                        Text(model.primaryActionTitle)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .buttonStyle(OverlayPrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.isPrimaryEnabled)
                    .opacity(model.isPrimaryEnabled ? 1 : 0.55)
                    .accessibilityLabel(model.primaryActionTitle)
                    .accessibilityHint(model.primaryAccessibilityHint)
                    .accessibilitySortPriority(100)

                    Button(action: onSkip) {
                        Text(model.secondaryActionTitle)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .buttonStyle(OverlaySecondaryButtonStyle())
                    .accessibilityLabel(model.secondaryActionTitle)
                    .accessibilityHint(model.secondaryAccessibilityHint)
                    .accessibilitySortPriority(90)
                }

                if let recoveryTitle = model.recoveryActionTitle, let onRecovery {
                    Button(recoveryTitle, action: onRecovery)
                        .buttonStyle(.plain)
                        .foregroundStyle(recoveryForeground)
                        .font(.system(size: calloutSize, weight: .semibold))
                        .accessibilityLabel(recoveryTitle)
                        .accessibilityHint(model.recoveryAccessibilityHint)
                        .accessibilitySortPriority(80)
                }

                HStack(spacing: 20) {
                    Button("Postpone 15 min", action: onPostpone15)
                        .buttonStyle(.plain)
                        .foregroundStyle(secondaryActionForeground)
                        .keyboardShortcut(.escape, modifiers: [])
                        .accessibilityLabel("Postpone 15 min")
                        .accessibilityHint(model.postponeAccessibilityHint)
                        .accessibilitySortPriority(70)

                    Button("Quit Unchair", action: onQuit)
                        .buttonStyle(.plain)
                        .foregroundStyle(tertiaryActionForeground)
                        .keyboardShortcut("q", modifiers: .command)
                        .accessibilityLabel("Quit Unchair")
                        .accessibilityHint(model.quitAccessibilityHint)
                        .accessibilitySortPriority(60)
                }
                .font(.system(size: calloutSize, weight: .medium))

                Text(model.escapeHint)
                    .font(.system(size: captionSize, weight: .regular, design: .rounded))
                    .foregroundStyle(hintForeground)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: 720)
            .padding(40)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Break overlay")
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.12),
                Color(red: 0.14, green: 0.16, blue: 0.22),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            if reduceTransparency || contrast == .increased {
                Color.black.opacity(0.35)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var chipBackground: Color {
        if reduceTransparency || contrast == .increased {
            return Color.white.opacity(0.18)
        }
        return Color.white.opacity(0.08)
    }

    private var primaryText: Color {
        contrast == .increased ? .white : .white.opacity(0.92)
    }

    private var secondaryActionForeground: Color {
        contrast == .increased ? .white : .white.opacity(0.88)
    }

    private var tertiaryActionForeground: Color {
        contrast == .increased ? .white.opacity(0.92) : .white.opacity(0.7)
    }

    private var hintForeground: Color {
        contrast == .increased ? .white.opacity(0.8) : .white.opacity(0.55)
    }

    private var recoveryForeground: Color {
        contrast == .increased ? Color.cyan : Color.cyan.opacity(0.95)
    }

    @ViewBuilder
    private var cameraPreviewSlot: some View {
        switch model.verificationStatus {
        case .permissionDenied, .cameraBusy, .cameraUnavailable, .verificationOptedOut:
            let statusText: String = {
                switch model.verificationStatus {
                case .permissionDenied: return "Camera permission denied"
                case .cameraBusy: return "Camera busy in another app"
                case .verificationOptedOut: return "Camera verification off"
                default: return "Camera unavailable"
                }
            }()
            ZStack {
                Color.black.opacity(contrast == .increased ? 0.95 : 0.85)
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 28, weight: .semibold))
                        .accessibilityHidden(true)
                    Text(statusText)
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(primaryText)
            }
            .frame(maxWidth: 560)
            .frame(minHeight: 180)
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(statusText)
            .accessibilityHint("Movement verification is unavailable. You can still mark the break complete.")
        default:
            LivePosePreview(
                session: previewSession,
                joints: previewJoints,
                mirrored: true,
                height: 320
            )
            .frame(maxWidth: 560)
            .accessibilityLabel("Live camera preview for movement verification")
            .accessibilityHint("Frames stay in memory on this Mac and are not saved.")
        }
    }
}

private struct OverlayPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(configuration.isPressed ? 0.75 : 1))
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .accessibilityAddTraits(.isButton)
    }
}

private struct OverlaySecondaryButtonStyle: ButtonStyle {
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let fill: Double = {
            if reduceTransparency || contrast == .increased {
                return configuration.isPressed ? 0.28 : 0.34
            }
            return configuration.isPressed ? 0.12 : 0.16
        }()
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background(Color.white.opacity(fill))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(contrast == .increased ? 0.7 : 0.25), lineWidth: 1)
            }
            .scaleEffect(!reduceMotion && configuration.isPressed ? 0.98 : 1)
            .accessibilityAddTraits(.isButton)
    }
}
