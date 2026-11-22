import Foundation

/// How this binary is meant to be installed and updated.
///
/// Compile-time only (`DIRECT` vs `APPSTORE`). Do not mix Sparkle into App Store
/// builds — Apple requires MAS updates exclusively through the App Store.
enum DistributionChannel: String, Equatable, Sendable, CaseIterable {
    /// GitHub Releases + Developer ID + notarization (+ Sparkle when wired).
    case direct
    /// Mac App Store sandbox build — App Store updates only.
    case macAppStore

    /// Channel baked into this binary.
    static var current: DistributionChannel {
        #if APPSTORE
        .macAppStore
        #else
        .direct
        #endif
    }

    /// In-app updater UI / Sparkle are allowed only on the direct channel.
    var offersInAppUpdates: Bool {
        self == .direct
    }

    /// OpenMetrics HTTP scrape server (`NWListener`) requires sandbox
    /// `com.apple.security.network.server`. MAS deliberately omits that entitlement
    /// (see `docs/mas-sandbox.md`) — Direct keeps the optional localhost/LAN listener.
    var offersOpenMetricsHTTPServer: Bool {
        self == .direct
    }

    /// External `unchair` CLI talks to a Unix socket under Application Support.
    /// Sandboxed MAS containers that path; the unsigned CLI cannot reach it without
    /// an App Group. Socket + CLI stay Direct-only until a shared group lands (#142).
    var offersLocalControlSocket: Bool {
        self == .direct
    }

    var displayName: String {
        switch self {
        case .direct: return "Direct (GitHub)"
        case .macAppStore: return "Mac App Store"
        }
    }

    /// Shared marketing site for release notes (CHANGELOG stays the source of truth).
    static let changelogURL = URL(
        string: "https://github.com/EtienneDeneuve/unchair/blob/main/CHANGELOG.md"
    )!

    /// Latest direct download / release notes landing page.
    static let latestDirectReleaseURL = URL(
        string: "https://github.com/EtienneDeneuve/unchair/releases/latest"
    )!

    /// Author site (writing, experiments, contact).
    static let authorSiteURL = URL(
        string: "https://etienne.deneuve.xyz/?utm_source=unchair&utm_medium=app&utm_campaign=about"
    )!

    /// Omnivya — simpler systems for developer teams (beyond desk health).
    static let omnivyaSiteURL = URL(
        string: "https://www.omnivya.fr/?utm_source=unchair&utm_medium=app&utm_campaign=about"
    )!

    /// Placeholder App Store product URL — replace with real `idXXXXXXXX` after ASC listing.
    static let macAppStoreURL = URL(
        string: "https://apps.apple.com/app/unchair/id0000000000"
    )!
}
