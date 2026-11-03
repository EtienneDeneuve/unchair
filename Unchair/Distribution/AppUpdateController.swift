import AppKit
import Foundation

/// Channel-specific update entry point. Sparkle plugs into the direct implementation;
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
        DirectUpdateController()
        #endif
    }
}

#if APPSTORE
/// Mac App Store channel — no Sparkle, no sideloaded zip replacement.
@MainActor
final class AppStoreUpdateController: AppUpdateControlling {
    func checkForUpdates() {
        // Until the listing exists, open CHANGELOG so release notes stay unified.
        NSWorkspace.shared.open(DistributionChannel.macAppStoreURL)
    }
}
#else
/// Direct channel — temporary bridge until Sparkle + signed appcast ship.
///
/// Next step: replace the body with `SPUStandardUpdaterController` (Sparkle 2),
/// keep this type as the only UI-facing updater API.
@MainActor
final class DirectUpdateController: AppUpdateControlling {
    func checkForUpdates() {
        NSWorkspace.shared.open(DistributionChannel.latestDirectReleaseURL)
    }
}
#endif
