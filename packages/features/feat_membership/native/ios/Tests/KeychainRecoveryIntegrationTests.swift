#if os(iOS)
import XCTest
import Security

/// APPLE-ONLY TEST TARGET. Not executed by the portable verifier. Add core and
/// Apple source files to an isolated XCTest target before running on iOS.
/// Cleanup is limited to an unpredictable per-test namespace, never production data.
final class KeychainRecoveryIntegrationTests: XCTestCase {
    private var root: String!
    private var namespace: String!
    private var blob: KeychainRecoveryBlob!
    private var store: NativeRecoveryStore!
    private let owner = RecoveryProtocol.newID()
    private let request = RecoveryProtocol.newID()
    private let scope = "africlub-membership-v1:24:20000000-0000-4000-8000-000000000001"
    private var testQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "africlub.native-checkout-recovery.v1." + namespace,
         kSecAttrAccount as String: "installation-snapshot-v1", kSecAttrSynchronizable as String: false]
    }
    override func setUpWithError() throws {
        try super.setUpWithError()
        // Run on an unlocked test device; protected-data failures are test failures, not skips.
        namespace = "com.africlub.xctest." + RecoveryProtocol.newID()
        root = URL(fileURLWithPath: NSTemporaryDirectory()).resolvingSymlinksInPath()
            .appendingPathComponent("africlub-recovery-" + RecoveryProtocol.newID()).path
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.complete])
        blob = try KeychainRecoveryBlob(bundleID: namespace)
        store = try NativeRecoveryStore(root: root, applicationID: namespace, storage: blob)
    }
    override func tearDownWithError() throws {
        try store?.close(owner: owner)
        if namespace != nil {
            var cleanup = testQuery
            cleanup[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
            _ = SecItemDelete(cleanup as CFDictionary)
        }
        if root != nil { try? FileManager.default.removeItem(atPath: root) }
        try super.tearDownWithError()
    }
    private func token() throws -> String { try XCTUnwrap(store.acquire(owner: owner, scope: scope, acquisitionID: request)) }
    func testRealKeychainRoundTrip() throws {
        let lease = try token()
        XCTAssertTrue(try store.compareAndSet(owner: owner, scope: scope, lease: lease, expected: nil, value: "synthetic-pending"))
        XCTAssertEqual(try store.load(owner: owner, scope: scope, lease: lease), "synthetic-pending")
    }
    func testRequiredAccessibilityAndNoSynchronization() throws {
        _ = try token()
        var query = testQuery; query[kSecReturnAttributes as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var output: CFTypeRef?
        XCTAssertEqual(SecItemCopyMatching(query as CFDictionary, &output), errSecSuccess)
        let a = try XCTUnwrap(output as? [String: Any])
        XCTAssertEqual(a[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertNotEqual((a[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue, true)
    }
    func testReopenRetainsMarker() throws {
        let lease = try token()
        _ = try store.compareAndSet(owner: owner, scope: scope, lease: lease, expected: nil, value: "reserved")
        try store.close(owner: owner)
        store = try NativeRecoveryStore(root: root, applicationID: namespace, storage: KeychainRecoveryBlob(bundleID: namespace))
        XCTAssertEqual(try store.load(owner: owner, scope: scope, lease: token()), "reserved")
    }
    func testMissingKeychainItemDoesNotResetAnchor() throws {
        _ = try token(); try store.close(owner: owner)
        XCTAssertEqual(SecItemDelete(testQuery as CFDictionary), errSecSuccess)
        XCTAssertThrowsError(try token()) { XCTAssertEqual(($0 as? RecoveryFailure)?.code, "recovery_state_missing") }
        XCTAssertNil(try blob.read())
    }
    func testMissingAnchorDoesNotDeleteKeychain() throws {
        _ = try token(); try store.close(owner: owner); let original = try blob.read()
        try FileManager.default.removeItem(atPath: root + "/installation.anchor")
        XCTAssertThrowsError(try token()) { XCTAssertEqual(($0 as? RecoveryFailure)?.code, "recovery_state_missing") }
        XCTAssertEqual(try blob.read(), original)
    }
    func testWeakerExistingKeychainPolicyIsRejected() throws {
        var q = testQuery; q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        q[kSecValueData as String] = Data([1, 2, 3])
        XCTAssertEqual(SecItemAdd(q as CFDictionary, nil), errSecSuccess)
        XCTAssertThrowsError(try blob.read()) { XCTAssertEqual(($0 as? RecoveryFailure)?.code, "recovery_key_conflict") }
    }
    func testSynchronizedLegacyItemIsRejectedInsteadOfMissing() throws {
        var q = testQuery
        q[kSecAttrSynchronizable as String] = true
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        q[kSecValueData as String] = Data([1, 2, 3])
        XCTAssertEqual(SecItemAdd(q as CFDictionary, nil), errSecSuccess)
        XCTAssertThrowsError(try blob.read()) { XCTAssertEqual(($0 as? RecoveryFailure)?.code, "recovery_key_conflict") }
    }
    func testAmbiguousLegacyAndDeviceOnlyItemsAreRejected() throws {
        try blob.insert(Data([1, 2, 3]))
        var q = testQuery
        q[kSecAttrSynchronizable as String] = true
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        q[kSecValueData as String] = Data([4, 5, 6])
        XCTAssertEqual(SecItemAdd(q as CFDictionary, nil), errSecSuccess)
        XCTAssertThrowsError(try blob.read()) { XCTAssertEqual(($0 as? RecoveryFailure)?.code, "recovery_key_conflict") }
    }
    func testByteExactCompareAndSet() throws {
        let lease = try token()
        _ = try store.compareAndSet(owner: owner, scope: scope, lease: lease, expected: nil, value: "é")
        XCTAssertFalse(try store.compareAndSet(owner: owner, scope: scope, lease: lease, expected: "e\u{0301}", value: "other"))
    }
}
#endif
