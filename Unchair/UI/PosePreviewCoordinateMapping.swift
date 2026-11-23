import CoreGraphics
import Foundation

/// Maps Unchair pose joints into an `AVCaptureVideoPreviewLayer` preview that uses
/// `AVLayerVideoGravity.resizeAspect`.
///
/// Joints are stored in AVFoundation / capture-device space (top-left origin, 0…1) after
/// Vision’s bottom-left Y flip in `VisionBodyPoseEstimator`. Apple’s preview conversion
/// APIs (`layerPointConverted(fromCaptureDevicePoint:)`,
/// `layerRectConverted(fromMetadataOutputRect:)`) take the layer’s frame and
/// `videoGravity` into account — this helper mirrors that aspect-fit math so SwiftUI
/// overlays stay aligned without ignoring letterboxing / pillarboxing.
enum PosePreviewCoordinateMapping {
    /// Default when the capture session has not reported a format yet (matches `.hd1280x720`).
    static let defaultContentAspect: CGFloat = 1280.0 / 720.0

    /// Video content rect inside `viewSize` for resize-aspect gravity (top-left origin).
    static func aspectFitContentRect(in viewSize: CGSize, contentAspect: CGFloat) -> CGRect {
        let width = viewSize.width
        let height = viewSize.height
        guard width > 0, height > 0 else { return .zero }

        let aspect = contentAspect > 0 ? contentAspect : defaultContentAspect
        let viewAspect = width / height

        if viewAspect > aspect {
            let fittedWidth = height * aspect
            return CGRect(
                x: (width - fittedWidth) / 2,
                y: 0,
                width: fittedWidth,
                height: height
            )
        }

        let fittedHeight = width / aspect
        return CGRect(
            x: 0,
            y: (height - fittedHeight) / 2,
            width: width,
            height: fittedHeight
        )
    }

    /// Aspect ratio implied by the normalized picture area mapped through the preview layer.
    static func contentAspect(fromMetadataMappedRect rect: CGRect) -> CGFloat {
        guard rect.height > 0 else { return defaultContentAspect }
        let aspect = rect.width / rect.height
        return aspect > 0 ? aspect : defaultContentAspect
    }

    /// View-space point for a joint inside an aspect-fit content rect.
    static func viewPoint(
        for joint: PoseJoint,
        contentRect: CGRect,
        mirrored: Bool
    ) -> CGPoint {
        let xNorm = mirrored ? (1 - joint.x) : joint.x
        return CGPoint(
            x: contentRect.minX + CGFloat(xNorm) * contentRect.width,
            y: contentRect.minY + CGFloat(joint.y) * contentRect.height
        )
    }
}
