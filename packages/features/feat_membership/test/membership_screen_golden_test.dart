import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_membership/src/official_membership_tiers.dart';
import 'package:feat_membership/src/providers/membership_provider.dart';
import 'package:feat_membership/src/screens/membership_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_support/design_font_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadDesignFonts);

  testWidgets('matches the membership tier surface layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildMembershipApp(_successSnapshot()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MembershipScreen),
      matchesGoldenFile('goldens/membership_screen.png'),
    );
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

    await expectLater(
      find.byType(MembershipScreen),
      matchesGoldenFile('goldens/membership_screen_loading.png'),
    );
  });

  testWidgets('matches the membership empty layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildMembershipApp(_emptySnapshot()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MembershipScreen),
      matchesGoldenFile('goldens/membership_screen_empty.png'),
    );
  });

  testWidgets('matches the membership error layout', (tester) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildMembershipErrorApp());
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MembershipScreen),
      matchesGoldenFile('goldens/membership_screen_error.png'),
    );
  });

  testWidgets('matches the membership layout at 200 percent text', (
    tester,
  ) async {
    _setMobileSurface(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(_buildMembershipApp(_successSnapshot()));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MembershipScreen),
      matchesGoldenFile('goldens/membership_screen_large_text.png'),
    );
  });

  testWidgets('uses shared async state and pending review banner', (
    tester,
  ) async {
    _setMobileSurface(tester);

    await tester.pumpWidget(_buildMembershipApp(_pendingSnapshot()));
    await tester.pumpAndSettle();

    expect(find.byType(AfriStateBanner), findsOneWidget);
    expect(find.text('Membership review'), findsOneWidget);
    expect(
      find.text('Gold request is awaiting payment verification.'),
      findsOneWidget,
    );

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
}

Widget _buildMembershipApp(
  MembershipSnapshot? snapshot, {
  Completer<MembershipSnapshot>? pendingSnapshot,
}) {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) => const UserProfile(
          id: 'user-1',
          clubId: '24',
          publicUserId: '483912',
        ),
      ),
      membershipProvider.overrideWith(
        () => pendingSnapshot == null
            ? _StaticMembershipNotifier(snapshot ?? _emptySnapshot())
            : _PendingMembershipNotifier(pendingSnapshot),
      ),
    ],
    child: MaterialApp(
      home: const MembershipScreen(),
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

Widget _buildMembershipErrorApp() {
  return ProviderScope(
    overrides: [
      currentUserProvider.overrideWith(
        (ref) => const UserProfile(
          id: 'user-1',
          clubId: '24',
          publicUserId: '483912',
        ),
      ),
      membershipProvider.overrideWith(_ErrorMembershipNotifier.new),
    ],
    child: MaterialApp(
      home: const MembershipScreen(),
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
    applications: const <Map<String, dynamic>>[],
    contributions: const [],
  );
}

MembershipSnapshot _emptySnapshot() {
  return const MembershipSnapshot(
    packages: <Map<String, dynamic>>[],
    membership: null,
    applications: <Map<String, dynamic>>[],
    contributions: [],
  );
}

MembershipSnapshot _pendingSnapshot() {
  return MembershipSnapshot(
    packages: officialMembershipPackages(),
    membership: null,
    applications: const <Map<String, dynamic>>[
      <String, dynamic>{
        'tier': 'gold',
        'status': 'pending',
        'payment_status': 'unpaid',
        'application_date': '2026-07-01T08:00:00Z',
        'metadata': <String, dynamic>{'amount': 5000, 'currency_symbol': 'RWF'},
      },
    ],
    contributions: const [],
  );
}

void _setMobileSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(393, 852);
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
