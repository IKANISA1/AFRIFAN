import 'package:core_router/core_router.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => TypographyTokens.debugUseFallbackFonts = true);
  tearDown(() => TypographyTokens.debugUseFallbackFonts = false);

  test('no enabled modules retains a valid built-in recovery route', () {
    final factory = AppRouter(
      modules: const [],
      shellBuilder: (_, __) => throw StateError('No shell should be built'),
    );
    expect(factory.initialLocation, '/feature-unavailable');
    expect(factory.tabs, isEmpty);
    final router = factory.router;
    addTearDown(router.dispose);
    expect(router.configuration.routes, hasLength(1));
    expect(
      router.configuration.findMatch(Uri.parse('/feature-unavailable')).isError,
      isFalse,
    );
  });

  testWidgets('zero enabled modules renders recovery without a shell', (
    tester,
  ) async {
    final factory = AppRouter(
      modules: const [],
      shellBuilder: (_, __) => throw StateError('No shell should be built'),
    );
    await _pump(tester, factory);
    expect(find.byType(RouteRecoveryScreen), findsOneWidget);
    expect(find.text('This feature is currently unavailable.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(
      factory.router.routeInformationProvider.value.uri.path,
      '/feature-unavailable',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone-only modules recover to a registered destination', (
    tester,
  ) async {
    final factory = AppRouter(
      modules: [_StandaloneModule('/support')],
      shellBuilder: (_, __) => throw StateError('No shell should be built'),
    );
    expect(factory.initialLocation, '/support');
    await _pump(tester, factory);
    expect(find.text('/support'), findsOneWidget);
    factory.router.go('/feature-unavailable?from=/private-account-details');
    await tester.pumpAndSettle();
    expect(find.text('Requested section'), findsOneWidget);
    expect(find.textContaining('private-account-details'), findsNothing);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(find.text('/support'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a settings-only shell retains its actual recovery destination', (
    tester,
  ) async {
    final factory = AppRouter(
      modules: [_TabModule('settings')],
      shellBuilder: (_, shell) => shell,
    );
    expect(factory.tabs, isEmpty);
    expect(factory.initialLocation, '/settings');
    await _pump(tester, factory);
    expect(find.text('/settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabled routes recover to Home and can be enabled later', (
    tester,
  ) async {
    var shopEnabled = false;
    final factory = AppRouter(
      modules: [_TabModule('home'), _StandaloneModule('/shop')],
      shellBuilder: (_, shell) => shell,
      isFeatureEnabled: (path) => path == '/shop' && shopEnabled,
    );
    await _pump(tester, factory);
    // The active Home invariant remains usable even when the remote callback
    // denies it. Domain commands continue to enforce their own authorization.
    expect(find.text('/home'), findsOneWidget);
    factory.router.go('/shop');
    await tester.pumpAndSettle();
    expect(
      factory.router.routeInformationProvider.value.uri.path,
      '/feature-unavailable',
    );
    expect(find.byType(RouteRecoveryScreen), findsOneWidget);
    await tester.tap(find.text('Go back'));
    await tester.pumpAndSettle();
    expect(find.text('/home'), findsOneWidget);
    shopEnabled = true;
    factory.router.go('/shop');
    await tester.pumpAndSettle();
    expect(find.text('/shop'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('malformed flags fail closed without throwing during registration', () {
    final module = _StandaloneModule('/shop');
    for (final snapshot in <Map<String, dynamic>>[
      {'features': null},
      {'features': 'enabled'},
      {
        'features': [
          {'feature_key': 'shop', 'is_enabled': 'true'},
        ],
      },
      {
        'features': [
          {'feature_key': 'shop', 'is_enabled': null},
        ],
      },
      {
        'features': [
          {'feature_key': 'shop', 'visibility_state': 'unknown'},
        ],
      },
      {
        'features': [
          {'feature_key': 'shop', 'channel': []},
        ],
      },
      {
        'features': [
          {
            'feature_key': 'shop',
            'rules': {'is_within_schedule': 1},
          },
        ],
      },
      {
        'features': [
          {'feature_key': 'shop'},
          {'feature_key': ' SHOP '},
        ],
      },
    ]) {
      expect(
        module.isEnabledForConfig(configSnapshot: snapshot),
        isFalse,
        reason: snapshot.toString(),
      );
    }
  });

  test('club capability intersects valid runtime availability', () {
    final module = _StandaloneModule('/shop');
    expect(
      module.isEnabledForConfig(
        featureFlags: {'shop': false},
        configSnapshot: {
          'features': [
            {'feature_key': 'shop', 'is_enabled': true},
          ],
        },
      ),
      isFalse,
    );
    expect(module.isEnabledForConfig(), isTrue);
    expect(module.isEnabledForConfig(configSnapshot: {'features': []}), isTrue);
    expect(
      module.isEnabledForConfig(
        configSnapshot: {
          'features': [
            {'feature_key': 'shop', 'visibility_state': 'hidden'},
          ],
        },
      ),
      isTrue,
    );
  });
}

Future<void> _pump(WidgetTester tester, AppRouter factory) async {
  final router = factory.router;
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pumpAndSettle();
}

class _StandaloneModule extends FeatureModule {
  _StandaloneModule(this.path);
  final String path;
  @override
  String get featureKey => path.substring(1);
  @override
  List<RouteBase> get routes => [
    GoRoute(path: path, builder: (_, __) => Text(path)),
  ];
}

class _TabModule extends FeatureModule {
  _TabModule(this.featureKey);
  @override
  final String featureKey;
  @override
  TabRoute get tabRoute => TabRoute(
    path: '/$featureKey',
    label: featureKey,
    icon: Icons.home,
    builder: (_, __) => Text('/$featureKey'),
  );
}
