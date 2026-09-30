#if os(iOS)
import Foundation
import UIKit
import LocalAuthentication
@preconcurrency import Flutter

private final class IOSCredentialReply: @unchecked Sendable {
    let value: Any
    init(_ value: Any) { self.value = value }
}
private final class IOSCredentialCall: @unchecked Sendable {
    // StandardMessageCodec values are copied to this immutable string/null map before dispatch.
    let method: String
    let arguments: [String: Any]
    let result: FlutterResult
    init(_ method: String, _ arguments: [String: Any], _ result: @escaping FlutterResult) {
        self.method = method; self.arguments = arguments; self.result = result
    }
    func complete(_ value: Any) {
        // Flutter results are delivered on the main thread. No stored value is logged.
        let reply = IOSCredentialReply(value)
        DispatchQueue.main.async { self.result(reply.value) }
    }
}

/// Opt-in per-engine host, not automatic Flutter plugin registration. Keep a strong
/// owner until that engine is disposed, then call dispose(). No timers clear leases.
/// No caller-selected paths/groups and no automatic authentication.
@MainActor
final class IOSNativeCredentialHost {
    private let channel: FlutterMethodChannel
    private let dispatcher: NativeCredentialDispatcher
    private let gate: CredentialHostGate
    private let queue = DispatchQueue(label: "com.africlub.native-identity-credentials.v1", qos: .userInitiated)
    private var observers: [NSObjectProtocol] = []
    private var disposed = false

    static func install(messenger: FlutterBinaryMessenger, enabled: Bool = false, approvedScopes: Set<String> = []) throws -> IOSNativeCredentialHost? {
        guard enabled else { return nil }
        return try IOSNativeCredentialHost(messenger: messenger, approvedScopes: approvedScopes)
    }
    private init(messenger: FlutterBinaryMessenger, approvedScopes: Set<String>) throws {
        let application = UIApplication.shared
        try requireCredential(application.isProtectedDataAvailable && application.applicationState == .active, "credential_device_locked")
        guard let bundle = Bundle.main.bundleIdentifier else { throw CredentialFailure("credential_unavailable") }
        let policy = try CredentialPolicy(applicationID: bundle, enabled: true, approvedScopes: approvedScopes)
        try requireCredential(!approvedScopes.isEmpty, "credential_disabled")
        let auth = LAContext()
        try requireCredential(auth.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil), "credential_device_locked")
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var root = base.appendingPathComponent("AFRICLUBIdentityCredentials-v1", isDirectory: true)
        if !fm.fileExists(atPath: root.path) {
            try fm.createDirectory(at: root, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.complete])
        }
        let canonical = root.resolvingSymlinksInPath().standardizedFileURL
        // The application-support base may be a platform alias; the final private
        // directory must not be a symlink. The portable checker also verifies mode/UID.
        let attrs = try fm.attributesOfItem(atPath: root.path)
        try requireCredential(attrs[.type] as? FileAttributeType == .typeDirectory, "credential_directory_unavailable")
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        let store = try NativeCredentialStore(root: canonical.path, applicationID: bundle, storage: KeychainCredentialBlob(bundleID: bundle))
        let gate = CredentialHostGate(); gate.update(foreground: true, protectedData: true); self.gate = gate
        dispatcher = try NativeCredentialDispatcher(store: store, policy: policy, usable: { gate.usable() })
        channel = FlutterMethodChannel(name: CredentialProtocol.channel, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(FlutterError(code: "credential_channel_unavailable", message: nil, details: nil)); return }
            MainActor.assumeIsolated { self.receive(call, result: result) }
        }
        for name in [UIApplication.didBecomeActiveNotification, UIApplication.willResignActiveNotification,
                     UIApplication.protectedDataDidBecomeAvailableNotification, UIApplication.protectedDataWillBecomeUnavailableNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak gate] note in
                // Notifications are delivered on main; use their declared transition
                // immediately rather than optimistically querying an old active value.
                let inactive = note.name == UIApplication.willResignActiveNotification
                let locked = note.name == UIApplication.protectedDataWillBecomeUnavailableNotification
                MainActor.assumeIsolated {
                    gate?.update(foreground: !inactive && UIApplication.shared.applicationState == .active,
                                 protectedData: !locked && UIApplication.shared.isProtectedDataAvailable)
                }
            })
        }
    }
    private func receive(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard !disposed, let map = call.arguments as? [String: Any],
              CredentialProtocol.requestShape(call.method, map), gate.enqueue(call.method) else {
            result(FlutterError(code: "credential_channel_unavailable", message: nil, details: nil)); return
        }
        let work = IOSCredentialCall(call.method, map, result), dispatch = dispatcher, gate = gate
        queue.async {
            defer { gate.finished(work.method) }
            do { work.complete(try dispatch.invoke(work.method, arguments: work.arguments)) }
            catch let error as CredentialFailure { work.complete(FlutterError(code: error.code, message: nil, details: nil)) }
            catch { work.complete(FlutterError(code: "credential_unavailable", message: nil, details: nil)) }
        }
    }
    func dispose() {
        guard !disposed else { return }; disposed = true; gate.stop(); channel.setMethodCallHandler(nil)
        for observer in observers { NotificationCenter.default.removeObserver(observer) }; observers.removeAll()
        let dispatch = dispatcher
        queue.async { try? dispatch.dispose() }
    }
}
#endif
