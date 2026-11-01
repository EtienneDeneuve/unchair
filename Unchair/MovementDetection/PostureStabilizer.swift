import Foundation

struct PostureStabilizerConfig: Equatable, Sendable {
    /// Consecutive matching raw classifications required before publishing a new state.
    var requiredStableFrames: Int = 4
    /// High-confidence raw estimates can promote faster.
    var fastTrackConfidence: Double = 0.72
    var fastTrackFrames: Int = 2
    /// How many `unknown` frames to ignore before falling back to `.unknown`.
    var occlusionGraceFrames: Int = 10

    static let `default` = PostureStabilizerConfig()
}

/// Smooths noisy per-frame posture hints so brief occlusion does not thrash state.
struct PostureStabilizer: Sendable {
    private let config: PostureStabilizerConfig
    private(set) var published: PostureEstimate = .unknown
    private var candidate: PostureState = .unknown
    private var candidateStreak = 0
    private var occlusionStreak = 0

    init(config: PostureStabilizerConfig = .default) {
        self.config = config
    }

    mutating func reset() {
        published = .unknown
        candidate = .unknown
        candidateStreak = 0
        occlusionStreak = 0
    }

    @discardableResult
    mutating func push(_ raw: PostureEstimate) -> PostureEstimate {
        if raw.state == .unknown {
            occlusionStreak += 1
            if occlusionStreak > config.occlusionGraceFrames {
                published = .unknown
                candidate = .unknown
                candidateStreak = 0
            }
            return published
        }

        occlusionStreak = 0

        if raw.state == published.state {
            // Rise quickly with stronger frames; decay slowly so a few weak
            // Vision scores don't drag "Sitting · 70%" down to ~25%.
            let blended: Double
            if raw.confidence >= published.confidence {
                blended = published.confidence * 0.25 + raw.confidence * 0.75
            } else {
                blended = published.confidence * 0.88 + raw.confidence * 0.12
            }
            published = PostureEstimate(state: published.state, confidence: blended)
            candidate = raw.state
            candidateStreak = 0
            return published
        }

        if raw.state == candidate {
            candidateStreak += 1
        } else {
            candidate = raw.state
            candidateStreak = 1
        }

        let needed = raw.confidence >= config.fastTrackConfidence
            ? config.fastTrackFrames
            : config.requiredStableFrames

        if candidateStreak >= needed {
            published = raw
            candidateStreak = 0
        }

        return published
    }
}
