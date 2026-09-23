import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/src/official_membership_tiers.dart';
import 'package:feat_membership/src/providers/membership_provider.dart';
import 'package:feat_membership/src/screens/membership_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/touch_target_audit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  setUp(() => ConnectivityService.setOnlineForTest(true));

  testWidgets('matches the membership tier surface layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildMembershipApp(_successSnapshot()));
    await tester.pumpAndSettle();

    expect(find.byType(MembershipScreen), findsOneWidget);
    expect(find.byType(AfriScreenScaffold), findsOneWidget);
    expectTapTargetsMeetMinimum(tester);
  });

  testWidgets('matches the membership loading layout', (tester) async {
    _setMobileSurface(tester);
    final pendingSnapshot = Completer<MembershipSnapshot>();
    addTearDown(() {
      if (!pendingSnapshot.isCompleted) {
        pendingSnapshot.complete(_emptySnapshot());
      }
    });

    await tester.pumpWidget(
      _buildMembershipApp(null, pendingSnapshot: pendingSnapshot),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(find.byType(MembershipScreen), findsOneWidget);
  });

  testWidgets('matches the membership empty layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildMembershipApp(_emptySnapshot()));
    await tester.pumpAndSettle();

    expect(find.byType(MembershipScreen), findsOneWidget);
  });

  testWidgets('matches the membership error layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildMembershipErrorApp());
    await tester.pumpAndSettle();

    expect(find.byType(MembershipScreen), findsOneWidget);
  });

  testWidgets('matches the membership layout at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_buildMembershipApp(_successSnapshot()));
    await tester.pumpAndSettle();

    expect(find.byType(MembershipScreen), findsOneWidget);
  });

  testWidgets('keeps historical payment records out of membership selection', (
    tester,
  ) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildMembershipApp(_pendingSnapshot()));
    await tester.pumpAndSettle();

    expect(find.text('Payment processing'), findsNothing);
    expect(find.text('Pending verification'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('Packages'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is AfriAsyncStateView<MembershipSnapshot>,
      ),
      findsOneWidget,
    );
  });

  testWidgets('labels saved membership data and disables changes offline', (
    tester,
  ) async {
    _setMobileSurface(tester);
    ConnectivityService.setOnlineForTest(false);
    final stale = _successSnapshot().copyWith(
      isStale: true,
      recoveryMessage:
          'Showing saved membership details. Reconnect and refresh before changing membership.',
    );

    await tester.pumpWidget(_buildMembershipApp(stale));
    await tester.pumpAndSettle();

    expect(find.text('Saved membership details'), findsOneWidget);
    expect(
      find.text(
        'Showing saved membership details. '
        'Reconnect and refresh before changing membership.',
      ),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Packages'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Connection required'), findsWidgets);
    final button = tester.widget<AfriButton>(
      find.widgetWithText(AfriButton, 'Connection required').first,
    );
    expect(button.enabled, isFalse);
  });

  testWidgets('caps membership content on tablet width', (tester) async {
    _setSurface(tester, const Size(720, 1024));

    await tester.pumpWidget(_buildMembershipApp(_successSnapshot()));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(CustomScrollView)).width,
      AfriResponsive.tabletContentMax,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports landscape with 200 percent text', (tester) async {
    _setSurface(tester, const Size(720, 393));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_buildMembershipApp(_successSnapshot()));
    await tester.pumpAndSettle();

    expect(find.byType(AfriScreenScaffold), findsOneWidget);
    expect(
      tester.getSize(find.byType(CustomScrollView)).width,
      AfriResponsive.tabletContentMax,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact-height landscape keeps membership tiers and actions usable',
    (tester) async {
      _setSurface(tester, const Size(720, 320));

      await tester.pumpWidget(_buildMembershipApp(_successSnapshot()));
      await tester.pumpAndSettle();

      expect(find.byType(AfriScreenScaffold), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Packages'),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Packages'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final profile in _compactGoldenProfiles) {
    testWidgets('golden compact Membership route ${profile.id}', (
      tester,
    ) async {
      _setGoldenSurface(tester, profile.size);
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      ColorTokens.setBrightness(profile.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));

      await tester.pumpWidget(
        _buildMembershipApp(
          _successSnapshot(),
          brightness: profile.brightness,
          goldenKey: const ValueKey<String>('membership-route-golden'),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey<String>('membership-route-golden')),
        matchesGoldenFile('goldens/membership_${profile.id}.png'),
      );
    });
  }

  testWidgets('golden Membership route loading state', (tester) async {
    final pendingSnapshot = Completer<MembershipSnapshot>();
    addTearDown(() {
      if (!pendingSnapshot.isCompleted) {
        pendingSnapshot.complete(_emptySnapshot());
      }
    });
    await _pumpMembershipStateGolden(
      tester,
      id: 'loading',
      pendingSnapshot: pendingSnapshot,
      settle: false,
      scrollToText: 'Packages',
    );
  });

  testWidgets('golden Membership route empty state', (tester) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'empty',
      snapshot: _emptySnapshot(),
      scrollToText: 'Membership setup pending',
    );
  });

  testWidgets('golden Membership route error state', (tester) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'error',
      notifierFactory: _ErrorMembershipNotifier.new,
      scrollToText: 'Membership unavailable',
    );
  });

  testWidgets('golden Membership route offline state', (tester) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'offline',
      notifierFactory: _ErrorMembershipNotifier.new,
      online: false,
      scrollToText: 'Connect to load current membership details.',
      additionalScroll: 160,
    );
  });

  testWidgets('golden Membership route large-text state', (tester) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'large_text',
      snapshot: _successSnapshot(),
      size: const Size(320, 720),
      textScale: 2,
      scrollToText: 'Gold · Current',
    );
  });

  testWidgets('golden Membership route selected state', (tester) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'selected',
      snapshot: _successSnapshot(),
      scrollToText: 'Gold · Current',
    );

    final currentPackage = find.bySemanticsLabel(
      'Gold membership package, current',
    );
    expect(currentPackage, findsOneWidget);
    final semantics = tester.getSemantics(currentPackage);
    expect(semantics.flagsCollection.isSelected.toBoolOrNull(), isTrue);
  });

  testWidgets('golden Membership route disabled state', (tester) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'disabled',
      snapshot: _pendingSnapshot(),
      online: false,
      scrollToKey: const ValueKey<String>('membership-action-gold'),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
        await tester.pumpAndSettle();
      },
    );
    final disabledAction = tester.widget<AfriButton>(
      find.byKey(const ValueKey<String>('membership-action-gold')),
    );
    expect(disabledAction.enabled, isFalse);
  });

  testWidgets('golden Membership route focused state', (tester) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'focused',
      snapshot: _successSnapshot(),
      autofocusTier: 'silver',
      scrollToKey: const ValueKey<String>('membership-action-silver'),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
        await tester.pumpAndSettle();
      },
    );
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
  });

  testWidgets('golden Membership route pressed state', (tester) async {
    TestGesture? heldGesture;
    await _pumpMembershipStateGolden(
      tester,
      id: 'pressed',
      snapshot: _successSnapshot(),
      scrollToKey: const ValueKey<String>('membership-action-silver'),
      beforeCapture: (tester) async {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 120));
        await tester.pumpAndSettle();
        heldGesture = await tester.startGesture(
          tester.getCenter(
            find.byKey(const ValueKey<String>('membership-action-silver')),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
      },
      afterCapture: () async {
        await heldGesture?.up();
      },
    );
  });

  testWidgets('golden Membership route permission-denied state', (
    tester,
  ) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'permission_denied',
      snapshot: _successSnapshot(),
      packageActivator: (_) async {
        throw StateError(
          'RLS permission denied for private-account-membership-4482',
        );
      },
      scrollToKey: const ValueKey<String>('membership-action-silver'),
      beforeCapture: (tester) async {
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('membership-action-silver')),
            )
            .onTap();
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.text('Membership change not permitted'), findsOneWidget);
      },
    );
    expect(
      find.textContaining('private-account-membership-4482'),
      findsNothing,
    );
  });

  testWidgets('golden Membership route syncing state', (tester) async {
    final pendingActivation = Completer<void>();
    addTearDown(() {
      if (!pendingActivation.isCompleted) {
        pendingActivation.complete();
      }
    });
    await _pumpMembershipStateGolden(
      tester,
      id: 'syncing',
      snapshot: _successSnapshot(),
      packageActivator: (_) => pendingActivation.future,
      scrollToKey: const ValueKey<String>('membership-action-silver'),
      beforeCapture: (tester) async {
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('membership-action-silver')),
            )
            .onTap();
        await tester.pump();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
        await tester.pump();
        expect(find.text('Opening MoMo'), findsOneWidget);
      },
      afterCapture: () async {
        if (!pendingActivation.isCompleted) {
          pendingActivation.complete();
        }
        await tester.pump();
      },
    );
  });

  testWidgets('golden Membership route conflict state', (tester) async {
    await _pumpMembershipStateGolden(
      tester,
      id: 'conflict',
      snapshot: _successSnapshot(),
      packageActivator: (_) async {
        throw StateError('revision conflict: membership row changed at 4482');
      },
      scrollToKey: const ValueKey<String>('membership-action-silver'),
      beforeCapture: (tester) async {
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('membership-action-silver')),
            )
            .onTap();
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.text('Membership details changed'), findsOneWidget);
      },
    );
    expect(find.textContaining('4482'), findsNothing);
  });

  testWidgets('golden Membership route security-timeout state', (tester) async {
    final pendingActivation = Completer<void>();
    addTearDown(() {
      if (!pendingActivation.isCompleted) {
        pendingActivation.complete();
      }
    });
    await _pumpMembershipStateGolden(
      tester,
      id: 'security_timeout',
      snapshot: _successSnapshot(),
      packageActivator: (_) => pendingActivation.future,
      activationTimeout: const Duration(milliseconds: 20),
      scrollToKey: const ValueKey<String>('membership-action-silver'),
      beforeCapture: (tester) async {
        tester
            .widget<AfriButton>(
              find.byKey(const ValueKey<String>('membership-action-silver')),
            )
            .onTap();
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pump();
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.text('Membership request timed out'), findsOneWidget);
      },
    );
  });
}

