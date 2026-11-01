import CoreImage
import CoreVideo
import Foundation
import Vision

/// Ephemeral person/subject isolation. Masks and masked buffers exist only in memory
/// for the duration of pose estimation — never written or uploaded.
struct SubjectLiftResult: Sendable {
    /// Fraction of mask pixels that belong to the subject (0...1).
    var coverage: Double
}

protocol SubjectLifting: Sendable {
    /// Returns subject coverage when a person/foreground mask can be produced.
    /// Does not retain pixel buffers beyond the call used by the pose estimator.
    func subjectCoverage(in pixelBuffer: CVPixelBuffer) -> Double?

    /// Renders a background-suppressed copy for pose. Caller must not persist the buffer.
    func maskedPixelBuffer(from pixelBuffer: CVPixelBuffer) -> (buffer: CVPixelBuffer, coverage: Double)?
}

/// On-device person segmentation (fast) for lid-cam isolation.
struct VisionPersonSubjectLifter: SubjectLifting {
    var qualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel

    init(qualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel = .fast) {
        self.qualityLevel = qualityLevel
    }

    func subjectCoverage(in pixelBuffer: CVPixelBuffer) -> Double? {
        guard let mask = Self.personMask(from: pixelBuffer, qualityLevel: qualityLevel) else {
            return nil
        }
        return Self.coverage(of: mask)
    }

    func maskedPixelBuffer(from pixelBuffer: CVPixelBuffer) -> (buffer: CVPixelBuffer, coverage: Double)? {
        guard let mask = Self.personMask(from: pixelBuffer, qualityLevel: qualityLevel) else {
            return nil
        }
        let coverage = Self.coverage(of: mask)
        // Skip masking when almost nobody is in frame — pose on raw is fine.
        guard coverage >= 0.02 else { return nil }
        guard let masked = Self.applyMask(mask, to: pixelBuffer) else { return nil }
        return (masked, coverage)
    }

    private static func personMask(
        from pixelBuffer: CVPixelBuffer,
        qualityLevel: VNGeneratePersonSegmentationRequest.QualityLevel
    ) -> CVPixelBuffer? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = qualityLevel
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        return request.results?.first?.pixelBuffer
    }

    /// Sampled coverage — full scan would be too heavy for every frame.
    static func coverage(of mask: CVPixelBuffer, stride: Int = 8) -> Double {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(mask) else { return 0 }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        var subject = 0
        var total = 0
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let value = ptr[y * bytesPerRow + x]
                if value > 32 { subject += 1 }
                total += 1
                x += stride
            }
            y += stride
        }
        guard total > 0 else { return 0 }
        return Double(subject) / Double(total)
    }

    private static func applyMask(_ mask: CVPixelBuffer, to image: CVPixelBuffer) -> CVPixelBuffer? {
        let input = CIImage(cvPixelBuffer: image)
        var maskImage = CIImage(cvPixelBuffer: mask)
        let scaleX = input.extent.width / max(maskImage.extent.width, 1)
        let scaleY = input.extent.height / max(maskImage.extent.height, 1)
        if abs(scaleX - 1) > 0.01 || abs(scaleY - 1) > 0.01 {
            maskImage = maskImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        }

        let background = CIImage(color: .black).cropped(to: input.extent)
        let masked = input.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: background,
                kCIInputMaskImageKey: maskImage,
            ]
        )

        var output: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(image),
            CVPixelBufferGetHeight(image),
            kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            ] as CFDictionary,
            &output
        )
        guard status == kCVReturnSuccess, let output else { return nil }

        // Per-call context avoids sharing CIContext across threads without locks.
        let context = CIContext(options: [.cacheIntermediates: false, .useSoftwareRenderer: false])
        context.render(masked, to: output)
        return output
    }
}

/// Test double — returns fixed coverage / passthrough.
struct StubSubjectLifter: SubjectLifting {
    var coverage: Double? = 0.4
    var maskEnabled = false

    func subjectCoverage(in pixelBuffer: CVPixelBuffer) -> Double? { coverage }

    func maskedPixelBuffer(from pixelBuffer: CVPixelBuffer) -> (buffer: CVPixelBuffer, coverage: Double)? {
        guard maskEnabled, let coverage else { return nil }
        return (pixelBuffer, coverage)
    }
}
