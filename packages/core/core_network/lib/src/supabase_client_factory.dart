import 'package:core_utils/core_utils.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Factory for creating the Supabase client instance.
///
/// One Supabase project serves all clubs.
/// The client is initialized once per app session.
class SupabaseClientFactory {
  SupabaseClientFactory._();

  static bool _initialized = false;
  static String? _initializedUrl;
  static String? _initializedAnonKey;

  /// Maximum retry attempts for initialization.
  static const _maxRetries = 3;

  /// Base delay for exponential backoff.
  static const _baseDelay = Duration(seconds: 1);

  static bool get isInitialized => _initialized;

  /// Initialize Supabase with the given URL and anon key.
  ///
  /// Retries up to [_maxRetries] times with exponential backoff
  /// (1s, 2s, 4s) on transient failures. Should be called once
  /// during app bootstrap.
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    if (_initialized) {
      final sameConfig =
          _initializedUrl == supabaseUrl &&
          _initializedAnonKey == supabaseAnonKey;
      if (!sameConfig) {
        throw StateError(
          'SupabaseClientFactory was already initialized with a different configuration.',
        );
      }
      return;
    }

    Object? lastError;
    for (var attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );

        _initializedUrl = supabaseUrl;
        _initializedAnonKey = supabaseAnonKey;
        _initialized = true;

        if (attempt > 1) {
          AfriLogger.info(
            'SupabaseClientFactory',
            'Supabase initialized on attempt $attempt.',
          );
        }
        return;
      } catch (error) {
        lastError = error;
        if (attempt < _maxRetries) {
          final delay = _baseDelay * (1 << (attempt - 1));
          AfriLogger.warn(
            'SupabaseClientFactory',
            'Init attempt $attempt/$_maxRetries failed: $error. '
            'Retrying in ${delay.inSeconds}s…',
          );
          await Future<void>.delayed(delay);
        }
      }
    }

    AfriLogger.error(
      'SupabaseClientFactory',
      'All $_maxRetries init attempts failed.',
      lastError,
    );
    throw StateError(
      'Supabase initialization failed after $_maxRetries attempts: $lastError',
    );
  }

  /// Get the Supabase client singleton.
  static SupabaseClient get client => Supabase.instance.client;

  /// Get the current authenticated user.
  static User? get currentUser => client.auth.currentUser;

  /// Get the auth state stream.
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;
}
