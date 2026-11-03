import AppKit
import Foundation

/// Channel-specific update entry point. Sparkle powers the direct channel;
/// MAS builds never embed an updater — they only deep-link the Store when available.
@MainActor
protocol AppUpdateControlling: AnyObject {
    /// User clicked “Check for Updates…” (or Settings).
    func checkForUpdates()
}

enum AppUpdateControllerFactory {
    @MainActor
    static func make() -> any AppUpdateControlling {
        #if APPSTORE
        AppStoreUpdateController()
        #else
        if isRunningUnderXCTest {
            // Avoid loading Sparkle's updater/XPC inside the XCTest host app.
            return NoOpUpdateController()
        }
        return DirectUpdateController()
        #endif
    }

    private static var isRunningUnderXCTest: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}

#if APPSTORE
/// Mac App Store channel — no Sparkle, no sideloaded zip replacement.
@MainActor
final class AppStoreUpdateController: AppUpdateControlling {
    func checkForUpdates() {
        NSWorkspace.shared.open(DistributionChannel.macAppStoreURL)
    }
}
#else
import Sparkle

/// Direct channel — Sparkle 2 with EdDSA-signed GitHub appcast.
@MainActor
final class DirectUpdateController: NSObject, AppUpdateControlling {
    private let updaterController: SPUStandardUpdaterController

    override init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
#endif

/// Test double / silent stub that never opens the network.
@MainActor
final class NoOpUpdateController: AppUpdateControlling {
    func checkForUpdates() {}
}