Widget _buildMembershipApp(
  MembershipSnapshot? snapshot, {
  Completer<MembershipSnapshot>? pendingSnapshot,
  MembershipNotifier Function()? notifierFactory,
  Brightness brightness = Brightness.dark,
  Key? goldenKey,
  MembershipPackageActivator? packageActivator,
  Duration activationTimeout = const Duration(seconds: 30),
  String? autofocusTier,
}) {
  final createNotifier =
      notifierFactory ??
      () => pendingSnapshot == null
          ? _StaticMembershipNotifier(snapshot ?? _emptySnapshot())
          : _PendingMembershipNotifier(pendingSnapshot);
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) => const UserProfile(
          id: 'user-1',
          clubId: '24',
          publicUserId: '483912',
        ),
      ),
      membershipProvider.overrideWith(createNotifier),
    ],
    child: MaterialApp(
      theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
      home: RepaintBoundary(
        key: goldenKey,
        child: MembershipScreen(
          packageActivator: packageActivator,
          activationTimeout: activationTimeout,
          autofocusTier: autofocusTier,
        ),
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: true),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

const _membershipStateGoldenPaths = <String, String>{
  'loading': 'goldens/membership_state_loading_dark_390x844.png',
  'empty': 'goldens/membership_state_empty_dark_390x844.png',
  'error': 'goldens/membership_state_error_dark_390x844.png',
  'offline': 'goldens/membership_state_offline_dark_390x844.png',
  'large_text': 'goldens/membership_state_large_text_dark_320x720.png',
  'selected': 'goldens/membership_state_selected_dark_390x844.png',
  'disabled': 'goldens/membership_state_disabled_dark_390x844.png',
  'focused': 'goldens/membership_state_focused_dark_390x844.png',
  'pressed': 'goldens/membership_state_pressed_dark_390x844.png',
  'permission_denied':
      'goldens/membership_state_permission_denied_dark_390x844.png',
  'syncing': 'goldens/membership_state_syncing_dark_390x844.png',
  'conflict': 'goldens/membership_state_conflict_dark_390x844.png',
  'security_timeout':
      'goldens/membership_state_security_timeout_dark_390x844.png',
};

Future<void> _pumpMembershipStateGolden(
  WidgetTester tester, {
  required String id,
  MembershipSnapshot? snapshot,
  Completer<MembershipSnapshot>? pendingSnapshot,
  MembershipNotifier Function()? notifierFactory,
  Size size = const Size(390, 844),
  double textScale = 1,
  bool settle = true,
  bool online = true,
  String? scrollToText,
  Key? scrollToKey,
  double additionalScroll = 0,
  MembershipPackageActivator? packageActivator,
  Duration activationTimeout = const Duration(seconds: 30),
  String? autofocusTier,
  Future<void> Function(WidgetTester tester)? beforeCapture,
  Future<void> Function()? afterCapture,
}) async {
  _setGoldenSurface(tester, size);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  ColorTokens.setBrightness(Brightness.dark);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  ConnectivityService.setOnlineForTest(online);
  addTearDown(() => ConnectivityService.setOnlineForTest(true));

  await tester.pumpWidget(
    _buildMembershipApp(
      snapshot,
      pendingSnapshot: pendingSnapshot,
      notifierFactory: notifierFactory,
      goldenKey: const ValueKey<String>('membership-state-golden'),
      packageActivator: packageActivator,
      activationTimeout: activationTimeout,
      autofocusTier: autofocusTier,
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  if (scrollToKey != null) {
    await tester.scrollUntilVisible(
      find.byKey(scrollToKey),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  } else if (scrollToText != null) {
    await tester.scrollUntilVisible(
      find.text(scrollToText),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    if (additionalScroll > 0) {
      await tester.drag(
        find.byType(Scrollable).first,
        Offset(0, -additionalScroll),
      );
      await tester.pumpAndSettle();
    }
  }

  await beforeCapture?.call(tester);

  expect(tester.takeException(), isNull);
  final goldenPath = _membershipStateGoldenPaths[id];
  expect(
    goldenPath,
    isNotNull,
    reason: 'Missing Membership golden path for $id.',
  );
  await expectLater(
    find.byKey(const ValueKey<String>('membership-state-golden')),
    matchesGoldenFile(goldenPath!),
  );
  await afterCapture?.call();
}

const _compactGoldenProfiles =
    <({String id, Size size, Brightness brightness})>[
      (
        id: 'compact_dark_320x760',
        size: Size(320, 760),
        brightness: Brightness.dark,
      ),
      (
        id: 'compact_light_374x812',
        size: Size(374, 812),
        brightness: Brightness.light,
      ),
      (
        id: 'standard_dark_390x844',
        size: Size(390, 844),
        brightness: Brightness.dark,
      ),
      (
        id: 'large_light_430x900',
        size: Size(430, 900),
        brightness: Brightness.light,
      ),
      (
        id: 'wide_dark_599x900',
        size: Size(599, 900),
        brightness: Brightness.dark,
      ),
      (
        id: 'foldable_half_light_674x842',
        size: Size(674, 842),
        brightness: Brightness.light,
      ),
      (
        id: 'tablet_dark_834x1194',
        size: Size(834, 1194),
        brightness: Brightness.dark,
      ),
    ];

void _setGoldenSurface(WidgetTester tester, Size size) {
  _setSurface(tester, size);
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Widget _buildMembershipErrorApp() {
  return _buildMembershipApp(
    null,
    notifierFactory: _ErrorMembershipNotifier.new,
  );
}

MembershipSnapshot _successSnapshot() {
  return MembershipSnapshot(
    packages: officialMembershipPackages(),
    membership: const <String, dynamic>{
      'tier': 'gold',
      'points': 5260,
      'payment_status': 'verified',
      'joined_at': '2026-01-12T08:00:00Z',
      'expires_at': '2027-01-12T08:00:00Z',
    },

    contributions: const [],
  );
}

MembershipSnapshot _emptySnapshot() {
  return const MembershipSnapshot(
    packages: <Map<String, dynamic>>[],
    membership: null,

    contributions: [],
  );
}

MembershipSnapshot _pendingSnapshot() {
  return MembershipSnapshot(
    packages: officialMembershipPackages(),
    membership: null,

    contributions: const [],
  );
}

void _setMobileSurface(WidgetTester tester) {
  _setSurface(tester, const Size(393, 852));
}

void _setSurface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _StaticMembershipNotifier extends MembershipNotifier {
  _StaticMembershipNotifier(this.snapshot);

  final MembershipSnapshot snapshot;

  @override
  Future<MembershipSnapshot> build() async => snapshot;
}

class _PendingMembershipNotifier extends MembershipNotifier {
  _PendingMembershipNotifier(this.pendingSnapshot);

  final Completer<MembershipSnapshot> pendingSnapshot;

  @override
  Future<MembershipSnapshot> build() => pendingSnapshot.future;
}

class _ErrorMembershipNotifier extends MembershipNotifier {
  @override
  Future<MembershipSnapshot> build() async {
    throw StateError('membership unavailable');
  }
}
