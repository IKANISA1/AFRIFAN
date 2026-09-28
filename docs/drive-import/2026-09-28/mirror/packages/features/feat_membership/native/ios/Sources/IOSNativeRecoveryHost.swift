#if os(iOS)
import Foundation
import UIKit
@preconcurrency import Flutter

/// Mutable state is synchronized. The dispatcher additionally serializes every
/// backend operation through the portable process registry and OS lock.
private final class IOSRecoveryGate: @unchecked Sendable {
    private let mutex = NSLock()
    private var foreground = false
    private var protectedData = false
    private var stopped = false
    private var pending = 0
    func update(foreground: Bool, protectedData: Bool) {
        mutex.lock(); defer { mutex.unlock() }
        self.foreground = foreground; self.protectedData = protectedData
    }
    func usable() -> Bool { mutex.lock(); defer { mutex.unlock() }; return !stopped && foreground && protectedData }
    func enqueue() -> Bool {
        mutex.lock(); defer { mutex.unlock() }
        guard !stopped && pending < 32 else { return false }; pending += 1; return true
    }
    func finished() { mutex.lock(); pending -= 1; mutex.unlock() }
    func stop() { mutex.lock(); stopped = true; mutex.unlock() }
}
private final class IOSRecoveryReply: @unchecked Sendable {
    let value: Any
    init(_ value: Any) { self.value = value }
}
private final class IOSRecoveryCall: @unchecked Sendable {
    // StandardMessageCodec values are copied to this immutable string/null map before dispatch.
    let method: String
    let arguments: [String: Any]
    let result: FlutterResult
    init(_ method: String, _ arguments: [String: Any], _ result: @escaping FlutterResult) {
        self.method = method; self.arguments = arguments; self.result = result
    }
    func complete(_ value: Any) {
        // Flutter results are delivered on the main thread. No stored value is logged.
        let reply = IOSRecoveryReply(value)
        DispatchQueue.main.async { self.result(reply.value) }
    }
}

/// Opt-in per-engine host, not automatic Flutter plugin registration. Keep a strong
/// owner until that engine is disposed, then call dispose(). No timers clear leases.
/// No app project, Podfile, SwiftPM package, entitlement or minimum version is changed.
@MainActor
final class IOSNativeRecoveryHost {
    private let channel: FlutterMethodChannel
    private let dispatcher: NativeRecoveryDispatcher
    private let gate: IOSRecoveryGate
    private let queue = DispatchQueue(label: "com.africlub.native-checkout-recovery.v1", qos: .userInitiated)
    private var observers: [NSObjectProtocol] = []
    private var disposed = false

    static func install(messenger: FlutterBinaryMessenger, enabled: Bool = false) throws -> IOSNativeRecoveryHost? {
        guard enabled else { return nil }
        return try IOSNativeRecoveryHost(messenger: messenger)
    }
    private init(messenger: FlutterBinaryMessenger) throws {
        let application = UIApplication.shared
        try requireRecovery(application.isProtectedDataAvailable && application.applicationState == .active, "recovery_device_locked")
        guard let bundle = Bundle.main.bundleIdentifier else { throw RecoveryFailure("recovery_unavailable") }
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var root = base.appendingPathComponent("AFRICLUBRecovery-v1", isDirectory: true)
        if !fm.fileExists(atPath: root.path) {
            try fm.createDirectory(at: root, withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700, .protectionKey: FileProtectionType.complete])
        }
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try root.setResourceValues(values)
        let canonical = root.resolvingSymlinksInPath().standardizedFileURL
        // The application-support base may be a platform alias; the final private
        // directory must not be a symlink. The portable checker also verifies mode/UID.
        let attrs = try fm.attributesOfItem(atPath: root.path)
        try requireRecovery(attrs[.type] as? FileAttributeType == .typeDirectory, "recovery_directory_unavailable")
        try fm.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: root.path)
        let store = try NativeRecoveryStore(root: canonical.path, applicationID: bundle, storage: KeychainRecoveryBlob(bundleID: bundle))
        let gate = IOSRecoveryGate(); gate.update(foreground: true, protectedData: true); self.gate = gate
        dispatcher = try NativeRecoveryDispatcher(store: store, usable: { gate.usable() })
        channel = FlutterMethodChannel(name: RecoveryProtocol.channel, binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self else { result(FlutterError(code: "recovery_channel_unavailable", message: nil, details: nil)); return }
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
              map.values.allSatisfy({ $0 is String || $0 is NSNull }), gate.enqueue() else {
            result(FlutterError(code: "recovery_channel_unavailable", message: nil, details: nil)); return
        }
        let work = IOSRecoveryCall(call.method, map, result), dispatch = dispatcher, gate = gate
        queue.async {
            defer { gate.finished() }
            do { work.complete(try dispatch.invoke(work.method, arguments: work.arguments)) }
            catch let error as RecoveryFailure { work.complete(FlutterError(code: error.code, message: nil, details: nil)) }
            catch { work.complete(FlutterError(code: "recovery_unavailable", message: nil, details: nil)) }
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
