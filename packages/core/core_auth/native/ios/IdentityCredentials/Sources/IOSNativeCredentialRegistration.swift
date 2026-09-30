#if os(iOS)
import Foundation
import UIKit
@preconcurrency import Flutter

/// One registration owner per engine. Launch may occur before the application is
/// active or protected data is available; only those events retry host setup.
/// There is no checkout, credential, dialer or automatic payment retry here.
@MainActor
final class IOSNativeCredentialRegistration {
    private let messenger: FlutterBinaryMessenger
    private let enabled: Bool
    private let approvedScopes: Set<String>
    private var host: IOSNativeCredentialHost?
    private var observers: [NSObjectProtocol] = []
    private var disposed = false

    init(messenger: FlutterBinaryMessenger, enabled: Bool = false, approvedScopes: Set<String> = []) {
        self.messenger = messenger; self.enabled = enabled; self.approvedScopes = approvedScopes
        for name in [UIApplication.didBecomeActiveNotification,
                     UIApplication.protectedDataDidBecomeAvailableNotification] {
            observers.append(NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.installIfUsable() }
            })
        }
        installIfUsable()
    }

    private func installIfUsable() {
        guard enabled, !approvedScopes.isEmpty, !disposed, host == nil,
              UIApplication.shared.applicationState == .active,
              UIApplication.shared.isProtectedDataAvailable else { return }
        // Failure leaves the channel unavailable. It never substitutes plaintext,
        // deletes credential state or creates a new checkout key.
        host = try? IOSNativeCredentialHost.install(messenger: messenger, enabled: enabled, approvedScopes: approvedScopes)
    }

    func dispose() {
        guard !disposed else { return }
        disposed = true
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
        observers.removeAll()
        host?.dispose()
        host = nil
    }
}
#endif
