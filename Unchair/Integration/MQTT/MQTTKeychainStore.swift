import Foundation
import LocalAuthentication
import Security

enum MQTTCredentialStoreError: Error, Equatable, Sendable {
    case notFound
    case unexpectedStatus(OSStatus)
    case encodingFailed
}

protocol MQTTCredentialStoring: AnyObject {
    func savePassword(_ password: String) throws
    func loadPassword() throws -> String
    func deletePassword() throws
}

/// macOS Keychain-backed password/token storage. Never UserDefaults.
final class KeychainMQTTCredentialStore: MQTTCredentialStoring {
    private let service: String
    private let account: String

    init(
        service: String = "com.etiennedeneuve.unchair.mqtt",
        account: String = "broker-password"
    ) {
        self.service = service
        self.account = account
    }

    func savePassword(_ password: String) throws {
        // XCTest host is a different codesign identity than the installed app —
        // SecItem* would ACL-prompt on every MenuBarShell init. Tests use InMemory.
        if UnchairProcess.isRunningUnderXCTest { return }
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        // Prefer ThisDeviceOnly so menu-bar relaunches after unlock don't re-prompt as often.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MQTTCredentialStoreError.unexpectedStatus(status)
        }
    }

    func loadPassword() throws -> String {
        if UnchairProcess.isRunningUnderXCTest {
            throw MQTTCredentialStoreError.notFound
        }
        let auth = LAContext()
        auth.interactionNotAllowed = true
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            // Never present an ACL / unlock sheet from background reconnect paths.
            kSecUseAuthenticationContext as String: auth,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw MQTTCredentialStoreError.notFound
        }
        // Interaction-not-allowed / auth failed → treat as missing (Settings can re-save).
        if status == errSecAuthFailed || status == errSecInteractionNotAllowed {
            throw MQTTCredentialStoreError.notFound
        }
        guard status == errSecSuccess, let data = item as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            throw MQTTCredentialStoreError.unexpectedStatus(status)
        }
        return password
    }

    func deletePassword() throws {
        if UnchairProcess.isRunningUnderXCTest { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MQTTCredentialStoreError.unexpectedStatus(status)
        }
    }
}

final class InMemoryMQTTCredentialStore: MQTTCredentialStoring {
    private var password: String?
    private(set) var loadCount = 0

    func savePassword(_ password: String) throws {
        self.password = password
    }

    func loadPassword() throws -> String {
        loadCount += 1
        guard let password else { throw MQTTCredentialStoreError.notFound }
        return password
    }

    func deletePassword() throws {
        password = nil
    }
}
