import XCTest
@testable import Unchair

final class PresentationSignalCacheTests: XCTestCase {
    func testMediaDeviceInspectorCachesAcrossReads() {
        let probe = CountingMediaDeviceInspector()
        let cached = CachingMediaDeviceInspectorProbe(backing: probe, ttl: 2.0)

        _ = cached.isCameraInUseByAnotherApplication
        _ = cached.isMicrophoneInUseByAnotherApplication
        _ = cached.isCameraInUseByAnotherApplication
        XCTAssertEqual(probe.cameraReads, 1)
        XCTAssertEqual(probe.microphoneReads, 1)

        cached.advance(by: 2.1)
        _ = cached.isCameraInUseByAnotherApplication
        XCTAssertEqual(probe.cameraReads, 2)
    }

    func testRunningAppsInspectorCachesAcrossReads() {
        let probe = CountingRunningAppsInspector()
        let cached = CachingRunningAppsInspectorProbe(backing: probe, ttl: 2.0)

        _ = cached.runningBundleIdentifiers
        _ = cached.runningBundleIdentifiers
        XCTAssertEqual(probe.reads, 1)

        cached.advance(by: 2.1)
        _ = cached.runningBundleIdentifiers
        XCTAssertEqual(probe.reads, 2)
    }
}

/// Mirrors production TTL caching without hitting AVFoundation / NSWorkspace in CI.
private final class CountingMediaDeviceInspector: MediaDeviceInspecting {
    var cameraReads = 0
    var microphoneReads = 0
    var isCameraInUseByAnotherApplication: Bool {
        cameraReads += 1
        return false
    }

    var isMicrophoneInUseByAnotherApplication: Bool {
        microphoneReads += 1
        return false
    }
}

private final class CachingMediaDeviceInspectorProbe: MediaDeviceInspecting {
    private let backing: CountingMediaDeviceInspector
    private let ttl: TimeInterval
    private var now = Date(timeIntervalSince1970: 0)
    private var cachedAt: Date?
    private var cachedCamera = false
    private var cachedMicrophone = false

    init(backing: CountingMediaDeviceInspector, ttl: TimeInterval) {
        self.backing = backing
        self.ttl = ttl
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    var isCameraInUseByAnotherApplication: Bool {
        refreshIfNeeded()
        return cachedCamera
    }

    var isMicrophoneInUseByAnotherApplication: Bool {
        refreshIfNeeded()
        return cachedMicrophone
    }

    private func refreshIfNeeded() {
        if let cachedAt, now.timeIntervalSince(cachedAt) < ttl { return }
        cachedCamera = backing.isCameraInUseByAnotherApplication
        cachedMicrophone = backing.isMicrophoneInUseByAnotherApplication
        cachedAt = now
    }
}

private final class CountingRunningAppsInspector: RunningApplicationInspecting {
    var reads = 0
    var runningBundleIdentifiers: Set<String> {
        reads += 1
        return ["com.example.app"]
    }
}

private final class CachingRunningAppsInspectorProbe: RunningApplicationInspecting {
    private let backing: CountingRunningAppsInspector
    private let ttl: TimeInterval
    private var now = Date(timeIntervalSince1970: 0)
    private var cachedAt: Date?
    private var cached: Set<String> = []

    init(backing: CountingRunningAppsInspector, ttl: TimeInterval) {
        self.backing = backing
        self.ttl = ttl
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    var runningBundleIdentifiers: Set<String> {
        if let cachedAt, now.timeIntervalSince(cachedAt) < ttl {
            return cached
        }
        cached = backing.runningBundleIdentifiers
        cachedAt = now
        return cached
    }
}
