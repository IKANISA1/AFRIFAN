import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase client provider — the SINGLE SOURCE OF TRUTH.
///
/// All feature packages MUST use this provider instead of calling
/// `Supabase.instance.client` directly. This ensures:
///   1. Testability — can be overridden in tests
///   2. Consistency — one access point for the client
///   3. Compliance — §5.3 prohibits direct Supabase.instance access in features
final supabaseClientProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

/// Current authenticated user ID — convenience provider.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(supabaseClientProvider).auth.currentUser?.id;
});
