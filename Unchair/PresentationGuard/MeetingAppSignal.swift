import AppKit
import Foundation

protocol RunningApplicationInspecting: AnyObject {
    var runningBundleIdentifiers: Set<String> { get }
}

/// `NSWorkspace.runningApplications` snapshot with a short TTL — full process
/// enumeration on every PresentationGuard tick was a major idle-CPU source.
final class WorkspaceRunningApplicationInspector: RunningApplicationInspecting {
    private let lock = NSLock()
    private let ttl: TimeInterval
    private let now: () -> Date
    private var cachedAt: Date?
    private var cachedIdentifiers: Set<String> = []

    init(ttl: TimeInterval = 2.0, now: @escaping () -> Date = Date.init) {
        self.ttl = ttl
        self.now = now
    }

    var runningBundleIdentifiers: Set<String> {
        lock.lock()
        let instant = now()
        if let cachedAt, instant.timeIntervalSince(cachedAt) < ttl {
            let hit = cachedIdentifiers
            lock.unlock()
            return hit
        }
        lock.unlock()

        let identifiers = Set(
            NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)
        )

        lock.lock()
        cachedIdentifiers = identifiers
        cachedAt = instant
        lock.unlock()
        return identifiers
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
