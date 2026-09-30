import Foundation

/// Errors are intentionally finite: never return Keychain data or OS error text to Dart.
struct CredentialFailure: Error, Equatable, Sendable {
    let code: String
    init(_ code: String = "credential_unavailable") { self.code = CredentialProtocol.safeCode(code) }
}
func requireCredential(_ condition: Bool, _ code: String = "credential_invalid_request") throws {
    if !condition { throw CredentialFailure(code) }
}
enum CredentialProtocol {
    static let maxScopes = 64
    static let maxValueBytes = 8192
    static let maxSnapshotBytes = 600_000
    static let channel = "africlub/native-identity-credentials/v1"
    private static let errors: Set<String> = ["credential_unavailable", "credential_disabled", "credential_invalid_request",
        "credential_invalid_scope", "credential_invalid_value", "credential_binding_mismatch", "credential_corrupt",
        "credential_capacity", "credential_directory_unavailable", "credential_lock_lost", "credential_lock_required",
        "credential_key_unavailable", "credential_key_conflict", "credential_state_missing", "credential_write_unknown",
        "credential_device_locked", "credential_channel_unavailable"]
    static func safeCode(_ value: String) -> String { errors.contains(value) ? value : "credential_unavailable" }
    static func requestShape(_ method: String, _ arguments: [String: Any]) -> Bool {
        ["describe", "tryAcquire", "read", "compareAndSet", "drain", "release"].contains(method) &&
            (1...4).contains(arguments.count) && arguments.values.allSatisfy {
                $0 is NSNull || ($0 as? String).map { $0.utf8.count <= maxValueBytes } == true
            }
    }
    static func matches(_ value: String, _ pattern: String) -> Bool {
        guard let r = value.range(of: pattern, options: .regularExpression) else { return false }
        return r == value.startIndex..<value.endIndex
    }
    static func identifier(_ value: String) throws {
        try requireCredential(matches(value, "[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"))
    }
    static func scope(_ value: String) throws {
        let p = value.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        try requireCredential(value.utf8.count <= 512 && p.count == 3, "credential_invalid_scope")
        try application(p[0])
        try requireCredential(matches(p[1], "https://[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?(?:[.][a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+(?:[:]443)?") &&
            matches(p[2], "[1-9][0-9]{0,9}"), "credential_invalid_scope")
        guard let u = URLComponents(string: p[1]), let host = u.host else { throw CredentialFailure("credential_invalid_scope") }
        try requireCredential(host.utf8.count <= 253 && !matches(host, "[0-9.]+"), "credential_invalid_scope")
    }
    static func bind(_ value: String, _ applicationID: String) throws {
        try scope(value)
        try requireCredential(value.split(separator: "|", omittingEmptySubsequences: false).first.map(String.init) == applicationID, "credential_binding_mismatch")
    }
    static func value(_ value: String) throws {
        try requireCredential(!value.isEmpty && value.utf8.count <= maxValueBytes, "credential_invalid_value")
    }
    static func application(_ value: String) throws {
        try requireCredential(value.utf8.count <= 128 && matches(value, "[A-Za-z][A-Za-z0-9_]*(?:[.][A-Za-z][A-Za-z0-9_]*)+"), "credential_invalid_scope")
    }
    static func newID() -> String { UUID().uuidString.lowercased() }
}

struct CredentialSnapshot: Equatable, Sendable {
    let applicationID: String
    let installationID: String
    let revision: Int64
    let values: [String: String]
}

/// A bounded binary format avoids duplicate JSON keys and platform number coercion.
/// This is the iOS internal format, NOT an Android ciphertext migration format.
enum CredentialSnapshotCodec {
    private static let magic: [UInt8] = [65, 70, 82, 73, 0, 0, 0, 1]
    static func encode(_ value: CredentialSnapshot) throws -> Data {
        try CredentialProtocol.application(value.applicationID)
        try CredentialProtocol.identifier(value.installationID)
        try requireCredential(value.revision >= 0 && value.values.count <= CredentialProtocol.maxScopes)
        var bytes = magic
        func number(_ value: UInt64, _ width: Int) {
            for position in (0..<width).reversed() { bytes.append(UInt8(truncatingIfNeeded: value >> (position * 8))) }
        }
        func text(_ value: String) { let b = Array(value.utf8); number(UInt64(b.count), 4); bytes.append(contentsOf: b) }
        text(value.applicationID); text(value.installationID)
        number(UInt64(value.revision), 8); number(UInt64(value.values.count), 4)
        for key in value.values.keys.sorted() {
            try CredentialProtocol.scope(key); try CredentialProtocol.value(value.values[key]!)
            text(key); text(value.values[key]!)
        }
        try requireCredential(bytes.count <= CredentialProtocol.maxSnapshotBytes)
        return Data(bytes)
    }
    static func decode(_ data: Data) throws -> CredentialSnapshot {
        do {
            try requireCredential(data.count <= CredentialProtocol.maxSnapshotBytes && data.count >= magic.count)
            let b = Array(data); var offset = magic.count
            try requireCredential(Array(b.prefix(magic.count)) == magic)
            func number(_ width: Int) throws -> UInt64 {
                try requireCredential(width <= b.count - offset)
                var v: UInt64 = 0
                for _ in 0..<width { v = (v << 8) | UInt64(b[offset]); offset += 1 }
                return v
            }
            func text(_ maximum: Int) throws -> String {
                let size = try number(4)
                try requireCredential(size > 0 && size <= UInt64(maximum) && size <= UInt64(b.count - offset))
                guard let value = String(bytes: b[offset..<(offset + Int(size))], encoding: .utf8) else { throw CredentialFailure() }
                offset += Int(size); return value
            }
            let app = try text(255), install = try text(36), revision = try number(8), count = try number(4)
            try CredentialProtocol.application(app); try CredentialProtocol.identifier(install)
            try requireCredential(revision <= UInt64(Int64.max) && count <= UInt64(CredentialProtocol.maxScopes))
            var values: [String: String] = [:]
            for _ in 0..<Int(count) {
                let key = try text(512), value = try text(CredentialProtocol.maxValueBytes)
                try CredentialProtocol.scope(key); try CredentialProtocol.value(value)
                try requireCredential(values[key] == nil); values[key] = value
            }
            try requireCredential(offset == b.count)
            return CredentialSnapshot(applicationID: app, installationID: install, revision: Int64(revision), values: values)
        } catch { throw CredentialFailure("credential_corrupt") }
    }
}

/// Host-authoritative exact bindings. Disabled and empty by default.
struct CredentialPolicy: Sendable {
    let applicationID: String
    let enabled: Bool
    private let approvedScopes: Set<String>
    init(applicationID: String, enabled: Bool = false, approvedScopes: Set<String> = []) throws {
        try CredentialProtocol.application(applicationID)
        for scope in approvedScopes { try CredentialProtocol.bind(scope, applicationID) }
        self.applicationID = applicationID; self.enabled = enabled; self.approvedScopes = approvedScopes
    }
    func authorize(_ scope: String) throws {
        try requireCredential(enabled && !approvedScopes.isEmpty, "credential_disabled")
        try CredentialProtocol.bind(scope, applicationID)
        try requireCredential(approvedScopes.contains(scope), "credential_binding_mismatch")
    }
}
