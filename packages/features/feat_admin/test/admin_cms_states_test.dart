import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_admin/feat_admin.dart';
import 'package:feat_admin/src/screens/cms_content_manager_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';

const _goldenViewport = Size(390, 844);
const _goldenViewportId = '390x844';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  setUp(() {
    ConnectivityService.setOnlineForTest(true);
    TypographyTokens.debugUseFallbackFonts = true;
  });
  tearDown(() {
    ConnectivityService.setOnlineForTest(true);
    TypographyTokens.debugUseFallbackFonts = false;
    ColorTokens.setBrightness(Brightness.dark);
  });

  testWidgets('renders a truthful loading state', (tester) async {
    final pending = Completer<AdminCmsSnapshot>();
    await _pumpCms(
      tester,
      gateway: _CmsGateway(<Object>[pending.future]),
      settle: false,
    );

    expect(find.text('Loading content manager'), findsOneWidget);
    expect(find.text('SEASON LAUNCH'), findsNothing);
    await _expectStateGolden(tester, 'loading');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('renders a confirmed empty workspace', (tester) async {
    await _pumpCms(
      tester,
      gateway: _CmsGateway(const <Object>[AdminCmsSnapshot.empty()]),
    );

    expect(find.text('No managed content'), findsOneWidget);
    expect(find.text('ADD ARTICLE'), findsOneWidget);
    await _expectStateGolden(tester, 'empty');
  });

  testWidgets('renders a privacy-safe unknown error', (tester) async {
    await _pumpCms(
      tester,
      gateway: _CmsGateway(<Object>[
        StateError('provider row private-account-991 failed'),
      ]),
    );

    expect(find.text('Content manager unavailable'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    expect(find.text('SEASON LAUNCH'), findsNothing);
    await _expectStateGolden(tester, 'error');
  });

  testWidgets('renders offline without private content data', (tester) async {
    await _pumpCms(
      tester,
      gateway: _CmsGateway(<Object>[_workspace]),
      online: false,
    );

    expect(find.text('Content manager offline'), findsOneWidget);
    expect(find.text('SEASON LAUNCH'), findsNothing);
    await _expectStateGolden(tester, 'offline');
  });

  testWidgets('permission denial clears private workspace and controls', (
    tester,
  ) async {
    await _pumpCms(
      tester,
      gateway: _CmsGateway(const <Object>[
        AdminCmsFailure(AdminCmsFailureKind.permissionDenied),
      ]),
    );

    expect(find.text('Content access unavailable'), findsOneWidget);
    expect(find.text('SEASON LAUNCH'), findsNothing);
    expect(find.text('ADD ARTICLE'), findsNothing);
    await _expectStateGolden(tester, 'permission_denied');
  });

  testWidgets('renders the feature-disabled state', (tester) async {
    await _pumpCms(
      tester,
      gateway: _CmsGateway(<Object>[_workspace]),
      enabled: false,
    );

    expect(find.text('Content manager unavailable'), findsOneWidget);
    expect(
      find.textContaining('disabled for this controlled build'),
      findsOneWidget,
    );
    expect(find.text('SEASON LAUNCH'), findsNothing);
    await _expectStateGolden(tester, 'disabled');
  });

  testWidgets('renders confirmed content and publishing control', (
    tester,
  ) async {
    await _pumpCms(tester, gateway: _CmsGateway(<Object>[_workspace]));

    expect(find.text('SEASON LAUNCH'), findsOneWidget);
    expect(find.text('UNPUBLISH'), findsOneWidget);
    expect(find.text('ADD ARTICLE'), findsOneWidget);
  });

  for (final localeCase in <(Locale, String, String)>[
    (const Locale('fr'), 'GESTIONNAIRE DE CONTENU', 'RETIRER'),
    (const Locale('rw'), 'AHAGENZURIRWA IBIRIMO', 'KURAHO'),
  ]) {
    testWidgets(
      'renders CMS article dates and actions in ${localeCase.$1.languageCode}',
      (tester) async {
        await _pumpCms(
          tester,
          gateway: _CmsGateway(<Object>[_workspace]),
          appCopyLocale: localeCase.$1,
        );

        expect(find.text(localeCase.$2), findsOneWidget);
        expect(find.text(localeCase.$3), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('syncing retains confirmed content and pauses actions', (
    tester,
  ) async {
    final pending = Completer<AdminCmsSnapshot>();
    final gateway = _CmsGateway(<Object>[_workspace, pending.future]);
    final container = await _pumpCms(tester, gateway: gateway);

    unawaited(container.read(adminCmsProvider.notifier).refresh());
    await tester.pump();

    expect(find.text('Refreshing content'), findsOneWidget);
    expect(find.text('SEASON LAUNCH'), findsOneWidget);
    expect(
      tester
          .widget<AfriTextIconButton>(
            find.byKey(const ValueKey<String>('admin-cms-action-add-article')),
          )
          .onPressed,
      isNull,
    );
    await _expectStateGolden(tester, 'syncing');
    pending.complete(_workspace);
    await tester.pumpAndSettle();
  });

  testWidgets('conflict retains confirmed content and recovery consequence', (
    tester,
  ) async {
    final gateway = _CmsGateway(<Object>[
      _workspace,
      const AdminCmsFailure(AdminCmsFailureKind.conflict),
    ]);
    final container = await _pumpCms(tester, gateway: gateway);

    await container.read(adminCmsProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Content changed'), findsOneWidget);
    expect(find.text('SEASON LAUNCH'), findsOneWidget);
    expect(find.textContaining('Actions are paused'), findsOneWidget);
    await _expectStateGolden(tester, 'conflict');
  });

  testWidgets('security timeout retains content and hides diagnostics', (
    tester,
  ) async {
    final gateway = _CmsGateway(<Object>[
      _workspace,
      TimeoutException('private-account-991 timed out'),
    ]);
    final container = await _pumpCms(tester, gateway: gateway);

    await container.read(adminCmsProvider.notifier).refresh();
    await tester.pump();

    expect(find.text('Security check timed out'), findsOneWidget);
    expect(find.text('SEASON LAUNCH'), findsOneWidget);
    expect(find.textContaining('private-account-991'), findsNothing);
    await _expectStateGolden(tester, 'security_timeout');
  });

  testWidgets('selected section exposes current selection semantics', (
    tester,
  ) async {
    await _pumpCms(tester, gateway: _CmsGateway(<Object>[_workspace]));

    await tester.tap(find.text('Quick Actions'));
    await tester.pumpAndSettle();

    expect(find.text('HOME QUICK ACTIONS'), findsOneWidget);
    final selectedChip = tester.widget<AfriChoiceChip>(
      find.widgetWithText(AfriChoiceChip, 'Quick Actions'),
    );
    expect(selectedChip.selected, isTrue);
    await _expectStateGolden(tester, 'selected');
  });

  testWidgets('primary action supports focus, press, and keyboard activation', (
    tester,
  ) async {
    final focusNode = FocusNode(debugLabel: 'admin-cms-add-article');
    addTearDown(focusNode.dispose);
    final previousStrategy = FocusManager.instance.highlightStrategy;
    addTearDown(
      () => FocusManager.instance.highlightStrategy = previousStrategy,
    );
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    await _pumpCms(
      tester,
      gateway: _CmsGateway(<Object>[_workspace]),
      primaryActionFocusNode: focusNode,
    );
    final action = find.byKey(
      const ValueKey<String>('admin-cms-action-add-article'),
    );
    final textButton = find.descendant(
      of: action,
      matching: find.byType(TextButton),
    );
    expect(textButton, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(textButton));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 100));
    await _expectStateGolden(tester, 'pressed');
    await gesture.cancel();
    await tester.pumpAndSettle();

    focusNode.requestFocus();
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);
    await _expectStateGolden(tester, 'focused');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('NEW ARTICLE'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
  });

  testWidgets('supports 200 percent text without horizontal overflow', (
    tester,
  ) async {
    await _pumpCms(
      tester,
      gateway: _CmsGateway(<Object>[_workspace]),
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
    final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
    expect(
      scrollable.axisDirection,
      anyOf(AxisDirection.down, AxisDirection.up),
    );
    await _expectStateGolden(tester, 'large_text');
  });

  testWidgets('respects reduced motion', (tester) async {
    await _pumpCms(
      tester,
      gateway: _CmsGateway(<Object>[_workspace]),
      reduceMotion: true,
    );

    final context = tester.element(find.byType(CmsContentManagerScreen));
    expect(AfriMotion.reduceMotion(context), isTrue);
    expect(tester.takeException(), isNull);
    await _expectStateGolden(tester, 'reduced_motion');
  });

  for (final brightness in <Brightness>[Brightness.dark, Brightness.light]) {
    testWidgets('renders the ${brightness.name} theme', (tester) async {
      await _pumpCms(
        tester,
        gateway: _CmsGateway(<Object>[_workspace]),
        brightness: brightness,
      );

      expect(find.text('CONTENT MANAGER'), findsOneWidget);
      expect(
        Theme.of(
          tester.element(find.byType(CmsContentManagerScreen)),
        ).brightness,
        brightness,
      );
      expect(tester.takeException(), isNull);
      await _expectStateGolden(tester, brightness.name);
    });
  }
}

Future<ProviderContainer> _pumpCms(
  WidgetTester tester, {
  required AdminCmsGateway gateway,
  bool enabled = true,
  bool online = true,
  bool settle = true,
  bool reduceMotion = false,
  double textScale = 1,
  Brightness brightness = Brightness.dark,
  Locale appCopyLocale = const Locale('en'),
  FocusNode? primaryActionFocusNode,
}) async {
  tester.view.physicalSize = _goldenViewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      FakeAccessibilityFeatures(
        disableAnimations: reduceMotion,
        accessibleNavigation: reduceMotion,
      );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  ConnectivityService.setOnlineForTest(online);
  ColorTokens.setBrightness(brightness);

  final router = GoRouter(
    initialLocation: '/admin/cms',
    routes: <RouteBase>[
      GoRoute(
        path: '/admin/cms',
        builder: (_, _) => CmsContentManagerScreen(
          primaryActionFocusNode: primaryActionFocusNode,
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  late ProviderContainer container;
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        adminCmsGatewayProvider.overrideWithValue(gateway),
        adminCmsEnabledProvider.overrideWithValue(enabled),
      ],
      child: Consumer(
        builder: (context, ref, child) {
          container = ProviderScope.containerOf(context);
          return ClubConfigScope(
            config: ClubConfig.fallback(),
            child: AfriLocalizationsScope(
              locale: appCopyLocale,
              child: MaterialApp.router(
                debugShowCheckedModeBanner: false,
                builder: (context, child) {
                  final mediaQuery = MediaQuery.of(context);
                  return MediaQuery(
                    data: mediaQuery.copyWith(
                      disableAnimations: reduceMotion,
                      accessibleNavigation: reduceMotion,
                    ),
                    child: child!,
                  );
                },
                theme: ClubTheme.from(
                  ClubConfig.fallback(),
                  brightness: brightness,
                ),
                routerConfig: router,
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pump();
  if (settle) await tester.pumpAndSettle();
  return container;
}

Future<void> _expectStateGolden(WidgetTester tester, String id) async {
  final suffix = id == 'light' ? 'light' : 'dark';
  expect(tester.view.physicalSize, _goldenViewport);
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile(
      'goldens/admin_cms_state_${id}_${suffix}_$_goldenViewportId.png',
    ),
  );
}

final _workspace = AdminCmsSnapshot.fromRawCollections(<Object?>[
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'article-1',
      'title': 'Season launch',
      'category': 'Club',
      'is_published': true,
      'is_featured': true,
      'published_at': '2026-07-30T08:00:00Z',
    },
  ],
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'action-1',
      'action_key': 'tickets',
      'title': 'Match tickets',
      'route': '/tickets',
      'icon_key': 'ticket',
      'country': 'RW',
      'is_active': true,
    },
  ],
  <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 'partner-1',
      'name': 'Community Bank',
      'slug': 'community-bank',
      'category': 'bank',
      'country': 'RW',
      'is_active': true,
      'gamification_enabled': false,
    },
  ],
  const <Object>[],
  const <Object>[],
  const <Object>[],
  const <Object>[],
  const <Object>[],
  const <Object>[],
]);

class _CmsGateway implements AdminCmsGateway {
  _CmsGateway(this.outcomes);

  final List<Object> outcomes;
  int loadCount = 0;

  @override
  Future<AdminCmsSnapshot> load() async {
    final index = loadCount++;
    final outcome = outcomes[index.clamp(0, outcomes.length - 1)];
    if (outcome is Future<AdminCmsSnapshot>) return outcome;
    if (outcome is AdminCmsSnapshot) return outcome;
    throw outcome;
  }
}
