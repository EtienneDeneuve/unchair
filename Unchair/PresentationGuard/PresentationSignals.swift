import Foundation

/// Why the presentation guard is currently blocking break presentation.
enum PresentationBlockReason: String, Equatable, Sendable, CaseIterable {
    case manualPresentationMode
    case cameraInUseByAnotherApp
    case microphoneInUseByAnotherApp
    case screenLockedOrAsleep
    case meetingAppWithDeviceUse
}

/// A single fail-safe signal. Strong signals only — never "Zoom is installed".
protocol PresentationSignalSource: AnyObject {
    var reason: PresentationBlockReason { get }
    var isActive: Bool { get }
}
