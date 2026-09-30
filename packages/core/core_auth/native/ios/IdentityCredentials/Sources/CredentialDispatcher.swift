import Foundation

/// Channel callers cannot choose owner IDs, paths, service names, groups or policies.
final class NativeCredentialDispatcher: @unchecked Sendable {
    private let owner: String
    private let store: NativeCredentialStore
    private let policy: CredentialPolicy
    private let usable: () -> Bool
    private let mutex = NSLock()
    private var closed = false
    init(store: NativeCredentialStore, policy: CredentialPolicy, owner: String = CredentialProtocol.newID(), usable: @escaping () -> Bool) throws {
        try CredentialProtocol.identifier(owner)
        self.store = store; self.policy = policy; self.owner = owner; self.usable = usable
    }
    private func fields(_ value: Any?, _ expected: Set<String>) throws -> [String: Any] {
        guard let value = value as? [String: Any], Set(value.keys) == expected else { throw CredentialFailure("credential_invalid_request") }
        return value
    }
    private func string(_ value: Any?) throws -> String {
        guard let value = value as? String else { throw CredentialFailure("credential_invalid_request") }; return value
    }
    func invoke(_ method: String, arguments: Any?) throws -> [String: Any] {
        mutex.lock(); defer { mutex.unlock() }
        try requireCredential(!closed, "credential_disabled")
        // Release must remain possible after lock/background; it never reads stored values.
        if method != "release" && method != "drain" { try requireCredential(usable(), "credential_device_locked") }
        if method != "release" && method != "drain" {
            guard let a = arguments as? [String: Any] else { throw CredentialFailure() }
            try policy.authorize(string(a["scope"]))
        }
        switch method {
        case "describe":
            let a = try fields(arguments, ["scope"])
            return ["version": 1, "scope": try string(a["scope"]), "applicationId": policy.applicationID, "maxJournalBytes": 8192, "policy": "ios_passcode_keychain_no_backup_v1"]
        case "drain":
            let a = try fields(arguments, ["scope", "acquisitionId"])
            try CredentialProtocol.bind(string(a["scope"]), policy.applicationID)
            try CredentialProtocol.identifier(string(a["acquisitionId"]))
            return ["version": 1, "settled": true]
        case "tryAcquire":
            let a = try fields(arguments, ["scope", "acquisitionId"])
            let token = try store.acquire(owner: owner, scope: string(a["scope"]), acquisitionID: string(a["acquisitionId"]))
            return ["version": 1, "busy": token == nil, "lease": token as Any? ?? NSNull()]
        case "read":
            let a = try fields(arguments, ["scope", "lease"])
            let result = try store.load(owner: owner, scope: string(a["scope"]), lease: string(a["lease"]))
            return ["version": 1, "value": result as Any? ?? NSNull()]
        case "compareAndSet":
            let a = try fields(arguments, ["scope", "lease", "expected", "value"])
            let expected: String?
            if a["expected"] is NSNull { expected = nil } else { expected = try string(a["expected"]) }
            let result = try store.compareAndSet(owner: owner, scope: string(a["scope"]), lease: string(a["lease"]), expected: expected, value: string(a["value"]))
            return ["version": 1, "updated": result]
        case "release":
            let a = try fields(arguments, ["scope", "acquisitionId"])
            try store.release(owner: owner, scope: string(a["scope"]), acquisitionID: string(a["acquisitionId"]))
            return ["version": 1, "released": true]
        default: throw CredentialFailure("credential_invalid_request")
        }
    }
    func dispose() throws {
        mutex.lock(); defer { mutex.unlock() }
        closed = true
        try store.close(owner: owner)
    }
}
