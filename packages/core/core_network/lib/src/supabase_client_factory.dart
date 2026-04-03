import 'package:supabase_flutter/supabase_flutter.dart';

/// Factory for creating the Supabase client instance.
///
/// One Supabase project serves all clubs.
/// The client is initialized once per app session.
class SupabaseClientFactory {
  SupabaseClientFactory._();

  static bool _initialized = false;

  /// Initialize Supabase with the given URL and anon key.
  /// Should be called once during app bootstrap.
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    if (_initialized) return;

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    _initialized = true;
  }

  /// Get the Supabase client singleton.
  static SupabaseClient get client => Supabase.instance.client;

  /// Get the current authenticated user.
  static User? get currentUser => client.auth.currentUser;

  /// Get the auth state stream.
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;
}
