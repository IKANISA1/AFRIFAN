import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:feat_membership/src/providers/membership_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'membership reads paid current cards and confirmed contribution history in the active club',
    () async {
      const userId = '99660000-0000-4000-8000-000000000001';
      final requests = <Uri>[];
      String part(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final token =
          '${part({'alg': 'none'})}.${part({'sub': userId, 'exp': 4070908800})}.synthetic';
      final client = SupabaseClient(
        'https://membership.invalid',
        'synthetic',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          requests.add(request.url);
          final path = request.url.path;
          final Object data;
          if (path == '/auth/v1/token') {
            data = {
              'access_token': token,
              'token_type': 'bearer',
              'refresh_token': 'synthetic',
              'expires_in': 3600,
              'user': {
                'id': userId,
                'aud': 'authenticated',
                'created_at': '2026-09-20T00:00:00Z',
                'app_metadata': {'club_id': 24},
                'user_metadata': {},
              },
            };
          } else if (path.endsWith('/membership_tiers')) {
            data = [
              {
                'id': 'paid',
                'tier': 'gold',
                'club_id': 24,
                'annual_price': 1000,
                'benefits': ['Club access'],
              },
            ];
          } else if (path.endsWith('/fan_memberships')) {
            data = {
              'user_id': userId,
              'club_id': 24,
              'tier': 'gold',
              'payment_status': 'verified',
              'status': 'active',
              'expires_at': '2099-01-01T00:00:00Z',
            };
          } else if (path.endsWith('/initiative_contributions')) {
            data = [
              {
                'initiative_id': 'initiative',
                'amount': 500,
                'status': 'confirmed',
                'created_at': '2026-09-20T00:00:00Z',
              },
            ];
          } else if (path.endsWith('/initiatives')) {
            data = [
              {'id': 'initiative', 'title': 'Club project'},
            ];
          } else {
            throw StateError('Unexpected request: $path');
          }
          return http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'fixture@example.test',
        password: 'synthetic',
      );
      ConnectivityService.setOnlineForTest(true);
      final container = ProviderContainer(
        overrides: [supabaseClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);
      final snapshot = await container.read(membershipProvider.future);
      expect(snapshot.membership?['tier'], 'gold');
      expect(snapshot.contributions.single.label, 'Club project');
      expect(snapshot.contributions.single.status, 'confirmed');
      final card = requests
          .singleWhere((uri) => uri.path.endsWith('/fan_memberships'))
          .queryParameters;
      expect(card['club_id'], 'eq.24');
      expect(card['user_id'], 'eq.$userId');
      expect(card['payment_status'], 'eq.verified');
      expect(card['status'], 'eq.active');
      expect(card['tier'], 'neq.fan');
      expect(card['expires_at'], startsWith('gt.'));
      final history = requests
          .singleWhere((uri) => uri.path.endsWith('/initiative_contributions'))
          .queryParameters;
      expect(history['club_id'], 'eq.24');
      expect(history['status'], 'eq.confirmed');
      expect(history.containsKey('payment_status'), isFalse);
      expect(history.containsKey('expires_at'), isFalse);
    },
  );
}
