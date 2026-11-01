import Foundation
import IOKit
import CryptoKit

enum MQTTDeviceID {
    /// Stable anonymized id: `uch_` + first 8 hex chars of SHA256(IOPlatformUUID).
    static func make(platformUUID: String? = nil) -> String {
        let uuid = platformUUID ?? readIOPlatformUUID() ?? "unknown-mac"
        let digest = SHA256.hash(data: Data(uuid.utf8))
        let hex = digest.prefix(4).map { String(format: "%02x", $0) }.joined()
        return "uch_\(hex)"
    }

    private static func readIOPlatformUUID() -> String? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPlatformExpertDevice")
        )
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard let cf = IORegistryEntryCreateCFProperty(
            service,
            "IOPlatformUUID" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
        else {
            return nil
        }
        return cf
    }
}
