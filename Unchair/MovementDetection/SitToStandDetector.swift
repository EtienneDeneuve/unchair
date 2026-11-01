import Foundation

/// Consumes pose samples and publishes a stable posture plus sit→stand transitions.
struct SitToStandDetector: Sendable {
    private var classifier: PostureClassifier
    private var stabilizer: PostureStabilizer
    private var smoother: PoseJointSmoother
    private(set) var estimate: PostureEstimate = .unknown
    private(set) var lastSitToStand: SitToStandEvent?
    private(set) var lastSmoothedJoints: [BodyJoint: PoseJoint] = [:]

    var posture: PostureState { estimate.state }

    init(
        classification: PostureClassificationConfig = .default,
        stabilization: PostureStabilizerConfig = .default,
        smoother: PoseJointSmoother = PoseJointSmoother()
    ) {
        self.classifier = PostureClassifier(config: classification)
        self.stabilizer = PostureStabilizer(config: stabilization)
        self.smoother = smoother
    }

    mutating func reset() {
        stabilizer.reset()
        smoother.reset()
        estimate = .unknown
        lastSitToStand = nil
        lastSmoothedJoints = [:]
    }

    @discardableResult
    mutating func process(_ sample: PoseSample) -> PostureEstimate {
        let previous = estimate.state
        let smoothed = smoother.push(sample)
        lastSmoothedJoints = smoothed.joints
        let next = stabilizer.push(classifier.classify(smoothed))
        estimate = next

        if previous == .seatedLike, next.state == .standingLike {
            lastSitToStand = SitToStandEvent(detectedAt: sample.timestamp)
        }

        return estimate
    }
}
