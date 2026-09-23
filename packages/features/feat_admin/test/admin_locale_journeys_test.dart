import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/feature_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => ConnectivityService.setOnlineForTest(true));
  tearDown(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('English Admin journey uses the English catalog', (tester) async {
    await _pumpFeatureManager(tester, const Locale('en'));

    expect(find.text('Feature manager'), findsOneWidget);
    expect(find.text('Registered'), findsOneWidget);
    expect(find.text('Enabled'), findsWidgets);
  });

  testWidgets(
    'Stored-locale fallback English Admin journey uses the English catalog',
    (tester) async {
      await _pumpFeatureManager(tester, const Locale('zz'));

      expect(find.text('Feature manager'), findsOneWidget);
      expect(find.text('Registered'), findsOneWidget);
      expect(find.text('Enabled'), findsWidgets);
    },
  );
}

Future<void> _pumpFeatureManager(
  WidgetTester tester,
  Locale appCopyLocale,
) async {
  final router = GoRouter(
    initialLocation: '/admin/features',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/features',
        builder: (context, state) => const FeatureManagerScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminFeaturesGatewayProvider.overrideWithValue(
          const _LocaleFeaturesGateway(),
        ),
        adminFeaturesEnabledProvider.overrideWithValue(true),
      ],
      child: ClubConfigScope(
        config: ClubConfig.fallback(),
        child: MaterialApp.router(
          locale: const Locale('en'),
          builder: (context, child) => AfriLocalizationsScope(
            locale: appCopyLocale,
            child: child ?? const SizedBox.shrink(),
          ),
          theme: ClubTheme.from(
            ClubConfig.fallback(),
            brightness: Brightness.dark,
          ),
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

class _LocaleFeaturesGateway implements AdminFeaturesGateway {
  const _LocaleFeaturesGateway();

  @override
  Future<AdminFeaturesSnapshot> loadAll() async {
    return AdminFeaturesSnapshot.fromRaw(<Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'locale-feature',
        'feature_key': 'predictions',
        'display_name': 'Predictions',
        'description': 'Controlled feature.',
        'category': 'Engagement',
        'is_enabled': true,
        'visibility_state': 'visible',
        'channels': <Map<String, dynamic>>[],
        'rules': <Map<String, dynamic>>[],
      },
    ]);
  }

  @override
  Future<AdminFeatureDetailSnapshot> loadOne(String featureKey) async {
    final snapshot = await loadAll();
    return AdminFeatureDetailSnapshot(feature: snapshot.features.single);
  }

  @override
  Future<void> setGlobalEnabled(String featureId, bool enabled) async {}

  @override
  Future<void> setVisibility(String featureId, String visibility) async {}

  @override
  Future<void> updateChannel(
    String featureId,
    String channel,
    Map<String, dynamic> updates,
  ) async {}

  @override
  Future<void> updateRules(
    String featureId,
    Map<String, dynamic> updates,
  ) async {}
}
