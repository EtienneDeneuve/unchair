import Foundation

/// Exponential smoothing + short hold for flickering Vision joints.
struct PoseJointSmoother: Sendable {
    /// Blend toward new observations (higher = snappier, lower = stabler).
    var alpha: Double
    /// Decay confidence for joints missing from the latest frame.
    var holdDecay: Double

    private var smoothed: [BodyJoint: PoseJoint] = [:]

    init(alpha: Double = 0.4, holdDecay: Double = 0.82) {
        self.alpha = alpha
        self.holdDecay = holdDecay
    }

    mutating func reset() {
        smoothed = [:]
    }

    mutating func push(_ sample: PoseSample) -> PoseSample {
        // Total miss: drop held joints so occlusion can surface as `.unknown`.
        if sample.joints.isEmpty {
            smoothed = [:]
            return sample
        }

        var next = smoothed
        let decay = holdDecay

        for (key, incoming) in sample.joints {
            if let previous = next[key] {
                next[key] = PoseJoint(
                    x: alpha * incoming.x + (1 - alpha) * previous.x,
                    y: alpha * incoming.y + (1 - alpha) * previous.y,
                    confidence: max(incoming.confidence, previous.confidence * 0.92)
                )
            } else {
                next[key] = incoming
            }
        }

        for (key, previous) in smoothed where sample.joints[key] == nil {
            let decayed = previous.confidence * decay
            if decayed < 0.12 {
                next.removeValue(forKey: key)
            } else {
                next[key] = PoseJoint(x: previous.x, y: previous.y, confidence: decayed)
            }
        }

        smoothed = next
        return PoseSample(joints: next, timestamp: sample.timestamp)
    }
}
