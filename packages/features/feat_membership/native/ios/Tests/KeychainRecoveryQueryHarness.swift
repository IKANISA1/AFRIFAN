import Foundation
import Security
import LocalAuthentication

// Synthetic Security responses only. No SecItem call, real credentials, prompts,
// Keychain, signing or network run in this executable.
private final class FakeSecurity: RecoverySecurityOperations {
    var responses: [(OSStatus, CFTypeRef?)] = []
    var copies: [[String: Any]] = []
    var adds: [[String: Any]] = []
    var updates: [([String: Any], [String: Any])] = []
    var writeStatus: OSStatus = errSecSuccess
    func copy(_ query: CFDictionary) -> (OSStatus, CFTypeRef?) {
        copies.append(query as! [String: Any]); precondition(!responses.isEmpty)
        return responses.removeFirst()
    }
    func add(_ query: CFDictionary) -> OSStatus { adds.append(query as! [String: Any]); return writeStatus }
    func update(_ query: CFDictionary, _ attributes: CFDictionary) -> OSStatus {
        updates.append((query as! [String: Any], attributes as! [String: Any])); return writeStatus
    }
}
private func check(_ value: Bool) throws { if !value { throw RecoveryFailure("test_failed") } }
private func failure(_ code: String, _ work: () throws -> Void) throws {
    do { try work() } catch let error as RecoveryFailure { try check(error.code == code); return }
    throw RecoveryFailure("expected_refusal")
}
private let app = "rw.ikanisa.rayonSports.qa.codex"
private let reference = Data([1, 2, 3])
private let journal = Data("SYNTHETIC_CHECKOUT_SNAPSHOT".utf8)
private func attributes(_ overrides: [String: Any] = [:]) -> [String: Any] {
    var value: [String: Any] = [
        kSecAttrService as String: "africlub.native-checkout-recovery.v1." + app,
        kSecAttrAccount as String: "installation-snapshot-v1",
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        kSecAttrSynchronizable as String: false,
        kSecValuePersistentRef as String: reference,
    ]
    value.merge(overrides) { _, new in new }; return value
}
private func valid(_ fake: FakeSecurity) {
    fake.responses = [(errSecSuccess, [attributes()] as CFArray),
        (errSecSuccess, attributes([kSecValueData as String: journal]) as CFDictionary)]
}
private func noPrompt(_ query: [String: Any]) throws {
    try check((query[kSecUseAuthenticationContext as String] as? LAContext)?.interactionNotAllowed == true)
    try check(query[kSecAttrAccessGroup as String] == nil)
}

