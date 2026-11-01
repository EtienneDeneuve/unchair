import AVFoundation
import AppKit
import SwiftUI

/// AppKit preview layer bound to the live `AVCaptureSession` (no frame copies).
struct CameraPreviewRepresentable: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> CameraPreviewNSView {
        let view = CameraPreviewNSView()
        view.attach(session: session)
        return view
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {
        nsView.attach(session: session)
    }
}

final class CameraPreviewNSView: NSView {
    private let previewLayer = AVCaptureVideoPreviewLayer()

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
    }

    var isMirrored: Bool {
        previewLayer.connection?.isVideoMirrored ?? true
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

/// Skeleton overlay for Vision body joints used by Unchair (no face points).
struct PoseSkeletonOverlay: View {
    var joints: [BodyJoint: PoseJoint]
    var mirrored: Bool

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
            let size = geo.size
            Canvas { context, _ in
                for (a, b) in Self.bones {
                    guard let pa = joints[a], let pb = joints[b] else { continue }
                    var path = Path()
                    path.move(to: point(pa, in: size))
                    path.addLine(to: point(pb, in: size))
                    context.stroke(
                        path,
                        with: .color(.green.opacity(0.85)),
                        lineWidth: 2
                    )
                }

                for (joint, pose) in joints {
                    let p = point(pose, in: size)
                    let rect = CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)
                    context.fill(Path(ellipseIn: rect), with: .color(color(for: joint)))
                    context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.9)), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func point(_ joint: PoseJoint, in size: CGSize) -> CGPoint {
        let x = mirrored ? (1 - joint.x) : joint.x
        return CGPoint(x: x * size.width, y: joint.y * size.height)
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

    var body: some View {
        ZStack {
            if let session {
                CameraPreviewRepresentable(session: session)
            } else {
                Color.black.opacity(0.85)
                Text("Camera starting…")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            PoseSkeletonOverlay(joints: joints, mirrored: mirrored)
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
