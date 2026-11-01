import Foundation

/// Internal knobs for sit/stand classification. Not user-facing settings.
struct PostureClassificationConfig: Equatable, Sendable {
    /// Soft floor for using a joint in geometry (smoother may hold slightly lower).
    var minimumJointConfidence: Double = 0.12
    /// |score| above this → commit to seated/standing; below → unknown.
    var decisionMargin: Double = 0.16

    static let `default` = PostureClassificationConfig()
}

/// Multi-signal sit/stand classifier tuned for Mac lid webcams.
///
/// Real lid cameras usually see shoulders→hips at best (knees off-frame).
/// Positive score → standing-like, negative → seated-like.
struct PostureClassifier: Sendable {
    var config: PostureClassificationConfig

    init(config: PostureClassificationConfig = .default) {
        self.config = config
    }

    func classify(_ sample: PoseSample) -> PostureEstimate {
        let minConf = config.minimumJointConfidence
        guard
            let leftShoulder = sample.joint(.leftShoulder, minimumConfidence: minConf),
            let rightShoulder = sample.joint(.rightShoulder, minimumConfidence: minConf)
        else {
            return .unknown
        }

        var score = 0.0
        var weight = 0.0
        var quality = (leftShoulder.confidence + rightShoulder.confidence) / 2

        let leftHip = sample.joint(.leftHip, minimumConfidence: minConf)
        let rightHip = sample.joint(.rightHip, minimumConfidence: minConf)
        let leftKnee = sample.joint(.leftKnee, minimumConfidence: minConf)
        let rightKnee = sample.joint(.rightKnee, minimumConfidence: minConf)
        let leftAnkle = sample.joint(.leftAnkle, minimumConfidence: minConf)
        let rightAnkle = sample.joint(.rightAnkle, minimumConfidence: minConf)

        let hips = [leftHip, rightHip].compactMap { $0 }
        let knees = [leftKnee, rightKnee].compactMap { $0 }
        let ankles = [leftAnkle, rightAnkle].compactMap { $0 }

        let shoulderY = (leftShoulder.y + rightShoulder.y) / 2
        let shoulderWidth = abs(rightShoulder.x - leftShoulder.x)

        // Shoulders only (hips cropped): typical close sit at a lid camera.
        // Joint Vision scores are often middling — don't report that as ~25% posture confidence.
        guard !hips.isEmpty else {
            return PostureEstimate(
                state: .seatedLike,
                confidence: committedConfidence(quality: quality, magnitude: 0.55)
            )
        }

        let hipY = hips.map(\.y).reduce(0, +) / Double(hips.count)
        let torsoSpan = max(0.001, hipY - shoulderY)
        quality = (quality + hips.map(\.confidence).reduce(0, +) / Double(hips.count)) / 2

        let hasLegs = !knees.isEmpty || !ankles.isEmpty

        if hasLegs {
            accumulateLegSignals(
                hipY: hipY,
                torsoSpan: torsoSpan,
                knees: knees,
                ankles: ankles,
                leftHip: leftHip,
                rightHip: rightHip,
                leftKnee: leftKnee,
                rightKnee: rightKnee,
                leftAnkle: leftAnkle,
                rightAnkle: rightAnkle,
                score: &score,
                weight: &weight,
                quality: &quality
            )
        } else {
            // Lid-camera mode: knees never enter the frame — use torso framing only.
            accumulateLidCameraSignals(
                shoulderY: shoulderY,
                hipY: hipY,
                shoulderWidth: shoulderWidth,
                torsoSpan: torsoSpan,
                score: &score,
                weight: &weight
            )
        }

        guard weight > 0 else { return .unknown }
        let normalized = score / weight
        let magnitude = abs(normalized)

        if normalized >= config.decisionMargin {
            return PostureEstimate(
                state: .standingLike,
                confidence: committedConfidence(quality: quality, magnitude: magnitude)
            )
        }
        if normalized <= -config.decisionMargin {
            return PostureEstimate(
                state: .seatedLike,
                confidence: committedConfidence(quality: quality, magnitude: magnitude)
            )
        }
        // Ambiguous band — keep this visibly lower than a committed sit/stand.
        return PostureEstimate(
            state: .unknown,
            confidence: clamp01(0.20 + 0.25 * magnitude * quality)
        )
    }

    /// Maps decision strength to a UI-friendly confidence.
    /// Committed sit/stand should land roughly in the 65–92% band on lid cameras.
    private func committedConfidence(quality: Double, magnitude: Double) -> Double {
        let strength = clamp(
            (magnitude - config.decisionMargin) / max(0.001, 1 - config.decisionMargin),
            0,
            1
        )
        let base = 0.68 + 0.24 * strength
        let q = clamp(quality, 0.35, 1)
        return clamp01(base * (0.82 + 0.18 * q))
    }

