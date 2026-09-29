/// Optional iOS-only counterpart to the Android recovery channel. Not app-registered.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'src/native_checkout/platform_recovery_store.dart';
export 'src/native_checkout/platform_recovery_store.dart';

final class IOSCheckoutRecoveryChannel implements RecoveryPlatformChannel {
  const IOSCheckoutRecoveryChannel({
    this.enabled = false,
    this.channel = const MethodChannel('africlub/native-checkout-recovery/v1'),
  });
  final bool enabled;
  final MethodChannel channel;
  @override
  Future<Object?> invoke(String method, Map<String, Object?> arguments) async {
    if (!enabled || kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw const RecoveryPlatformFailure('recovery_disabled');
    }
    try {
      return await channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      throw const RecoveryPlatformFailure('recovery_channel_unavailable');
    } on PlatformException catch (error) {
      throw RecoveryPlatformFailure(error.code);
    }
  }
}
