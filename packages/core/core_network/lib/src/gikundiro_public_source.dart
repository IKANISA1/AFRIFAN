import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const gikundiroPublicSourceConfigured =
    String.fromEnvironment('CLUB_ID') == '24' &&
    String.fromEnvironment('GIKUNDIRO_PUBLIC_SUPABASE_URL') != '' &&
    String.fromEnvironment('GIKUNDIRO_PUBLIC_SUPABASE_ANON_KEY') != '';

/// Anonymous public content only. Member identity and writes remain in the
/// AFRICLUB project and are never sent to this client.
final gikundiroPublicClientProvider = Provider<SupabaseClient?>((ref) {
  if (!gikundiroPublicSourceConfigured) return null;
  const url = String.fromEnvironment('GIKUNDIRO_PUBLIC_SUPABASE_URL');
  const key = String.fromEnvironment('GIKUNDIRO_PUBLIC_SUPABASE_ANON_KEY');
  final uri = Uri.tryParse(url);
  if (uri?.scheme != 'https' ||
      uri?.host != 'loxcwbfukbqziuxgkfcm.supabase.co') {
    throw StateError('Gikundiro public source is misconfigured.');
  }
  final source = SupabaseClient(
    url,
    key,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  ref.onDispose(source.dispose);
  return source;
});

Future<String> gikundiroPublicClubId(SupabaseClient source) async {
  final row = await source
      .from('clubs')
      .select('id')
      .eq('slug', 'rayon-sports')
      .single();
  final id = row['id']?.toString() ?? '';
  if (id.isEmpty) throw StateError('Rayon Sports source is unavailable.');
  return id;
}
