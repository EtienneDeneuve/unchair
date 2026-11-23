import AVFoundation
import AppKit
import SwiftUI

/// AppKit preview layer bound to the live `AVCaptureSession` (no frame copies).
struct CameraPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession
    var onVideoContentAspectChange: ((CGFloat) -> Void)?

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.onVideoContentAspectChange = onVideoContentAspectChange
        view.attach(session: session)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.onVideoContentAspectChange = onVideoContentAspectChange
        nsView.attach(session: session)
    }
}

final class CameraPreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()
    var onVideoContentAspectChange: ((CGFloat) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspect
        layer = CALayer()
        layer?.addSublayer(previewLayer)
        previewLayer.backgroundColor = NSColor.black.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attach(session: AVCaptureSession) {
        if previewLayer.session !== session {
            previewLayer.session = session
        }
        // FaceTime preview is mirrored; keep overlay math in sync via isMirrored.
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = true
        }
        publishVideoContentAspect()
    }

    var isMirrored: Bool {
        previewLayer.connection?.isVideoMirrored ?? true
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
        publishVideoContentAspect()
    }

    /// Uses Apple’s metadata→layer conversion so `videoGravity` is honored.
    private func publishVideoContentAspect() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let mapped = previewLayer.layerRectConverted(
            fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let aspect = PosePreviewCoordinateMapping.contentAspect(fromMetadataMappedRect: mapped)
        onVideoContentAspectChange?(aspect)
    }
}

/// Skeleton overlay for Vision body joints used by Unchair (no face points).
struct PoseSkeletonOverlay: View {
    var joints: [BodyJoint: PoseJoint]
    var mirrored: Bool
    /// Capture picture aspect (width / height). Defaults to 1280×720 when unknown.
    var contentAspect: CGFloat = PosePreviewCoordinateMapping.defaultContentAspect

    private static let bones: [(BodyJoint, BodyJoint)] = [
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.rightShoulder, .rightElbow),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        (.leftHip, .root),
        (.rightHip, .root),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        GeometryReader { geo in
            let contentRect = PosePreviewCoordinateMapping.aspectFitContentRect(
                in: geo.size,
                contentAspect: contentAspect
            )
            Canvas { context, _ in
                for (a, b) in Self.bones {
                    guard let pa = joints[a], let pb = joints[b] else { continue }
                    var path = Path()
                    path.move(to: point(pa, contentRect: contentRect))
                    path.addLine(to: point(pb, contentRect: contentRect))
                    context.stroke(
                        path,
                        with: .color(.green.opacity(0.85)),
                        lineWidth: 2
                    )
                }

                for (joint, pose) in joints {
                    let p = point(pose, contentRect: contentRect)
                    let rect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(color(for: joint)))
                    context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.9)), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func point(_ joint: PoseJoint, contentRect: CGRect) -> CGPoint {
        PosePreviewCoordinateMapping.viewPoint(
            for: joint,
            contentRect: contentRect,
            mirrored: mirrored
        )
    }

    private func color(for joint: BodyJoint) -> Color {
        switch joint {
        case .root:
            return .white
        case .leftShoulder, .rightShoulder:
            return .cyan
        case .leftElbow, .rightElbow:
            return .mint
        case .leftHip, .rightHip:
            return .orange
        case .leftKnee, .rightKnee:
            return .yellow
        case .leftAnkle, .rightAnkle:
            return .pink
        }
    }
}

struct LivePosePreview: View {
    var session: AVCaptureSession?
    var joints: [BodyJoint: PoseJoint]
    /// FaceTime preview is mirrored on Mac; match overlay unless proven otherwise.
    var mirrored: Bool = true
    /// Default height for Settings; break overlay overrides via `.frame(height:)`.
    var height: CGFloat = 240

    @State private var contentAspect: CGFloat = PosePreviewCoordinateMapping.defaultContentAspect

    var body: some View {
        ZStack {
            if let session {
                CameraPreviewRepresentable(
                    session: session,
                    onVideoContentAspectChange: { aspect in
                        // layout() can run during representable updates — defer state write.
                        DispatchQueue.main.async {
                            if abs(aspect - contentAspect) > 0.001 {
                                contentAspect = aspect
                            }
                        }
                    }
                )
            } else {
                Color.black.opacity(0.85)
                Text("Camera starting…")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            PoseSkeletonOverlay(
                joints: joints,
                mirrored: mirrored,
                contentAspect: contentAspect
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
    }
}
