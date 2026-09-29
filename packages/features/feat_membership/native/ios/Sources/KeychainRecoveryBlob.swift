#if os(iOS)
import Foundation
import Security

/// Apple-only adapter. No plaintext recovery file, exported encryption key, iCloud
/// synchronization, caller-selected keychain access group, or delete/reset fallback.
/// This source must be built/tested with the actual app entitlements and iOS SDK.
final class KeychainRecoveryBlob: RecoveryBlobStorage {
    let namespace: String
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "africlub.native-checkout-recovery.v1." + namespace,
         kSecAttrAccount as String: "installation-snapshot-v1",
         kSecAttrSynchronizable as String: false]
    }
    init(bundleID: String) throws { try RecoveryProtocol.application(bundleID); namespace = bundleID }
    private func checkedStatus(_ status: OSStatus, missing: String = "recovery_key_unavailable") throws {
        if status == errSecSuccess { return }
        if status == errSecInteractionNotAllowed { throw RecoveryFailure("recovery_device_locked") }
        if status == errSecItemNotFound { throw RecoveryFailure(missing) }
        if status == errSecDuplicateItem { throw RecoveryFailure("recovery_key_conflict") }
        throw RecoveryFailure("recovery_key_unavailable")
    }
    func read() throws -> Data? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecReturnAttributes as String] = true
        // A weaker legacy synchronized item must not be hidden by the write policy.
        // Ambiguous same-namespace records fail closed instead of selecting one.
        q[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        q[kSecMatchLimit as String] = kSecMatchLimitAll
        // Never turn a locked/unavailable keychain into a successful empty store.
        var item: CFTypeRef?
        let result = SecItemCopyMatching(q as CFDictionary, &item)
        if result == errSecItemNotFound { return nil }
        try checkedStatus(result)
        guard let matches = item as? [[String: Any]], matches.count == 1 else {
            throw RecoveryFailure("recovery_key_conflict")
        }
        let attributes = matches[0]
        guard let data = attributes[kSecValueData as String] as? Data else {
            throw RecoveryFailure("recovery_corrupt")
        }
        try requireRecovery(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String,
            "recovery_key_conflict")
        try requireRecovery((attributes[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue != true, "recovery_key_conflict")
        try requireRecovery(data.count <= RecoveryProtocol.maxSnapshotBytes, "recovery_corrupt")
        return data
    }
    func insert(_ value: Data) throws {
        try requireRecovery(value.count <= RecoveryProtocol.maxSnapshotBytes)
        var q = query
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        q[kSecValueData as String] = value
        try checkedStatus(SecItemAdd(q as CFDictionary, nil))
    }
    func replace(_ value: Data) throws {
        try requireRecovery(value.count <= RecoveryProtocol.maxSnapshotBytes)
        // No errSecItemNotFound -> add fallback. Absence is an unresolved state failure.
        try checkedStatus(SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary), missing: "recovery_state_missing")
    }
}
#endif
