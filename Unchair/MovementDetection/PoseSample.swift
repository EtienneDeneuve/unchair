import Foundation

/// Normalized joint positions from Vision body pose. No face/identity joints.
struct PoseJoint: Equatable, Sendable {
    var x: Double
    var y: Double
    var confidence: Double
}

enum BodyJoint: String, CaseIterable, Sendable {
    case root
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle
}

/// One pose observation derived from a single camera frame. Landmarks only — never pixels.
struct PoseSample: Equatable, Sendable {
    var joints: [BodyJoint: PoseJoint]
    var timestamp: Date
    /// Fraction of frame covered by the ephemeral person mask (0...1), when available.
    var subjectCoverage: Double?

    init(
        joints: [BodyJoint: PoseJoint],
        timestamp: Date = Date(),
        subjectCoverage: Double? = nil
    ) {
        self.joints = joints
        self.timestamp = timestamp
        self.subjectCoverage = subjectCoverage
    }

    func joint(_ name: BodyJoint, minimumConfidence: Double) -> PoseJoint? {
        guard let joint = joints[name], joint.confidence >= minimumConfidence else {
            return nil
        }
        return joint
    }

    var verticalSpan: Double? {
        let ys = joints.values.map(\.y)
        guard let minY = ys.min(), let maxY = ys.max(), maxY > minY else { return nil }
        return maxY - minY
    }

    var shoulderWidth: Double? {
        guard
            let left = joint(.leftShoulder, minimumConfidence: 0.1),
            let right = joint(.rightShoulder, minimumConfidence: 0.1)
        else { return nil }
        return abs(right.x - left.x)
    }
}

enum PostureState: String, Equatable, Sendable {
    case unknown
    case seatedLike = "seated-like"
    case standingLike = "standing-like"
}

/// Classified posture plus a 0...1 confidence suitable for Settings / debug UI.
struct PostureEstimate: Equatable, Sendable {
    var state: PostureState
    /// 0 = no signal, 1 = highly decisive geometry + joint confidence.
    var confidence: Double

    static let unknown = PostureEstimate(state: .unknown, confidence: 0)

    var confidencePercent: Int {
        Int((confidence * 100).rounded())
    }

    var displayLabel: String {
        switch state {
        case .unknown:
            return "Unknown"
        case .seatedLike:
            return "Sitting"
        case .standingLike:
            return "Standing"
        }
    }

    var statusText: String {
        switch state {
        case .unknown:
            return confidence > 0 ? "Unclear · \(confidencePercent)%" : "Unknown · —"
        case .seatedLike, .standingLike:
            return "\(displayLabel) · \(confidencePercent)%"
        }
    }
}

struct SitToStandEvent: Equatable, Sendable {
    var detectedAt: Date
}
