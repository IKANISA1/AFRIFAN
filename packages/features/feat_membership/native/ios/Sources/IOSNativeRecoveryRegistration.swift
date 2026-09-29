#if os(iOS)
import Foundation
import UIKit
@preconcurrency import Flutter

/// One registration owner per engine. Launch may occur before the application is
/// active or protected data is available; only those events retry host setup.
/// There is no checkout, credential, dialer or automatic payment retry here.
@MainActor
final class IOSNativeRecoveryRegistration {
    private let messenger: FlutterBinaryMessenger
    private var host: IOSNativeRecoveryHost?
    private var observers: [NSObjectProtocol] = []
    private var disposed = false

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
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
        guard !disposed, host == nil,
              UIApplication.shared.applicationState == .active,
              UIApplication.shared.isProtectedDataAvailable else { return }
        // Failure leaves the channel unavailable. It never substitutes plaintext,
        // deletes recovery state or creates a new checkout key.
        host = try? IOSNativeRecoveryHost.install(messenger: messenger, enabled: true)
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
