/// Compile-time gate for Firebase-backed observability SDKs.
///
/// Keep this disabled by default while the production Firebase project is not
/// verified. Enable with `--dart-define=ENABLE_FIREBASE_OBSERVABILITY=true`
/// only after Firebase Installations, Crashlytics, Analytics, and Performance
/// use a valid production project.
class FirebaseObservabilityConfig {
  const FirebaseObservabilityConfig._();

  static const bool enabled = bool.fromEnvironment(
    'ENABLE_FIREBASE_OBSERVABILITY',
  );

  static const bool appCheckEnabled = bool.fromEnvironment(
    'ENABLE_FIREBASE_APP_CHECK',
  );
}
