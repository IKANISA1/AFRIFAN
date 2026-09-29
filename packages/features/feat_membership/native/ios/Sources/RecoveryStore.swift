import Foundation

/// Production implementation is the Apple Keychain adapter. Test implementations
/// are explicitly unprotected and must never be registered in a shipped app.
protocol RecoveryBlobStorage: AnyObject {
    var namespace: String { get }
    func read() throws -> Data?
    func insert(_ value: Data) throws
    func replace(_ value: Data) throws
}

final class RecoveryPersistence {
    let root: String
    let applicationID: String
    let storage: RecoveryBlobStorage
    let fault: (String) throws -> Void
    init(root: String, applicationID: String, storage: RecoveryBlobStorage,
         fault: @escaping (String) throws -> Void = { _ in }) {
        self.root = root; self.applicationID = applicationID; self.storage = storage; self.fault = fault
    }
    func initialize() throws {
        let current = try storage.read(), anchor = try RecoveryFiles.readAnchor(root)
        if current == nil && anchor == nil {
            let install = RecoveryProtocol.newID()
            let data = try RecoverySnapshotCodec.encode(RecoverySnapshot(applicationID: applicationID,
                installationID: install, revision: 0, values: [:]))
            try RecoveryFiles.createAnchor(root, install)
            do {
                try fault("after_anchor")
                try storage.insert(data)
                try fault("after_insert")
                try requireRecovery(try storage.read() == data, "recovery_write_unknown")
            } catch { throw RecoveryFailure("recovery_write_unknown") }
        } else {
            try requireRecovery(current != nil && anchor != nil, "recovery_state_missing")
        }
        _ = try snapshot()
    }
    func snapshot() throws -> RecoverySnapshot {
        guard let data = try storage.read(), let anchor = try RecoveryFiles.readAnchor(root) else {
            throw RecoveryFailure("recovery_state_missing")
        }
        let value = try RecoverySnapshotCodec.decode(data)
        try requireRecovery(value.applicationID == applicationID && value.installationID == anchor, "recovery_key_conflict")
        return value
    }
    func load(_ scope: String) throws -> String? { try snapshot().values[scope] }
    func compareAndSet(_ scope: String, expected: String?, value: String) throws -> Bool {
        try RecoveryProtocol.value(value)
        if let expected { try RecoveryProtocol.value(expected) }
        let old = try snapshot()
        // Swift String equality normalizes Unicode; the Dart CAS contract is byte-exact.
        if old.values[scope].map({ Data($0.utf8) }) != expected.map({ Data($0.utf8) }) { return false }
        try requireRecovery(old.revision < Int64.max, "recovery_capacity")
        try requireRecovery(old.values[scope] != nil || old.values.count < RecoveryProtocol.maxScopes, "recovery_capacity")
        var values = old.values; values[scope] = value
        let next = try RecoverySnapshotCodec.encode(RecoverySnapshot(applicationID: applicationID,
            installationID: old.installationID, revision: old.revision + 1, values: values))
        do {
            try fault("before_replace")
            try storage.replace(next)
            try fault("after_replace")
            try requireRecovery(try storage.read() == next, "recovery_write_unknown")
        } catch { throw RecoveryFailure("recovery_write_unknown") }
        return true
    }
}

/// All engines in this process must use this one compiled module and fixed root.
/// OS flock additionally serializes cooperating processes. There is no lease timer.
final class RecoveryLeaseRegistry: @unchecked Sendable {
    static let shared = RecoveryLeaseRegistry()
    struct Lease {
        let owner: String, scope: String, acquisitionID: String, token: String
        let file: Int32
        let persistence: RecoveryPersistence
    }
    let mutex = NSLock()
    var leases: [String: Lease] = [:]
    func synchronized<T>(_ action: () throws -> T) rethrows -> T {
        mutex.lock(); defer { mutex.unlock() }; return try action()
    }
}

final class NativeRecoveryStore: @unchecked Sendable {
    private let root: String
    private let applicationID: String
    private let persistence: RecoveryPersistence
    private let registry = RecoveryLeaseRegistry.shared
    init(root: String, applicationID: String, storage: RecoveryBlobStorage,
         fault: @escaping (String) throws -> Void = { _ in }) throws {
        self.root = try RecoveryFiles.directory(root)
        try RecoveryProtocol.application(applicationID)
        try requireRecovery(storage.namespace == applicationID, "recovery_key_conflict")
        self.applicationID = applicationID
        self.persistence = RecoveryPersistence(root: self.root, applicationID: applicationID, storage: storage, fault: fault)
    }
    func acquire(owner: String, scope: String, acquisitionID: String) throws -> String? {
        try registry.synchronized {
            try RecoveryProtocol.identifier(owner); try RecoveryProtocol.identifier(acquisitionID); try RecoveryProtocol.scope(scope)
            if let held = registry.leases[root] {
                try RecoveryFiles.checkedFile(held.file, root + "/recovery.lock")
                try requireRecovery(held.persistence.applicationID == applicationID, "recovery_key_conflict")
                return held.owner == owner && held.scope == scope && held.acquisitionID == acquisitionID ? held.token : nil
            }
            try requireRecovery(registry.leases.count < 16, "recovery_capacity")
            guard let fd = try RecoveryFiles.acquire(root) else { return nil }
            do {
                try persistence.initialize()
                let token = RecoveryProtocol.newID()
                registry.leases[root] = .init(owner: owner, scope: scope, acquisitionID: acquisitionID,
                    token: token, file: fd, persistence: persistence)
                return token
            } catch { RecoveryFiles.release(fd); throw error }
        }
    }
    private func held(owner: String, scope: String, token: String) throws -> RecoveryLeaseRegistry.Lease {
        try RecoveryProtocol.identifier(owner); try RecoveryProtocol.identifier(token); try RecoveryProtocol.scope(scope)
        guard let h = registry.leases[root], h.owner == owner && h.scope == scope && h.token == token else {
            throw RecoveryFailure("recovery_lock_required")
        }
        try requireRecovery(h.persistence.applicationID == applicationID, "recovery_key_conflict")
        try RecoveryFiles.checkedFile(h.file, root + "/recovery.lock")
        return h
    }
    func load(owner: String, scope: String, lease: String) throws -> String? {
        try registry.synchronized { try held(owner: owner, scope: scope, token: lease).persistence.load(scope) }
    }
    func compareAndSet(owner: String, scope: String, lease: String, expected: String?, value: String) throws -> Bool {
        try registry.synchronized {
            try held(owner: owner, scope: scope, token: lease).persistence.compareAndSet(scope, expected: expected, value: value)
        }
    }
    func release(owner: String, scope: String, acquisitionID: String) throws {
        try registry.synchronized {
            try RecoveryProtocol.identifier(owner); try RecoveryProtocol.identifier(acquisitionID); try RecoveryProtocol.scope(scope)
            guard let h = registry.leases[root], h.owner == owner && h.scope == scope && h.acquisitionID == acquisitionID else { return }
            RecoveryFiles.release(h.file); registry.leases.removeValue(forKey: root)
        }
    }
    func close(owner: String) throws {
        try registry.synchronized {
            try RecoveryProtocol.identifier(owner)
            guard let h = registry.leases[root], h.owner == owner else { return }
            RecoveryFiles.release(h.file); registry.leases.removeValue(forKey: root)
        }
    }
}
