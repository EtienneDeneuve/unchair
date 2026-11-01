import Foundation
@testable import Unchair

enum PoseFixtures {
    /// Full-body standing: long legs, straight knees, ankles low in frame.
    static func standing(confidence: Double = 0.9, timestamp: Date = Date()) -> PoseSample {
        PoseSample(
            joints: [
                .root: .init(x: 0.50, y: 0.46, confidence: confidence),
                .leftShoulder: .init(x: 0.40, y: 0.22, confidence: confidence),
                .rightShoulder: .init(x: 0.60, y: 0.22, confidence: confidence),
                .leftElbow: .init(x: 0.36, y: 0.34, confidence: confidence),
                .rightElbow: .init(x: 0.64, y: 0.34, confidence: confidence),
                .leftHip: .init(x: 0.43, y: 0.46, confidence: confidence),
                .rightHip: .init(x: 0.57, y: 0.46, confidence: confidence),
                .leftKnee: .init(x: 0.44, y: 0.70, confidence: confidence),
                .rightKnee: .init(x: 0.56, y: 0.70, confidence: confidence),
                .leftAnkle: .init(x: 0.44, y: 0.93, confidence: confidence),
                .rightAnkle: .init(x: 0.56, y: 0.93, confidence: confidence),
            ],
            timestamp: timestamp
        )
    }

    /// Seated: hips low, knees bent forward, ankles under chair (not a long vertical leg).
    static func seated(confidence: Double = 0.9, timestamp: Date = Date()) -> PoseSample {
        PoseSample(
            joints: [
                .root: .init(x: 0.50, y: 0.58, confidence: confidence),
                .leftShoulder: .init(x: 0.40, y: 0.28, confidence: confidence),
                .rightShoulder: .init(x: 0.60, y: 0.28, confidence: confidence),
                .leftElbow: .init(x: 0.34, y: 0.42, confidence: confidence),
                .rightElbow: .init(x: 0.66, y: 0.42, confidence: confidence),
                .leftHip: .init(x: 0.43, y: 0.58, confidence: confidence),
                .rightHip: .init(x: 0.57, y: 0.58, confidence: confidence),
                .leftKnee: .init(x: 0.48, y: 0.78, confidence: confidence),
                .rightKnee: .init(x: 0.52, y: 0.78, confidence: confidence),
                // Ankles tucked back under the seat — bent knee geometry.
                .leftAnkle: .init(x: 0.40, y: 0.70, confidence: confidence),
                .rightAnkle: .init(x: 0.60, y: 0.70, confidence: confidence),
            ],
            timestamp: timestamp
        )
    }

    /// Lid-camera sit: wide shoulders, lower in frame, hips near bottom — no legs.
    static func torsoOnly(confidence: Double = 0.9, timestamp: Date = Date()) -> PoseSample {
        lidSitting(confidence: confidence, timestamp: timestamp)
    }

    /// Lid-camera sit (shoulders + hips only).
    static func lidSitting(confidence: Double = 0.9, timestamp: Date = Date()) -> PoseSample {
        PoseSample(
            joints: [
                .root: .init(x: 0.50, y: 0.78, confidence: confidence),
                .leftShoulder: .init(x: 0.32, y: 0.36, confidence: confidence),
                .rightShoulder: .init(x: 0.68, y: 0.36, confidence: confidence),
                .leftElbow: .init(x: 0.28, y: 0.52, confidence: confidence),
                .rightElbow: .init(x: 0.72, y: 0.52, confidence: confidence),
                .leftHip: .init(x: 0.40, y: 0.80, confidence: confidence),
                .rightHip: .init(x: 0.60, y: 0.80, confidence: confidence),
            ],
            timestamp: timestamp
        )
    }

    /// Lid-camera stand: head cropped, narrower shoulders, hips mid-frame — no legs.
    static func lidStanding(confidence: Double = 0.9, timestamp: Date = Date()) -> PoseSample {
        PoseSample(
            joints: [
                .root: .init(x: 0.50, y: 0.58, confidence: confidence),
                .leftShoulder: .init(x: 0.40, y: 0.08, confidence: confidence),
                .rightShoulder: .init(x: 0.60, y: 0.08, confidence: confidence),
                .leftElbow: .init(x: 0.36, y: 0.28, confidence: confidence),
                .rightElbow: .init(x: 0.64, y: 0.28, confidence: confidence),
                .leftHip: .init(x: 0.43, y: 0.58, confidence: confidence),
                .rightHip: .init(x: 0.57, y: 0.58, confidence: confidence),
            ],
            timestamp: timestamp
        )
    }
}