@main private enum RecoveryKeychainQueryHarness {
    static func main() throws {
        var results: [[String: Any]] = []
        func test(_ name: String, _ work: () throws -> Void) {
            do { try work(); results.append(["name": name, "passed": true]) }
            catch { results.append(["name": name, "passed": false]) }
        }
        test("attributes-only all-match precedes exact persistent-reference single-data query") {
            let fake=FakeSecurity();valid(fake);let store=try KeychainRecoveryBlob(bundleID:app,operations:fake)
            try check(try store.read() == journal);try check(fake.copies.count == 2)
            let first=fake.copies[0], second=fake.copies[1]
            try check(first[kSecReturnData as String] == nil)
            try check(first[kSecMatchLimit as String] as? String == kSecMatchLimitAll as String)
            try check(first[kSecAttrSynchronizable as String] as? String == kSecAttrSynchronizableAny as String)
            try check(second[kSecMatchLimit as String] as? String == kSecMatchLimitOne as String)
            try check(second[kSecValuePersistentRef as String] as? Data == reference)
            try check(second[kSecReturnData as String] as? Bool == true)
            try noPrompt(first);try noPrompt(second)
        }
        test("absence alone is empty without a second query") {
            let fake=FakeSecurity();fake.responses=[(errSecItemNotFound,nil)]
            try check(try KeychainRecoveryBlob(bundleID:app,operations:fake).read() == nil);try check(fake.copies.count == 1)
        }
        for (name, records) in [("zero", []), ("two", [attributes(),attributes()])] {
            test("ambiguous \(name) metadata records are rejected before any data lookup") {
                let fake=FakeSecurity();fake.responses=[(errSecSuccess,records as CFArray)]
                try failure("recovery_key_conflict") {_ = try KeychainRecoveryBlob(bundleID:app,operations:fake).read()}
                try check(fake.copies.count == 1)
            }
        }
        for (name, override) in [
            ("weak", [kSecAttrAccessible as String:kSecAttrAccessibleAfterFirstUnlock]),
            ("synchronized", [kSecAttrSynchronizable as String:true]),
            ("string synchronizable", [kSecAttrSynchronizable as String:"false"]),
            ("numeric synchronizable", [kSecAttrSynchronizable as String:NSNumber(value:0)]),
            ("other service", [kSecAttrService as String:"other"]),
            ("other account", [kSecAttrAccount as String:"other"]),
            ("authentication access control", [kSecAttrAccessControl as String:"synthetic ACL"]),
            ("empty reference", [kSecValuePersistentRef as String:Data()]),
        ] as [(String, [String: Any])] {
            test("\(name) metadata rejected before data lookup") {
                let fake=FakeSecurity();fake.responses=[(errSecSuccess,[attributes(override)] as CFArray)]
                try failure("recovery_key_conflict") {_ = try KeychainRecoveryBlob(bundleID:app,operations:fake).read()}
                try check(fake.copies.count == 1)
            }
        }
        test("value lookup revalidates changed policy") {
            let fake=FakeSecurity();valid(fake);fake.responses[1]=(errSecSuccess,attributes([
                kSecValueData as String:journal,kSecAttrSynchronizable as String:true]) as CFDictionary)
            try failure("recovery_key_conflict") {_ = try KeychainRecoveryBlob(bundleID:app,operations:fake).read()}
        }
        test("lost record after metadata lookup is unavailable and never reinserted") {
            let fake=FakeSecurity();valid(fake);fake.responses[1]=(errSecItemNotFound,nil)
            try failure("recovery_state_missing") {_ = try KeychainRecoveryBlob(bundleID:app,operations:fake).read()}
            try check(fake.adds.isEmpty && fake.updates.isEmpty)
        }
        test("oversized stored data is rejected") {
            let fake=FakeSecurity();valid(fake);fake.responses[1]=(errSecSuccess,attributes([
                kSecValueData as String:Data(repeating:0,count:RecoveryProtocol.maxSnapshotBytes+1)]) as CFDictionary)
            try failure("recovery_corrupt") {_ = try KeychainRecoveryBlob(bundleID:app,operations:fake).read()}
        }
        for status in [errSecInteractionNotAllowed,errSecAuthFailed] {
            test("Security failure is finite and never converted to empty status \(status)") {
                let fake=FakeSecurity();fake.responses=[(status,nil)]
                try failure(status == errSecInteractionNotAllowed ? "recovery_device_locked":"recovery_key_unavailable") {
                    _ = try KeychainRecoveryBlob(bundleID:app,operations:fake).read()
                }
            }
        }
        test("insert pins non-synchronized existing unlocked-device policy without access group or UI") {
            let fake=FakeSecurity();try KeychainRecoveryBlob(bundleID:app,operations:fake).insert(journal)
            let q=fake.adds[0];try noPrompt(q)
            try check(q[kSecAttrAccessible as String] as? String == kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
            try check(q[kSecAttrSynchronizable as String] as? Bool == false && fake.updates.isEmpty)
        }
        test("missing replace never falls back to add or delete") {
            let fake=FakeSecurity();fake.writeStatus=errSecItemNotFound
            try failure("recovery_state_missing") {try KeychainRecoveryBlob(bundleID:app,operations:fake).replace(journal)}
            try check(fake.adds.isEmpty && fake.updates.count == 1);try noPrompt(fake.updates[0].0)
        }
        let passed=results.filter{$0["passed"] as? Bool == true}.count
        let summary: [String:Any] = ["schemaVersion":1,"passed":passed,"failed":results.count-passed,
            "tests":results,"keychainExecuted":false,"networkRequests":0,"physicalDeviceAccepted":false]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject:summary,options:[.prettyPrinted,.sortedKeys]))
        FileHandle.standardOutput.write(Data([10]));if passed != results.count {exit(1)}
    }
}
