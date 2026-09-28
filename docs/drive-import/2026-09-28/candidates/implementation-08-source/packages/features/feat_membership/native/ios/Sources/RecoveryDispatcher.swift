import Foundation

/// Channel callers cannot choose owner IDs, paths, service names, groups or policies.
final class NativeRecoveryDispatcher: @unchecked Sendable {
    private let owner: String
    private let store: NativeRecoveryStore
    private let usable: () -> Bool
    init(store: NativeRecoveryStore, owner: String = RecoveryProtocol.newID(), usable: @escaping () -> Bool) throws {
        try RecoveryProtocol.identifier(owner)
        self.store = store; self.owner = owner; self.usable = usable
    }
    private func fields(_ value: Any?, _ expected: Set<String>) throws -> [String: Any] {
        guard let value = value as? [String: Any], Set(value.keys) == expected else { throw RecoveryFailure("recovery_invalid_request") }
        return value
    }
    private func string(_ value: Any?) throws -> String {
        guard let value = value as? String else { throw RecoveryFailure("recovery_invalid_request") }; return value
    }
    func invoke(_ method: String, arguments: Any?) throws -> [String: Any] {
        // Release must remain possible after lock/background; it never reads stored values.
        if method != "release" { try requireRecovery(usable(), "recovery_device_locked") }
        switch method {
        case "tryAcquire":
            let a = try fields(arguments, ["scope", "acquisitionId"])
            let token = try store.acquire(owner: owner, scope: string(a["scope"]), acquisitionID: string(a["acquisitionId"]))
            return ["version": 1, "busy": token == nil, "lease": token as Any? ?? NSNull()]
        case "load":
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
        default: throw RecoveryFailure("recovery_invalid_request")
        }
    }
    func dispose() throws { try store.close(owner: owner) }
}
