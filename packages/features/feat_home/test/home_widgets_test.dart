import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/widgets/quick_actions_grid.dart';
import 'package:feat_home/src/widgets/stats_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

/// Smoke tests for feat_home widgets — StatsRow and QuickActionsGrid.
///
/// These verify rendering, formatting, and child counts.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  // ═══════════════════════════════════════════════════════════
  // StatsRow
  // ═══════════════════════════════════════════════════════════

  group('StatsRow', () {
    Widget buildTestApp({int globalXp = 42880, int fanRank = 12}) {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: StatsRow(globalXp: globalXp, fanRank: fanRank),
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

    testWidgets('renders XP label', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('XP'), findsOneWidget);
    });

    testWidgets('renders rank label', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('Rank'), findsOneWidget);
    });

    testWidgets('renders formatted XP number with commas', (tester) async {
      await tester.pumpWidget(buildTestApp(globalXp: 42880));
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
              body: SingleChildScrollView(child: QuickActionsGrid()),
            ),
          ),
          // Stub routes for navigation
          GoRoute(path: '/tickets', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/shop', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/fan-clubs', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/xp', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/fantasy', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/membership', builder: (_, __) => const SizedBox()),
          GoRoute(path: '/contribute', builder: (_, __) => const SizedBox()),
        ],
      );

      return ProviderScope(
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
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Fans'), findsOneWidget);
      expect(find.text('Games'), findsOneWidget);
      expect(find.text('Fantasy'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
    });

    testWidgets('renders support button', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Support'), findsOneWidget);
    });
  });
}
