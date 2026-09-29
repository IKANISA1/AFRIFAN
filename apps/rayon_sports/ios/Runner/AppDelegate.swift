import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var nativeRecoveryRegistration: IOSNativeRecoveryRegistration?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  nonisolated func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // The Objective-C delegate contract has no actor annotation. Assert the
    // UIKit main-actor boundary before registering or touching protected state.
    MainActor.assumeIsolated {
      GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
      nativeRecoveryRegistration?.dispose()
      if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AFRICLUBNativeCheckoutRecovery") {
        nativeRecoveryRegistration = IOSNativeRecoveryRegistration(messenger: registrar.messenger())
      }
    }
  }
}
