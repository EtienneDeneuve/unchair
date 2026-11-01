import AppKit

enum AppConfiguration {
    /// Menu bar agent: no Dock icon by default (`LSUIElement`).
    static let suppressesDockIcon = true
    static let activationPolicy: NSApplication.ActivationPolicy = .accessory

    /// Source modules aligned with README architecture boundaries.
    static let sourceModules: [String] = [
        "App",
        "BreakEngine",
        "MovementDetection",
        "PresentationGuard",
        "History",
        "UI",
    ]
}
