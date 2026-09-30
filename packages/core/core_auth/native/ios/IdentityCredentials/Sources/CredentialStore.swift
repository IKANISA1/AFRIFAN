import Foundation

/// Production implementation is the Apple Keychain adapter. Test implementations
/// are explicitly unprotected and must never be registered in a shipped app.
protocol CredentialBlobStorage: AnyObject {
    var namespace: String { get }
    func read() throws -> Data?
    func insert(_ value: Data) throws
    func replace(_ value: Data) throws
}

final class CredentialPersistence {
    let root: String
    let applicationID: String
    let storage: CredentialBlobStorage
    let fault: (String) throws -> Void
    init(root: String, applicationID: String, storage: CredentialBlobStorage,
         fault: @escaping (String) throws -> Void = { _ in }) {
        self.root = root; self.applicationID = applicationID; self.storage = storage; self.fault = fault
    }
    func initialize() throws {
        let current = try storage.read(), anchor = try CredentialFiles.readAnchor(root)
        if current == nil && anchor == nil {
            let install = CredentialProtocol.newID()
            let data = try CredentialSnapshotCodec.encode(CredentialSnapshot(applicationID: applicationID,
                installationID: install, revision: 0, values: [:]))
            try CredentialFiles.createAnchor(root, install)
            do {
                try fault("after_anchor")
                try storage.insert(data)
                try fault("after_insert")
                try requireCredential(try storage.read() == data, "credential_write_unknown")
            } catch { throw CredentialFailure("credential_write_unknown") }
        } else {
            try requireCredential(current != nil && anchor != nil, "credential_state_missing")
        }
        _ = try snapshot()
    }
    func snapshot() throws -> CredentialSnapshot {
        guard let data = try storage.read(), let anchor = try CredentialFiles.readAnchor(root) else {
            throw CredentialFailure("credential_state_missing")
        }
        let value = try CredentialSnapshotCodec.decode(data)
        try requireCredential(value.applicationID == applicationID && value.installationID == anchor, "credential_key_conflict")
        for scope in value.values.keys { try CredentialProtocol.bind(scope, applicationID) }
        return value
    }
    func load(_ scope: String) throws -> String? { try snapshot().values[scope] }
    func compareAndSet(_ scope: String, expected: String?, value: String) throws -> Bool {
        try CredentialProtocol.value(value)
        if let expected { try CredentialProtocol.value(expected) }
        let old = try snapshot()
        // Swift String equality normalizes Unicode; the Dart CAS contract is byte-exact.
        if old.values[scope].map({ Data($0.utf8) }) != expected.map({ Data($0.utf8) }) { return false }
        try requireCredential(old.revision < Int64.max, "credential_capacity")
        try requireCredential(old.values[scope] != nil || old.values.count < CredentialProtocol.maxScopes, "credential_capacity")
        var values = old.values; values[scope] = value
        let next = try CredentialSnapshotCodec.encode(CredentialSnapshot(applicationID: applicationID,
            installationID: old.installationID, revision: old.revision + 1, values: values))
        do {
            try fault("before_replace")
            try storage.replace(next)
            try fault("after_replace")
            try requireCredential(try storage.read() == next, "credential_write_unknown")
        } catch { throw CredentialFailure("credential_write_unknown") }
        return true
    }
}

/// All engines in this process must use this one compiled module and fixed root.
/// OS flock additionally serializes cooperating processes. There is no lease timer.
final class CredentialLeaseRegistry: @unchecked Sendable {
    static let shared = CredentialLeaseRegistry()
    struct Lease {
        let owner: String, scope: String, acquisitionID: String, token: String
        let file: Int32
        let persistence: CredentialPersistence
    }
    let mutex = NSLock()
    var leases: [String: Lease] = [:]
    func synchronized<T>(_ action: () throws -> T) rethrows -> T {
        mutex.lock(); defer { mutex.unlock() }; return try action()
    }
}

final class NativeCredentialStore: @unchecked Sendable {
    private let root: String
    private let applicationID: String
    private let persistence: CredentialPersistence
    private let registry = CredentialLeaseRegistry.shared
    init(root: String, applicationID: String, storage: CredentialBlobStorage,
         fault: @escaping (String) throws -> Void = { _ in }) throws {
        self.root = try CredentialFiles.directory(root)
        try CredentialProtocol.application(applicationID)
        try requireCredential(storage.namespace == applicationID, "credential_key_conflict")
        self.applicationID = applicationID
        self.persistence = CredentialPersistence(root: self.root, applicationID: applicationID, storage: storage, fault: fault)
    }
    func acquire(owner: String, scope: String, acquisitionID: String) throws -> String? {
        try registry.synchronized {
            try CredentialProtocol.identifier(owner); try CredentialProtocol.identifier(acquisitionID); try CredentialProtocol.bind(scope, applicationID)
            if let held = registry.leases[root] {
                try CredentialFiles.checkedFile(held.file, root + "/credentials.lock")
                try requireCredential(held.persistence.applicationID == applicationID, "credential_key_conflict")
                return held.owner == owner && held.scope == scope && held.acquisitionID == acquisitionID ? held.token : nil
            }
            try requireCredential(registry.leases.count < 16, "credential_capacity")
            guard let fd = try CredentialFiles.acquire(root) else { return nil }
            do {
                try persistence.initialize()
                let token = CredentialProtocol.newID()
                registry.leases[root] = .init(owner: owner, scope: scope, acquisitionID: acquisitionID,
                    token: token, file: fd, persistence: persistence)
                return token
            } catch { CredentialFiles.release(fd); throw error }
        }
    }
    private func held(owner: String, scope: String, token: String) throws -> CredentialLeaseRegistry.Lease {
        try CredentialProtocol.identifier(owner); try CredentialProtocol.identifier(token); try CredentialProtocol.bind(scope, applicationID)
        guard let h = registry.leases[root], h.owner == owner && h.scope == scope && h.token == token else {
            throw CredentialFailure("credential_lock_required")
        }
        try requireCredential(h.persistence.applicationID == applicationID, "credential_key_conflict")
        try CredentialFiles.checkedFile(h.file, root + "/credentials.lock")
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
            try CredentialProtocol.identifier(owner); try CredentialProtocol.identifier(acquisitionID); try CredentialProtocol.bind(scope, applicationID)
            guard let h = registry.leases[root], h.owner == owner && h.scope == scope && h.acquisitionID == acquisitionID else { return }
            CredentialFiles.release(h.file); registry.leases.removeValue(forKey: root)
        }
    }
    func close(owner: String) throws {
        try registry.synchronized {
            try CredentialProtocol.identifier(owner)
            guard let h = registry.leases[root], h.owner == owner else { return }
            CredentialFiles.release(h.file); registry.leases.removeValue(forKey: root)
        }
    }
}
