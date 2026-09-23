import 'dart:convert';

import 'package:club_data/club_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
    'project artwork is scoped to published app media and exact project routes',
    () async {
      Uri? requested;
      final client = SupabaseClient(
        'https://club.example',
        'public-key',
        httpClient: MockClient((request) async {
          requested = request.url;
          return http.Response(
            jsonEncode([
              {
                'route': '/contribute/group/project-1',
                'image_url': 'https://media.example/project.jpg',
              },
              {
                'route': '/club/projects/project-1',
                'image_url': 'https://media.example/older.jpg',
              },
              {
                'route': '/contribute/group/unrelated',
                'image_url': 'https://media.example/unrelated.jpg',
              },
              {
                'route': '/contribute/group/project-2',
                'image_url': 'https://private:secret@media.example/private.jpg',
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      expect(
        await loadPublishedProjectImages(
          client,
          clubId: 24,
          groupIds: ['project-1', 'project-2'],
        ),
        {'project-1': 'https://media.example/project.jpg'},
      );
      expect(requested?.path, '/rest/v1/home_banners');
      expect(requested?.queryParameters['club_id'], 'eq.24');
      expect(requested?.queryParameters['is_active'], 'eq.true');
      expect(requested?.queryParameters['distribution'], allOf(contains('app'), contains('both')));
      expect(requested?.queryParameters['route'], contains('/contribute/group/project-1'));
    },
  );

  test('unavailable optional artwork does not block project totals', () async {
    final client = SupabaseClient(
      'https://club.example',
      'public-key',
      httpClient: MockClient((request) async => http.Response('unavailable', 503, request: request)),
    );
    addTearDown(client.dispose);
    expect(
      await loadPublishedProjectImages(
        client,
        clubId: 24,
        groupIds: ['project-1'],
      ),
      isEmpty,
    );
  });
}
