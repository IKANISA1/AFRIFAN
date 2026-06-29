import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/repositories/home_content_repository.dart';
import 'package:feat_home/src/widgets/quick_actions_grid.dart';
import 'package:feat_home/src/widgets/stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Smoke tests for feat_home widgets — StatsRow and QuickActionsGrid.
///
/// These verify rendering, formatting, and child counts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════
  // StatsRow
  // ═══════════════════════════════════════════════════════════

  group('StatsRow', () {
    Widget buildTestApp({int globalFet = 42880, int fanRank = 12}) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: StatsRow(globalFet: globalFet, fanRank: fanRank),
            ),
          ),
        ],
      );

      return MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: ColorTokens.clubPrimary,
            brightness: Brightness.dark,
          ),
        ),
      );
    }

    testWidgets('renders FET label', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('FET'), findsOneWidget);
    });

    testWidgets('renders rank label', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('RANK'), findsOneWidget);
    });

    testWidgets('renders formatted FET number with commas', (tester) async {
      await tester.pumpWidget(buildTestApp(globalFet: 42880));
      await tester.pumpAndSettle();
      expect(find.text('42,880'), findsOneWidget);
    });

    testWidgets('renders fan rank number (zero-padded)', (tester) async {
      await tester.pumpWidget(buildTestApp(fanRank: 7));
      await tester.pumpAndSettle();
      expect(find.text('#007'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════
  // QuickActionsGrid
  // ═══════════════════════════════════════════════════════════

  group('QuickActionsGrid', () {
    Widget buildTestApp() {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(
                child: QuickActionsGrid(actions: HomeQuickAction.fallbackItems),
              ),
            ),
          ),
          // Stub routes for navigation
          GoRoute(
            path: '/fanzone/fixtures',
            builder: (_, __) => const SizedBox(),
          ),
          GoRoute(path: '/fanzone/my', builder: (_, __) => const SizedBox()),
          GoRoute(
            path: '/fanzone/notifications',
            builder: (_, __) => const SizedBox(),
          ),
          GoRoute(path: '/live', builder: (_, __) => const SizedBox()),
          GoRoute(
            path: '/fanzone/leaderboard',
            builder: (_, __) => const SizedBox(),
          ),
          GoRoute(
            path: '/fanzone/wallet',
            builder: (_, __) => const SizedBox(),
          ),
          GoRoute(path: '/tickets', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/membership', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/fan-clubs', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/shop', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/contribute', builder: (_, __) => const SizedBox()),
        ],
      );

      return ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: ColorTokens.clubPrimary,
              brightness: Brightness.dark,
            ),
          ),
        ),
      );
    }

    testWidgets('renders all quick action labels', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Tickets'), findsOneWidget);
      expect(find.text('Join Gikundiro'), findsOneWidget);
      expect(find.text('Fanclubs'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Matchday'), findsOneWidget);
      expect(find.text('Contribute'), findsOneWidget);
    });
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(clubId: '24');

  @override
  Future<UserProfile?> restoreCurrentUser() async => null;

  @override
  Future<AdminWorkspaceAccess> resolveAdminAccess(String userId) async {
    return AdminWorkspaceAccess.none;
  }

  @override
  Stream<supabase.AuthState> get authStateChanges =>
      const Stream<supabase.AuthState>.empty();
}
