import 'package:core_network/core_network.dart';

/// Testable boundary around platform notification permission and token work.
///
/// Settings UI depends on this contract instead of static Firebase calls so
/// denied, unavailable, recovery, and success states can be exercised without
/// contacting a device service.
abstract interface class NotificationPermissionGateway {
  Future<PushPermissionStatus> getPermissionStatus();

  Future<PushPermissionStatus> requestPermission();

  Future<void> syncToken();

  Future<void> unregisterCurrentDevice();
}

class FirebaseNotificationPermissionGateway
    implements NotificationPermissionGateway {
  const FirebaseNotificationPermissionGateway();

  @override
  Future<PushPermissionStatus> getPermissionStatus() =>
      PushNotificationService.getPermissionStatus();

  @override
  Future<PushPermissionStatus> requestPermission() =>
      PushNotificationService.requestPermission();

  @override
  Future<void> syncToken() => PushNotificationService.syncToken();

  @override
  Future<void> unregisterCurrentDevice() =>
      PushNotificationService.unregisterCurrentDevice();
}
