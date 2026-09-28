import 'package:core_router/core_router.dart';
import 'package:feat_fan_clubs/feat_fan_clubs.dart';
import 'package:feat_fan_clubs/src/screens/fan_clubs_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('retired detail links open the published directory', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/fan-clubs/group-2',
      routes: FanClubsModule().routes,
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fanClubsLoaderProvider.overrideWithValue(
            () async => [
              {
                'id': 'group-1',
                'name': 'Northern supporters',
                'region': 'North',
                'member_count': 12,
              },
              {
                'id': 'group-2',
                'name': 'City supporters',
                'region': 'City',
                'member_count': 42,
              },
            ],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/fan-clubs');
    expect(find.text('City supporters'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('City supporters')).dy,
      lessThan(tester.getTopLeft(find.text('Northern supporters')).dy),
    );
    expect(find.text('Copy link'), findsNothing);
  });

  test(
    'community root renders directly and cannot redirect back to Predict',
    () {
      final module = FanClubsModule();
      final root = module.routes.whereType<GoRoute>().single;
      expect(root.redirect, isNull);
      expect(root.pageBuilder, isNotNull);
      final decision = module.routePresentationDecisions.singleWhere(
        (entry) => entry.path == '/fan-clubs',
      );
      expect(decision.presentation, RoutePresentation.fullHeightSheet);
      expect(decision.targetPath, isNull);
    },
  );
}
