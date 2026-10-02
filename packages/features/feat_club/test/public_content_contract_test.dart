import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final resolved in [null, '/club/team/player-1', 'error']) {
    testWidgets('public content resolves natively: $resolved', (tester) async {
      final redirect = ClubModule().routes.whereType<GoRoute>().firstWhere(
        (r) => r.path == 'open-web',
      );
      final router = GoRouter(
        initialLocation: '/club/open-web?path=%2Fsquad%2Fplayer%2Fmissing',
        routes: [
          GoRoute(
            path: '/club',
            builder: (_, __) => const Text('Club'),
            routes: [redirect],
          ),
          GoRoute(
            path: '/club/team',
            builder: (_, __) => const Text('Native squad'),
          ),
          GoRoute(
            path: '/club/team/:id',
            builder: (_, __) => const Text('Native player'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clubPublicLinkProvider.overrideWith((_, __) async {
              if (resolved == 'error') throw StateError('unavailable');
              return resolved;
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          resolved == null || resolved == 'error'
              ? 'Native squad'
              : 'Native player',
        ),
        findsOneWidget,
      );
      expect(find.text('Open website'), findsNothing);
    });
  }

  test('publisher identity strips tracking and rejects unsafe links', () {
    ClubNewsItem article(String url) => ClubNewsItem.fromJson({
      'id': 'one',
      'title': 'Club update',
      'source_url': url,
    });
    expect(
      article(
        'https://publisher.example/news/story?utm_source=app&story=1#top',
      ).sourceUrl,
      'https://publisher.example/news/story?story=1',
    );
    for (final url in [
      'javascript:alert(1)',
      'https://secret@publisher.example/story',
      'https://publisher.example/',
      'https://x.com/clubprofile',
      'https://facebook.com/clubprofile',
    ]) {
      expect(article(url).sourceUrl, isNull);
    }
  });
  test('news photographs require rights and provenance together', () {
    final row = {'id': 'one', 'image_url': 'https://media.example/story.jpg'};
    expect(ClubNewsItem.fromJson(row).imageUrl, isNull);
    expect(
      ClubNewsItem.fromJson({...row, 'image_rights_approved': true}).imageUrl,
      isNull,
    );
    expect(
      ClubNewsItem.fromJson({
        ...row,
        'image_rights_approved': true,
        'image_provenance_id': 'approved-story',
      }).imageUrl,
      row['image_url'],
    );
  });
  test(
    'source links cannot traverse routes or carry an external destination',
    () {
      expect(validPublicEntityPath('/squad/player/club-player'), isTrue);
      for (final path in [
        '/news/../settings',
        '/news/%2fsettings',
        '//attacker.example/news/one',
        '/news/one?redirect=evil',
      ]) {
        expect(validPublicEntityPath(path), isFalse);
      }
      expect(validNativeEntityPath('/club/team/player-1'), isTrue);
      expect(validNativeEntityPath('/wallet/transfer'), isFalse);
    },
  );
}