    /// When Vision sees knees/ankles, use classic leg geometry.
    private func accumulateLegSignals(
        hipY: Double,
        torsoSpan: Double,
        knees: [PoseJoint],
        ankles: [PoseJoint],
        leftHip: PoseJoint?,
        rightHip: PoseJoint?,
        leftKnee: PoseJoint?,
        rightKnee: PoseJoint?,
        leftAnkle: PoseJoint?,
        rightAnkle: PoseJoint?,
        score: inout Double,
        weight: inout Double,
        quality: inout Double
    ) {
        let kneeY = knees.isEmpty ? nil : knees.map(\.y).reduce(0, +) / Double(knees.count)
        let ankleY = ankles.isEmpty ? nil : ankles.map(\.y).reduce(0, +) / Double(ankles.count)

        let lowerY: Double
        if let ankleY, let kneeY, ankleY >= kneeY - 0.02 {
            lowerY = ankleY
        } else if let kneeY {
            lowerY = kneeY
        } else if let ankleY {
            lowerY = ankleY
        } else {
            lowerY = hipY
        }

        let legSpan = max(0, lowerY - hipY)
        let ratio = legSpan / torsoSpan
        let legSignal = clamp((ratio - 0.85) / 0.55, -1, 1)
        accumulate(legSignal, w: 1.35, score: &score, weight: &weight)

        let bendSignals = [
            kneeStraightness(hip: leftHip, knee: leftKnee, ankle: leftAnkle),
            kneeStraightness(hip: rightHip, knee: rightKnee, ankle: rightAnkle),
        ].compactMap { $0 }
        if let meanBend = average(bendSignals) {
            accumulate((meanBend - 0.55) / 0.45, w: 1.0, score: &score, weight: &weight)
            quality = (quality + 0.7) / 1.7
        }

        if ratio >= 0.95 {
            if ankles.count == 2 {
                accumulate(0.55, w: 0.6, score: &score, weight: &weight)
            } else if ankles.count == 1 {
                accumulate(0.3, w: 0.35, score: &score, weight: &weight)
            }
        }
    }

    /// Lid webcam: head often cropped while standing; hips are the lowest reliable joint.
    ///
    /// Standing: shoulders near top, narrower width, hips mid-frame.
    /// Sitting: wider shoulders, hips low in the frame.
    /// (Raw torso length is a poor signal here — sitting close also stretches shoulder→hip.)
    private func accumulateLidCameraSignals(
        shoulderY: Double,
        hipY: Double,
        shoulderWidth: Double,
        torsoSpan: Double,
        score: inout Double,
        weight: inout Double
    ) {
        // Head cropped / shoulders pinned to the top edge → standing upright in front of lid cam.
        let shoulderTop = clamp((0.22 - shoulderY) / 0.16, -1, 1)
        accumulate(shoulderTop, w: 1.45, score: &score, weight: &weight)

        // Hips mid-frame → standing; hips jammed at the bottom → sitting at the desk.
        let hipPlacement = clamp((0.66 - hipY) / 0.20, -1, 1)
        accumulate(hipPlacement, w: 1.35, score: &score, weight: &weight)

        // Absolute shoulder width: close sit fills the frame; stand back shrinks it.
        if shoulderWidth > 0.02 {
            let widthSignal = clamp((0.28 - shoulderWidth) / 0.12, -1, 1)
            accumulate(widthSignal, w: 1.4, score: &score, weight: &weight)
        }

        // How much of the lower frame the hips occupy (0 at center → 1 at bottom).
        let hipsLow = clamp((hipY - 0.55) / 0.30, 0, 1)
        let wide = shoulderWidth > 0.02 ? clamp((shoulderWidth - 0.24) / 0.16, 0, 1) : 0
        // Combined "close sit" blob — both cues together are decisive.
        let closeSit = hipsLow * 0.55 + wide * 0.45
        accumulate(-closeSit * 2 + 0.3, w: 1.1, score: &score, weight: &weight)

        _ = torsoSpan // kept in the signature for call-site clarity / future tuning
    }

    private func kneeStraightness(hip: PoseJoint?, knee: PoseJoint?, ankle: PoseJoint?) -> Double? {
        guard let hip, let knee, let ankle else { return nil }
        let v1x = hip.x - knee.x
        let v1y = hip.y - knee.y
        let v2x = ankle.x - knee.x
        let v2y = ankle.y - knee.y
        let n1 = hypot(v1x, v1y)
        let n2 = hypot(v2x, v2y)
        guard n1 > 1e-4, n2 > 1e-4 else { return nil }
        let cosAngle = max(-1, min(1, (v1x * v2x + v1y * v2y) / (n1 * n2)))
        let angle = acos(cosAngle)
        return clamp((angle - (100 * .pi / 180)) / (60 * .pi / 180), 0, 1)
    }

    private func accumulate(_ signal: Double, w: Double, score: inout Double, weight: inout Double) {
        let s = clamp(signal, -1, 1)
        score += s * w
        weight += w
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        min(hi, max(lo, value))
    }

    private func clamp01(_ value: Double) -> Double {
        clamp(value, 0, 1)
    }
}
