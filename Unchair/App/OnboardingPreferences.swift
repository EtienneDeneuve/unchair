import Foundation

/// Whether the user wants local camera verification during breaks.
/// Reminders always work; verification is optional and reversible.
enum CameraVerificationPreference: String, Equatable, Sendable {
    case undecided
    /// User opted into sit→stand verification when the camera is available.
    case enabled
    /// Reminders only — no camera prompt until the user opts back in.
    case skipped
}

protocol OnboardingPreferencesStoring: AnyObject {
    var hasCompletedOnboarding: Bool { get set }
    var cameraVerificationPreference: CameraVerificationPreference { get set }
}

/// Local-only first-run choices. No account, no cloud.
final class UserDefaultsOnboardingPreferences: OnboardingPreferencesStoring {
    private let defaults: UserDefaults
    private let completedKey: String
    private let cameraKey: String

    init(
        defaults: UserDefaults = .standard,
        completedKey: String = "unchair.onboarding.v1.completed",
        cameraKey: String = "unchair.onboarding.v1.cameraVerification"
    ) {
        self.defaults = defaults
        self.completedKey = completedKey
        self.cameraKey = cameraKey
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: completedKey) }
        set { defaults.set(newValue, forKey: completedKey) }
    }

    var cameraVerificationPreference: CameraVerificationPreference {
        get {
            guard let raw = defaults.string(forKey: cameraKey),
                  let value = CameraVerificationPreference(rawValue: raw)
            else {
                return .undecided
            }
            return value
        }
        set { defaults.set(newValue.rawValue, forKey: cameraKey) }
    }

    func complete(camera preference: CameraVerificationPreference) {
        cameraVerificationPreference = preference
        hasCompletedOnboarding = true
    }

    /// Existing installs already answered the system camera prompt — don't re-show onboarding.
    func migrateIfNeeded(cameraStatus: CameraAuthorizationStatus) {
        guard !hasCompletedOnboarding else { return }
        switch cameraStatus {
        case .authorized:
            complete(camera: .enabled)
        case .denied, .restricted:
            complete(camera: .skipped)
        case .notDetermined:
            break
        }
    }
}
