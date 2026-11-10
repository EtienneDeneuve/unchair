import Foundation

enum UnchairProcess {
    /// True when this process is the XCTest host (or a test bundle).
    /// Used to avoid Keychain ACL prompts and Sparkle XPC inside `xcodebuild test`.
    static var isRunningUnderXCTest: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}
