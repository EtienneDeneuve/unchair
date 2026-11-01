import Foundation
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
        let data = Data(password.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MQTTCredentialStoreError.unexpectedStatus(status)
        }
    }

    func loadPassword() throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
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

    func savePassword(_ password: String) throws {
        self.password = password
    }

    func loadPassword() throws -> String {
        guard let password else { throw MQTTCredentialStoreError.notFound }
        return password
    }

    func deletePassword() throws {
        password = nil
    }
}
