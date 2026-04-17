/// Callback interface for deferred feature initialization.
///
/// Feature packages that need initialization during startup can
/// provide implementations of this interface. This allows [core_app]
/// to orchestrate startup without depending on feature packages directly.
class DeferredFeatureInitializer {
  const DeferredFeatureInitializer({
    this.onPurgeLegacyCache,
    this.onRegisterAuthLifecycleObservers,
    this.onInitializeSmsAutoread,
  });

  /// Purge legacy caches from optional feature packages.
  final Future<void> Function()? onPurgeLegacyCache;

  /// Register auth lifecycle observers for optional feature packages.
  final Future<void> Function()? onRegisterAuthLifecycleObservers;

  /// Initialize SMS autoread service.
  final Future<void> Function()? onInitializeSmsAutoread;
}
