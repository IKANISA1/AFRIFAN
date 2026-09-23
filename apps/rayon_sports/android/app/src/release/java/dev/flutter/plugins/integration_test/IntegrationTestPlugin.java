package dev.flutter.plugins.integration_test;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Release-only no-op stub so production APK builds do not fail when Flutter's
 * generated plugin registrant includes the test plugin.
 */
public final class IntegrationTestPlugin implements FlutterPlugin {
  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {}

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {}
}
