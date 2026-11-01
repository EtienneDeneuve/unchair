import CoreVideo
import Foundation
import Vision

protocol BodyPoseEstimating: Sendable {
    func estimatePose(from pixelBuffer: CVPixelBuffer, timestamp: Date) -> PoseSample?
}

/// On-device Vision human body pose → `PoseSample`. Drops face joints intentionally.
struct VisionBodyPoseEstimator: BodyPoseEstimating {
    /// Accept faint joints into the sample; the classifier/smoother apply their own floors.
    var minimumJointConfidence: Double

    init(minimumJointConfidence: Double = 0.08) {
        self.minimumJointConfidence = minimumJointConfidence
    }

    func estimatePose(from pixelBuffer: CVPixelBuffer, timestamp: Date = Date()) -> PoseSample? {
        let request = VNDetectHumanBodyPoseRequest()
        // Prefer the newest revision when the SDK exposes it.
        if #available(macOS 14.0, *) {
            request.revision = VNDetectHumanBodyPoseRequestRevision1
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first else {
            return nil
        }

        return Self.sample(from: observation, timestamp: timestamp, minimumConfidence: minimumJointConfidence)
    }

    static func sample(
        from observation: VNHumanBodyPoseObservation,
        timestamp: Date,
        minimumConfidence: Double
    ) -> PoseSample? {
        var joints: [BodyJoint: PoseJoint] = [:]

        for bodyJoint in BodyJoint.allCases {
            guard let visionJoint = Self.visionJoint(for: bodyJoint) else { continue }
            guard let point = try? observation.recognizedPoint(visionJoint) else { continue }
            guard point.confidence >= Float(minimumConfidence) else { continue }
            // Vision body pose points use a bottom-left origin; flip Y so classifiers can
            // treat y as increasing downward (image / UIKit convention).
            joints[bodyJoint] = PoseJoint(
                x: Double(point.location.x),
                y: 1.0 - Double(point.location.y),
                confidence: Double(point.confidence)
            )
        }

        guard !joints.isEmpty else { return nil }
        return PoseSample(joints: joints, timestamp: timestamp)
    }

    private static func visionJoint(for joint: BodyJoint) -> VNHumanBodyPoseObservation.JointName? {
        switch joint {
        case .root: return .root
        case .leftShoulder: return .leftShoulder
        case .rightShoulder: return .rightShoulder
        case .leftElbow: return .leftElbow
        case .rightElbow: return .rightElbow
        case .leftHip: return .leftHip
        case .rightHip: return .rightHip
        case .leftKnee: return .leftKnee
        case .rightKnee: return .rightKnee
        case .leftAnkle: return .leftAnkle
        case .rightAnkle: return .rightAnkle
        }
    }
}
