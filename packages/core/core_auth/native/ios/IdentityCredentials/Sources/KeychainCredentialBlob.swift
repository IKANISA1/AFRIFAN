#if canImport(Security) && canImport(LocalAuthentication)
import Foundation
import Security
import LocalAuthentication

/// The default implementation invokes Security. The injected implementation is
/// used only by the synthetic query harness, which does not execute Keychain.
protocol CredentialSecurityOperations {
    func copy(_ query: CFDictionary) -> (OSStatus, CFTypeRef?)
    func add(_ query: CFDictionary) -> OSStatus
    func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus
}
struct SystemCredentialSecurityOperations: CredentialSecurityOperations {
    func copy(_ query: CFDictionary) -> (OSStatus, CFTypeRef?) {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)
        return (status, item)
    }
    func add(_ query: CFDictionary) -> OSStatus { SecItemAdd(query, nil) }
    func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus { SecItemUpdate(query, attributes) }
}

/// Apple-only adapter. No plaintext credential file, exported encryption key, iCloud
/// synchronization, caller-selected keychain access group, or delete/reset fallback.
/// This source must be built/tested with the actual app entitlements and iOS SDK.
final class KeychainCredentialBlob: CredentialBlobStorage {
    let namespace: String
    private let operations: any CredentialSecurityOperations
    private var authentication: LAContext {
        let value = LAContext()
        value.interactionNotAllowed = true
        return value
    }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "africlub.native-identity-credentials.v1." + namespace,
         kSecAttrAccount as String: "installation-journal-v1",
         kSecAttrSynchronizable as String: false,
         kSecUseAuthenticationContext as String: authentication]
    }
    init(bundleID: String, operations: any CredentialSecurityOperations = SystemCredentialSecurityOperations()) throws {
        try CredentialProtocol.application(bundleID); namespace = bundleID; self.operations = operations
    }
    private func checkedStatus(_ status: OSStatus, missing: String = "credential_key_unavailable") throws {
        if status == errSecSuccess { return }
        if status == errSecInteractionNotAllowed { throw CredentialFailure("credential_device_locked") }
        if status == errSecItemNotFound { throw CredentialFailure(missing) }
        if status == errSecDuplicateItem { throw CredentialFailure("credential_key_conflict") }
        throw CredentialFailure("credential_key_unavailable")
    }
    func read() throws -> Data? {
        var q = query
        q[kSecReturnAttributes as String] = true
        q[kSecReturnPersistentRef as String] = true
        // A weaker legacy synchronized item must not be hidden by the write policy.
        // Ambiguous same-namespace records fail closed instead of selecting one.
        q[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        q[kSecMatchLimit as String] = kSecMatchLimitAll
        // Never turn a locked/unavailable keychain into a successful empty store.
        let (result, item) = operations.copy(q as CFDictionary)
        if result == errSecItemNotFound { return nil }
        try checkedStatus(result)
        guard let matches = item as? [[String: Any]], matches.count == 1 else {
            throw CredentialFailure("credential_key_conflict")
        }
        let attributes = matches[0]
        try checkAttributes(attributes)
        guard let reference = attributes[kSecValuePersistentRef as String] as? Data, !reference.isEmpty else {
            throw CredentialFailure("credential_key_conflict")
        }
        // Apple forbids kSecReturnData together with kSecMatchLimitAll for
        // password records. Fetch this unique persistent reference exactly once,
        // with attributes again so policy is checked at the value read too.
        let dataQuery: [String: Any] = [
            kSecValuePersistentRef as String: reference,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: authentication,
        ]
        let (dataStatus, dataItem) = operations.copy(dataQuery as CFDictionary)
        try checkedStatus(dataStatus, missing: "credential_state_missing")
        guard let current = dataItem as? [String: Any], let data = current[kSecValueData as String] as? Data else {
            throw CredentialFailure("credential_corrupt")
        }
        try checkAttributes(current)
        try requireCredential(data.count <= CredentialProtocol.maxSnapshotBytes, "credential_corrupt")
        return data
    }
    private func checkAttributes(_ attributes: [String: Any]) throws {
        try requireCredential(attributes[kSecAttrService as String] as? String == "africlub.native-identity-credentials.v1." + namespace &&
            attributes[kSecAttrAccount as String] as? String == "installation-journal-v1", "credential_key_conflict")
        try requireCredential(attributes[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly as String,
            "credential_key_conflict")
        if let synchronized = attributes[kSecAttrSynchronizable as String] {
            try requireCredential(CFGetTypeID(synchronized as CFTypeRef) == CFBooleanGetTypeID() &&
                (synchronized as? NSNumber)?.boolValue == false, "credential_key_conflict")
        }
        try requireCredential(attributes[kSecAttrAccessControl as String] == nil, "credential_key_conflict")
    }
    func insert(_ value: Data) throws {
        try requireCredential(value.count <= CredentialProtocol.maxSnapshotBytes)
        var q = query
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        q[kSecValueData as String] = value
        try checkedStatus(operations.add(q as CFDictionary))
    }
    func replace(_ value: Data) throws {
        try requireCredential(value.count <= CredentialProtocol.maxSnapshotBytes)
        // No errSecItemNotFound -> add fallback. Absence is an unresolved state failure.
        try checkedStatus(operations.update(query as CFDictionary, [kSecValueData as String: value] as CFDictionary), missing: "credential_state_missing")
    }
}
#endif
