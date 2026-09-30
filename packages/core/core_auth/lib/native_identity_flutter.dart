/// Separate Flutter binding. The portable identity controller has no dependency
/// on payment recovery storage, app registration or automatic authentication.
library;

import 'package:flutter/services.dart';

import 'src/native_identity/platform_store.dart';

export 'native_identity.dart';
export 'src/native_identity/platform_store.dart';

final class FlutterNativeCredentialChannel implements NativeCredentialChannel {
  const FlutterNativeCredentialChannel();
  static const channelName = 'africlub/native-identity-credentials/v1';
  static const MethodChannel _channel = MethodChannel(channelName);
  @override
  Future<Object?> invoke(String method, Map<String, Object?> arguments) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException {
      throw const NativeCredentialChannelFailure('credential_unavailable');
    } on MissingPluginException {
      throw const NativeCredentialChannelFailure('credential_unavailable');
    }
  }
}
