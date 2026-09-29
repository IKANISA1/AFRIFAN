import Foundation

/// Errors are intentionally finite: never return Keychain data or OS error text to Dart.
struct RecoveryFailure: Error, Equatable, Sendable {
    let code: String
    init(_ code: String = "recovery_unavailable") { self.code = code }
}
func requireRecovery(_ condition: Bool, _ code: String = "recovery_invalid_request") throws {
    if !condition { throw RecoveryFailure(code) }
}
enum RecoveryProtocol {
    static let maxScopes = 64
    static let maxValueBytes = 2048
    static let maxSnapshotBytes = 160_000
    static let channel = "africlub/native-checkout-recovery/v1"
    static func matches(_ value: String, _ pattern: String) -> Bool {
        guard let r = value.range(of: pattern, options: .regularExpression) else { return false }
        return r == value.startIndex..<value.endIndex
    }
    static func identifier(_ value: String) throws {
        try requireRecovery(matches(value, "[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"))
    }
    static func scope(_ value: String) throws {
        try requireRecovery(matches(value, "africlub-(membership|payment-handoff)-v1:[1-9][0-9]{0,14}:[0-9a-f-]{36}"), "recovery_invalid_scope")
        do { try identifier(String(value.suffix(36))) }
        catch { throw RecoveryFailure("recovery_invalid_scope") }
    }
    static func value(_ value: String) throws {
        try requireRecovery(!value.isEmpty && value.utf8.count <= maxValueBytes, "recovery_invalid_value")
    }
    static func application(_ value: String) throws {
        try requireRecovery(value.utf8.count <= 255 && matches(value, "[A-Za-z0-9][A-Za-z0-9.-]{2,254}"))
    }
    static func newID() -> String { UUID().uuidString.lowercased() }
}

struct RecoverySnapshot: Equatable, Sendable {
    let applicationID: String
    let installationID: String
    let revision: Int64
    let values: [String: String]
}

/// A bounded binary format avoids duplicate JSON keys and platform number coercion.
/// This is the iOS internal format, NOT an Android ciphertext migration format.
enum RecoverySnapshotCodec {
    private static let magic: [UInt8] = [65, 70, 82, 73, 0, 0, 0, 1]
    static func encode(_ value: RecoverySnapshot) throws -> Data {
        try RecoveryProtocol.application(value.applicationID)
        try RecoveryProtocol.identifier(value.installationID)
        try requireRecovery(value.revision >= 0 && value.values.count <= RecoveryProtocol.maxScopes)
        var bytes = magic
        func number(_ value: UInt64, _ width: Int) {
            for position in (0..<width).reversed() { bytes.append(UInt8(truncatingIfNeeded: value >> (position * 8))) }
        }
        func text(_ value: String) { let b = Array(value.utf8); number(UInt64(b.count), 4); bytes.append(contentsOf: b) }
        text(value.applicationID); text(value.installationID)
        number(UInt64(value.revision), 8); number(UInt64(value.values.count), 4)
        for key in value.values.keys.sorted() {
            try RecoveryProtocol.scope(key); try RecoveryProtocol.value(value.values[key]!)
            text(key); text(value.values[key]!)
        }
        try requireRecovery(bytes.count <= RecoveryProtocol.maxSnapshotBytes)
        return Data(bytes)
    }
    static func decode(_ data: Data) throws -> RecoverySnapshot {
        do {
            try requireRecovery(data.count <= RecoveryProtocol.maxSnapshotBytes && data.count >= magic.count)
            let b = Array(data); var offset = magic.count
            try requireRecovery(Array(b.prefix(magic.count)) == magic)
            func number(_ width: Int) throws -> UInt64 {
                try requireRecovery(width <= b.count - offset)
                var v: UInt64 = 0
                for _ in 0..<width { v = (v << 8) | UInt64(b[offset]); offset += 1 }
                return v
            }
            func text(_ maximum: Int) throws -> String {
                let size = try number(4)
                try requireRecovery(size > 0 && size <= UInt64(maximum) && size <= UInt64(b.count - offset))
                guard let value = String(bytes: b[offset..<(offset + Int(size))], encoding: .utf8) else { throw RecoveryFailure() }
                offset += Int(size); return value
            }
            let app = try text(255), install = try text(36), revision = try number(8), count = try number(4)
            try RecoveryProtocol.application(app); try RecoveryProtocol.identifier(install)
            try requireRecovery(revision <= UInt64(Int64.max) && count <= UInt64(RecoveryProtocol.maxScopes))
            var values: [String: String] = [:]
            for _ in 0..<Int(count) {
                let key = try text(128), value = try text(RecoveryProtocol.maxValueBytes)
                try RecoveryProtocol.scope(key); try RecoveryProtocol.value(value)
                try requireRecovery(values[key] == nil); values[key] = value
            }
            try requireRecovery(offset == b.count)
            return RecoverySnapshot(applicationID: app, installationID: install, revision: Int64(revision), values: values)
        } catch { throw RecoveryFailure("recovery_corrupt") }
    }
}
