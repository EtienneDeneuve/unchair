import AppKit
import Foundation

protocol RunningApplicationInspecting: AnyObject {
    var runningBundleIdentifiers: Set<String> { get }
}

final class WorkspaceRunningApplicationInspector: RunningApplicationInspecting {
    var runningBundleIdentifiers: Set<String> {
        Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )
    }
}

/// Known conferencing / recording apps. Alone this is **not** enough to block —
/// it must combine with camera or microphone in use by another app.
enum KnownMeetingBundleID {
    static let identifiers: Set<String> = [
        "us.zoom.xos",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.apple.FaceTime",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.webex.meetingmanager",
        "com.cisco.webexmeetingsapp",
        "com.obsproject.obs-studio",
        "com.apple.QuickTimePlayerX",
        "com.apple.ScreenSharing",
        "com.google.Chrome", // Meet / Teams web — only with device-use corroboration
        "com.apple.Safari",
        "company.thebrowser.Browser",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "org.mozilla.firefox",
    ]
}

final class MeetingAppWithDeviceUseSignal: PresentationSignalSource {
    private let apps: any RunningApplicationInspecting
    private let devices: any MediaDeviceInspecting

    var reason: PresentationBlockReason { .meetingAppWithDeviceUse }

    var isActive: Bool {
        let meetingRunning = !apps.runningBundleIdentifiers.isDisjoint(
            with: KnownMeetingBundleID.identifiers
        )
        guard meetingRunning else { return false }
        return devices.isCameraInUseByAnotherApplication
            || devices.isMicrophoneInUseByAnotherApplication
    }

    init(apps: any RunningApplicationInspecting, devices: any MediaDeviceInspecting) {
        self.apps = apps
        self.devices = devices
    }
}
