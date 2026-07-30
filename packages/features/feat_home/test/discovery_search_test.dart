import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_home/src/screens/discovery_search_screen.dart';
import 'package:feat_home/src/search/discovery_search.dart';
import 'package:feat_home/src/search/discovery_search_provider.dart';
import 'package:feat_home/src/search/federated_discovery_search_repository.dart';
import 'package:feat_home/src/search/local_discovery_search_repository.dart';
import 'package:feat_home/src/search/recent_discovery_search_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:test_support/app_font_loader.dart';
import 'package:test_support/touch_target_audit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  group('LocalDiscoverySearchRepository', () {
    const repository = LocalDiscoverySearchRepository();

    test('indexes the canonical football-club route family', () async {
      for (final testCase in <({String query, String id, String destination})>[
        (query: 'official club', id: 'club', destination: '/club'),
        (query: 'squad players', id: 'club-team', destination: '/club/team'),
        (query: 'official story', id: 'club-news', destination: '/club/news'),
        (
          query: 'score matches',
          id: 'club-results',
          destination: '/club/results',
        ),
        (
          query: 'club heritage',
          id: 'club-history',
          destination: '/club/history',
        ),
        (
          query: 'projects support',
          id: 'club-projects',
          destination: '/club/projects',
        ),
        (
          query: 'match schedule',
          id: 'fixtures',
          destination: '/club/fixtures',
        ),
        (
          query: 'league table',
          id: 'standings',
          destination: '/club/standings',
        ),
      ]) {
        final response = await repository.search(
          DiscoverySearchQuery(text: testCase.query),
        );
        final result = response.results.singleWhere(
          (item) => item.id == testCase.id,
        );
        expect(result.destination, testCase.destination);
      }
    });

    test('keeps approved venues secondary under matchday services', () async {
      final response = await repository.search(
        const DiscoverySearchQuery(
          text: 'venue watch',
          category: DiscoveryCategory.services,
        ),
      );

      final venue = response.results.singleWhere(
        (result) => result.id == 'approved-venues',
      );
      expect(venue.destination, '/fanzone/venue');
      expect(venue.category, DiscoveryCategory.services);
    });

    test(
      'returns bounded fixture results without private identifiers',
      () async {
        final response = await repository.search(
          const DiscoverySearchQuery(
            text: 'match',
            category: DiscoveryCategory.fixtures,
          ),
        );

        expect(response.results, isNotEmpty);
        expect(
          response.results.every(
            (result) => result.category == DiscoveryCategory.fixtures,
          ),
          isTrue,
        );
        expect(
          response.results.length,
          lessThanOrEqualTo(LocalDiscoverySearchRepository.maxResults),
        );
        expect(
          response.results
              .map((result) => '${result.title} ${result.description}')
              .join(' '),
          isNot(contains(RegExp(r'\+\d{7,}|otp|token=', caseSensitive: false))),
        );
      },
    );

    test('requires every query term and respects category filters', () async {
      final response = await repository.search(
        const DiscoverySearchQuery(
          text: 'club shop',
          category: DiscoveryCategory.commerce,
        ),
      );

      expect(response.results.map((result) => result.id), contains('shop'));
      expect(
        response.results.every(
          (result) => result.category == DiscoveryCategory.commerce,
        ),
        isTrue,
      );
    });

    test('localizes the searchable catalog for EN, FR, and RW', () async {
      for (final testCase in <({String locale, String query, String title})>[
        (locale: 'en', query: 'tickets', title: 'Match tickets'),
        (locale: 'fr', query: 'billets', title: 'Billets de match'),
        (locale: 'rw', query: 'amatike', title: 'Amatike y’umukino'),
      ]) {
        final response = await repository.search(
          DiscoverySearchQuery(
            text: testCase.query,
            category: DiscoveryCategory.commerce,
            localeName: testCase.locale,
          ),
        );

        expect(
          response.results.map((result) => result.title),
          contains(testCase.title),
          reason: 'Search catalog did not resolve ${testCase.locale}.',
        );
      }
    });
  });

  group('FederatedDiscoverySearchRepository', () {
    test('merges live public content before local destinations', () async {
      const repository = FederatedDiscoverySearchRepository(
        local: LocalDiscoverySearchRepository(),
        liveSources: <DiscoverySearchSource>[
          _StaticSource(<DiscoveryResult>[
            DiscoveryResult(
              id: 'fixture-live',
              title: 'Rayon Sports vs APR',
              description: 'Live fixture from the active club.',
              category: DiscoveryCategory.fixtures,
              destination: '/fanzone/match/fixture-live',
              icon: AfriIcons.fixture,
            ),
          ]),
        ],
      );

      final response = await repository.search(
        const DiscoverySearchQuery(text: 'match'),
      );

      expect(response.offline, isFalse);
      expect(response.results.first.id, 'fixture-live');
      expect(
        response.results.length,
        lessThanOrEqualTo(LocalDiscoverySearchRepository.maxResults),
      );
    });

    test(
      'keeps bounded local results and marks total live failure offline',
      () async {
        final repository = FederatedDiscoverySearchRepository(
          local: const LocalDiscoverySearchRepository(),
          liveSources: <DiscoverySearchSource>[_FailingSource()],
        );

        final response = await repository.search(
          const DiscoverySearchQuery(text: 'ticket'),
        );

        expect(response.offline, isTrue);
        expect(
          response.results.map((result) => result.id),
          contains('tickets'),
        );
        expect(
          response.results.length,
          lessThanOrEqualTo(LocalDiscoverySearchRepository.maxResults),
        );
      },
    );

    test('only counts sources supporting the selected category', () async {
      final repository = FederatedDiscoverySearchRepository(
        local: const LocalDiscoverySearchRepository(),
        liveSources: <DiscoverySearchSource>[
          _CategorySource(
            category: DiscoveryCategory.fixtures,
            error: StateError('fixture source unavailable'),
          ),
          const _CategorySource(
            category: DiscoveryCategory.commerce,
            results: <DiscoveryResult>[],
          ),
        ],
      );

      final response = await repository.search(
        const DiscoverySearchQuery(
          text: 'match',
          category: DiscoveryCategory.fixtures,
        ),
      );

      expect(response.offline, isTrue);
      expect(
        response.results.every(
          (result) => result.category == DiscoveryCategory.fixtures,
        ),
        isTrue,
      );
    });
  });

  group('RecentDiscoverySearchesNotifier', () {
    test('persists, deduplicates, bounds, and clears recent terms', () async {
      final store = _MemoryRecentSearchStore();
      var container = ProviderContainer(
        overrides: <Override>[
          recentDiscoverySearchStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(() => container.dispose());

      expect(
        await container.read(recentDiscoverySearchesProvider.future),
        isEmpty,
      );
      for (final query in <String>[
        'tickets',
        'fixtures',
        'wallet',
        'shop',
        'supporters',
        'TICKETS',
      ]) {
        await container
            .read(recentDiscoverySearchesProvider.notifier)
            .add(query);
      }
      expect(
        container.read(recentDiscoverySearchesProvider).requireValue,
        <String>['TICKETS', 'supporters', 'shop', 'wallet', 'fixtures'],
      );

      container.dispose();
      container = ProviderContainer(
        overrides: <Override>[
          recentDiscoverySearchStoreProvider.overrideWithValue(store),
        ],
      );
      expect(
        await container.read(recentDiscoverySearchesProvider.future),
        <String>['TICKETS', 'supporters', 'shop', 'wallet', 'fixtures'],
      );

      await container.read(recentDiscoverySearchesProvider.notifier).clear();
      expect(
        container.read(recentDiscoverySearchesProvider).requireValue,
        isEmpty,
      );
      expect(store.values, isEmpty);
    });
  });

  group('SecureRecentDiscoverySearchStore', () {
    const store = SecureRecentDiscoverySearchStore();

    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
    });

    test('persists and clears only the bounded search terms', () async {
      await store.save(const <String>['fixtures', 'club shop']);
      expect(await store.load(), const <String>['fixtures', 'club shop']);

      await store.clear();
      expect(await store.load(), isEmpty);
    });

    test('fails closed for malformed protected storage', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        SecureRecentDiscoverySearchStore.storageKey: '{"not":"a list"}',
      });

      expect(await store.load(), isEmpty);
    });
  });

  group('DiscoverySearchScreen', () {
    testWidgets(
      'renders start, results, no-results, and recent-search states',
      (tester) async {
        await tester.pumpWidget(_buildSearchApp());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('discovery-search-start')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey<String>('discovery-search-input')),
          'ticket',
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        expect(find.text('Match tickets'), findsOneWidget);
        expect(find.text('My tickets'), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey<String>('discovery-search-input')),
          'not-a-real-destination',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey<String>('discovery-search-empty')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const ValueKey<String>('discovery-search-input')),
          '',
        );
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
        expect(find.text('not-a-real-destination'), findsOneWidget);
        expectTapTargetsMeetMinimum(tester);
      },
    );

    testWidgets('renders error with retry and offline results', (tester) async {
      final repository = _SequencedRepository(<Object>[
        StateError('simulated search failure'),
        const DiscoverySearchResponse(
          offline: true,
          results: <DiscoveryResult>[
            DiscoveryResult(
              id: 'help',
              title: 'Help and support',
              description: 'Safe offline destination.',
              category: DiscoveryCategory.services,
              destination: '/settings',
              icon: AfriIcons.help,
            ),
          ],
        ),
      ]);
      await tester.pumpWidget(_buildSearchApp(repository: repository));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('discovery-search-input')),
        'help',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('discovery-search-error')),
        findsOneWidget,
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('discovery-search-offline')),
        findsOneWidget,
      );
      expect(find.text('Help and support'), findsOneWidget);
    });

    testWidgets('opens the destination selected from a search result', (
      tester,
    ) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey<String>('discovery-search-input')),
        'match tickets',
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Match tickets'));
      await tester.pumpAndSettle();

      expect(find.text('Tickets destination'), findsOneWidget);
    });

    testWidgets('remains usable at compact width and 200 percent text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final repository = _SequencedRepository(<Object>[
        StateError('simulated search failure'),
      ]);
      await tester.pumpWidget(_buildSearchApp(repository: repository));
      await tester.pumpAndSettle();

      final input = find.byKey(
        const ValueKey<String>('discovery-search-input'),
      );
      await tester.enterText(input, 'help');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      final error = find.byKey(
        const ValueKey<String>('discovery-search-error'),
      );
      final retry = find.text('Retry');
      await tester.ensureVisible(error);
      await tester.ensureVisible(retry);
      expect(input, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'renders localized EN, FR, and RW Search at compact 200 percent text',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        for (final testCase
            in <
              ({Locale locale, String title, String query, String resultTitle})
            >[
              (
                locale: const Locale('en'),
                title: 'Search',
                query: 'tickets',
                resultTitle: 'Match tickets',
              ),
              (
                locale: const Locale('fr'),
                title: 'Chercher',
                query: 'billets',
                resultTitle: 'Billets de match',
              ),
              (
                locale: const Locale('rw'),
                title: 'Shakisha',
                query: 'amatike',
                resultTitle: 'Amatike y’umukino',
              ),
            ]) {
          await tester.pumpWidget(
            _buildSearchApp(appCopyLocale: testCase.locale),
          );
          await tester.pumpAndSettle();

          expect(find.text(testCase.title.toUpperCase()), findsOneWidget);
          await tester.enterText(
            find.byKey(const ValueKey<String>('discovery-search-input')),
            testCase.query,
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          expect(find.text(testCase.resultTitle), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'keyboard-open search keeps input, clear, error, and retry reachable',
      (tester) async {
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final repository = _SequencedRepository(<Object>[
          StateError('simulated search failure'),
        ]);

        await tester.pumpWidget(_buildSearchApp(repository: repository));
        await tester.pumpAndSettle();

        final input = find.byKey(
          const ValueKey<String>('discovery-search-input'),
        );
        await tester.showKeyboard(input);
        await tester.enterText(input, 'help');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();

        final clear = find.byTooltip('Clear search');
        _expectInKeyboardViewport(tester, input);
        _expectInKeyboardViewport(tester, clear);

        final error = find.byKey(
          const ValueKey<String>('discovery-search-error'),
        );
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        _expectInKeyboardViewport(tester, error);
        _expectInKeyboardViewport(tester, find.text('Retry'));
        expect(tester.takeException(), isNull);
      },
    );

    for (final profile in <String, Size>{
      'standard landscape': const Size(852, 393),
      'compact-height landscape': const Size(720, 320),
    }.entries) {
      testWidgets(
        '${profile.key} keeps search input, error, and retry usable',
        (tester) async {
          tester.view.physicalSize = profile.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final repository = _SequencedRepository(<Object>[
            StateError('simulated search failure'),
          ]);

          await tester.pumpWidget(_buildSearchApp(repository: repository));
          await tester.pumpAndSettle();
          final input = find.byKey(
            const ValueKey<String>('discovery-search-input'),
          );
          await tester.enterText(input, 'help');
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpAndSettle();

          final error = find.byKey(
            const ValueKey<String>('discovery-search-error'),
          );
          final retry = find.text('Retry');
          await tester.ensureVisible(input);
          await tester.ensureVisible(error);
          await tester.ensureVisible(retry);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  for (final profile in _compactGoldenProfiles) {
    testWidgets('golden compact Search route ${profile.id}', (tester) async {
      TypographyTokens.debugUseFallbackFonts = true;
      addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
      EditableText.debugDeterministicCursor = true;
      addTearDown(() => EditableText.debugDeterministicCursor = false);
      ColorTokens.setBrightness(profile.brightness);
      addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
      _setGoldenSurface(tester, profile.size);

      await tester.pumpWidget(
        _buildSearchApp(
          brightness: profile.brightness,
          goldenKey: const ValueKey<String>('search-route-golden'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey<String>('search-route-golden')),
        matchesGoldenFile('goldens/search_${profile.id}.png'),
      );
    });
  }

  for (final testCase in <({String id, Locale locale, String expectedTitle})>[
    (id: 'en', locale: const Locale('en'), expectedTitle: 'SEARCH'),
    (id: 'fr', locale: const Locale('fr'), expectedTitle: 'CHERCHER'),
    (id: 'rw', locale: const Locale('rw'), expectedTitle: 'SHAKISHA'),
  ]) {
    testWidgets(
      'golden localized Search ${testCase.id} at compact 200 percent text',
      (tester) async {
        TypographyTokens.debugUseFallbackFonts = true;
        addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
        EditableText.debugDeterministicCursor = true;
        addTearDown(() => EditableText.debugDeterministicCursor = false);
        ColorTokens.setBrightness(Brightness.dark);
        addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
        _setGoldenSurface(tester, const Size(320, 760));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          _buildSearchApp(
            appCopyLocale: testCase.locale,
            goldenKey: const ValueKey<String>('search-localized-golden'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(testCase.expectedTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey<String>('search-localized-golden')),
          matchesGoldenFile(
            'goldens/search_locale_${testCase.id}_large_text_dark_320x760.png',
          ),
        );
      },
    );
  }

  for (final state in const <String>['loading', 'empty', 'error', 'offline']) {
    testWidgets('golden Search route $state state', (tester) async {
      final repository = switch (state) {
        'loading' => _PendingRepository(),
        'empty' => _SequencedRepository(const <Object>[
          DiscoverySearchResponse(results: <DiscoveryResult>[]),
        ]),
        'error' => _SequencedRepository(<Object>[
          StateError('simulated search failure'),
        ]),
        'offline' => _SequencedRepository(const <Object>[
          DiscoverySearchResponse(
            offline: true,
            results: <DiscoveryResult>[
              DiscoveryResult(
                id: 'help',
                title: 'Help and support',
                description: 'Support information stored on this device.',
                category: DiscoveryCategory.services,
                destination: '/settings',
                icon: AfriIcons.help,
              ),
            ],
          ),
        ]),
        _ => throw StateError('Unsupported Search golden state: $state'),
      };

      await _pumpGoldenSearch(
        tester,
        size: const Size(390, 844),
        repository: repository,
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('discovery-search-input')),
        state == 'empty' ? 'no-match' : 'help',
      );
      await tester.pump(const Duration(milliseconds: 300));
      if (state == 'loading') {
        await tester.pump();
      } else {
        await tester.pumpAndSettle();
      }

      expect(
        find.byKey(ValueKey<String>('discovery-search-$state')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey<String>('search-route-state-golden')),
        matchesGoldenFile('goldens/search_state_${state}_dark_390x844.png'),
      );
      if (state == 'loading') {
        await tester.pump(const Duration(seconds: 13));
      }
    });
  }

  testWidgets('golden Search route large-text state', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpGoldenSearch(tester, size: const Size(320, 720));

    expect(
      find.byKey(const ValueKey<String>('discovery-search-start')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile('goldens/search_state_large_text_dark_320x720.png'),
    );
  });

  testWidgets('golden Search route focused state', (tester) async {
    await _pumpGoldenSearch(tester, size: const Size(390, 844));
    await tester.tap(
      find.byKey(const ValueKey<String>('discovery-search-input')),
    );
    await tester.pump();

    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile('goldens/search_state_focused_dark_390x844.png'),
    );
  });

  testWidgets('golden Search route selected state', (tester) async {
    await _pumpGoldenSearch(tester, size: const Size(390, 844));
    await tester.tap(find.text('Supporters'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AfriSegmentedControl>(find.byType(AfriSegmentedControl))
          .selectedIndex,
      DiscoveryCategory.values.indexOf(DiscoveryCategory.supporters),
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile('goldens/search_state_selected_dark_390x844.png'),
    );
  });

  testWidgets('golden Search route disabled state', (tester) async {
    await _pumpGoldenSearch(tester, size: const Size(390, 844));
    await tester.enterText(
      find.byKey(const ValueKey<String>('discovery-search-input')),
      'a',
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('discovery-search-disabled')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile('goldens/search_state_disabled_dark_390x844.png'),
    );
  });

  testWidgets('golden Search route pressed state', (tester) async {
    final repository = _SequencedRepository(const <Object>[
      DiscoverySearchResponse(
        results: <DiscoveryResult>[
          DiscoveryResult(
            id: 'help',
            title: 'Help and support',
            description: 'Open support information.',
            category: DiscoveryCategory.services,
            destination: '/settings',
            icon: AfriIcons.help,
          ),
        ],
      ),
    ]);
    await _pumpGoldenSearch(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );
    await _enterSearch(tester, 'help');
    final result = find.text('Help and support');
    final heldGesture = await tester.startGesture(tester.getCenter(result));
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile('goldens/search_state_pressed_dark_390x844.png'),
    );
    await heldGesture.up();
  });

  testWidgets('golden Search route permission-denied state', (tester) async {
    final repository = _SequencedRepository(<Object>[
      StateError('permission denied by tenant policy for account 491'),
    ]);
    await _pumpGoldenSearch(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );
    await _enterSearch(tester, 'help');

    expect(
      find.byKey(const ValueKey<String>('discovery-search-permission-denied')),
      findsOneWidget,
    );
    expect(find.textContaining('account 491'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile(
        'goldens/search_state_permission_denied_dark_390x844.png',
      ),
    );
  });

  testWidgets('golden Search route syncing state', (tester) async {
    final repository = _SyncingRepository();
    await _pumpGoldenSearch(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );
    await _enterSearch(tester, 'help');
    await tester.enterText(
      find.byKey(const ValueKey<String>('discovery-search-input')),
      'support',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('discovery-search-syncing')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile('goldens/search_state_syncing_dark_390x844.png'),
    );

    repository.completePending();
    await tester.pumpAndSettle();
  });

  testWidgets('golden Search route conflict state', (tester) async {
    final repository = _SequencedRepository(<Object>[
      StateError('search conflict includes private revision 491'),
    ]);
    await _pumpGoldenSearch(
      tester,
      size: const Size(390, 844),
      repository: repository,
    );
    await _enterSearch(tester, 'help');

    expect(
      find.byKey(const ValueKey<String>('discovery-search-conflict')),
      findsOneWidget,
    );
    expect(find.textContaining('revision 491'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile('goldens/search_state_conflict_dark_390x844.png'),
    );
  });

  testWidgets('golden Search route security-timeout state', (tester) async {
    await _pumpGoldenSearch(
      tester,
      size: const Size(390, 844),
      repository: _PendingRepository(),
      searchTimeout: const Duration(milliseconds: 20),
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('discovery-search-input')),
      'help',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('discovery-search-security-timeout')),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey<String>('search-route-state-golden')),
      matchesGoldenFile(
        'goldens/search_state_security_timeout_dark_390x844.png',
      ),
    );
  });
}

void _expectInKeyboardViewport(WidgetTester tester, Finder finder) {
  final visibleBottom =
      tester.view.physicalSize.height / tester.view.devicePixelRatio -
      tester.view.viewInsets.bottom;
  final rect = tester.getRect(finder);
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(visibleBottom));
}

Widget _buildSearchApp({
  DiscoverySearchRepository? repository,
  Duration? searchTimeout,
  Brightness brightness = Brightness.dark,
  Locale appCopyLocale = const Locale('en'),
  Key? goldenKey,
}) {
  final router = GoRouter(
    initialLocation: '/search',
    routes: <RouteBase>[
      GoRoute(
        path: '/search',
        builder: (context, state) => RepaintBoundary(
          key: goldenKey,
          child: const DiscoverySearchScreen(),
        ),
      ),
      GoRoute(
        path: '/tickets',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Tickets destination'))),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Settings destination'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: <Override>[
      discoverySearchRepositoryProvider.overrideWithValue(
        repository ?? const LocalDiscoverySearchRepository(),
      ),
      recentDiscoverySearchStoreProvider.overrideWithValue(
        _MemoryRecentSearchStore(),
      ),
      if (searchTimeout != null)
        discoverySearchTimeoutProvider.overrideWithValue(searchTimeout),
    ],
    child: MaterialApp.router(
      theme: ClubTheme.from(ClubConfig.fallback(), brightness: brightness),
      routerConfig: router,
      builder: (context, child) => AfriLocalizationsScope(
        locale: appCopyLocale,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
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
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        accessibleNavigation: true,
      );
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Future<void> _pumpGoldenSearch(
  WidgetTester tester, {
  required Size size,
  DiscoverySearchRepository? repository,
  Duration? searchTimeout,
}) async {
  TypographyTokens.debugUseFallbackFonts = true;
  addTearDown(() => TypographyTokens.debugUseFallbackFonts = false);
  EditableText.debugDeterministicCursor = true;
  addTearDown(() => EditableText.debugDeterministicCursor = false);
  ColorTokens.setBrightness(Brightness.dark);
  addTearDown(() => ColorTokens.setBrightness(Brightness.dark));
  _setGoldenSurface(tester, size);
  await tester.pumpWidget(
    _buildSearchApp(
      repository: repository,
      searchTimeout: searchTimeout,
      goldenKey: const ValueKey<String>('search-route-state-golden'),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _enterSearch(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const ValueKey<String>('discovery-search-input')),
    query,
  );
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

class _StaticSource implements DiscoverySearchSource {
  const _StaticSource(this.results);

  final List<DiscoveryResult> results;

  @override
  bool supports(DiscoverySearchQuery query) => true;

  @override
  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query) async {
    return results;
  }
}

class _FailingSource implements DiscoverySearchSource {
  @override
  bool supports(DiscoverySearchQuery query) => true;

  @override
  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query) async {
    throw StateError('simulated live source failure');
  }
}

class _CategorySource implements DiscoverySearchSource {
  const _CategorySource({
    required this.category,
    this.results = const <DiscoveryResult>[],
    this.error,
  });

  final DiscoveryCategory category;
  final List<DiscoveryResult> results;
  final Object? error;

  @override
  bool supports(DiscoverySearchQuery query) {
    return query.category == DiscoveryCategory.all ||
        query.category == category;
  }

  @override
  Future<List<DiscoveryResult>> search(DiscoverySearchQuery query) async {
    if (error case final Object error) {
      throw error;
    }
    return results;
  }
}

class _MemoryRecentSearchStore implements RecentDiscoverySearchStore {
  List<String> values = const <String>[];

  @override
  Future<void> clear() async {
    values = const <String>[];
  }

  @override
  Future<List<String>> load() async => List<String>.from(values);

  @override
  Future<void> save(List<String> searches) async {
    values = List<String>.from(searches);
  }
}

class _SequencedRepository implements DiscoverySearchRepository {
  _SequencedRepository(this.responses);

  final List<Object> responses;
  int _index = 0;

  @override
  Future<DiscoverySearchResponse> search(DiscoverySearchQuery query) async {
    final response = responses[_index.clamp(0, responses.length - 1)];
    _index += 1;
    if (response is Error) {
      throw response;
    }
    return response as DiscoverySearchResponse;
  }
}

class _PendingRepository implements DiscoverySearchRepository {
  @override
  Future<DiscoverySearchResponse> search(DiscoverySearchQuery query) {
    return Completer<DiscoverySearchResponse>().future;
  }
}

class _SyncingRepository implements DiscoverySearchRepository {
  final Completer<DiscoverySearchResponse> _pending =
      Completer<DiscoverySearchResponse>();
  var _calls = 0;

  @override
  Future<DiscoverySearchResponse> search(DiscoverySearchQuery query) {
    _calls += 1;
    if (_calls == 1) {
      return Future<DiscoverySearchResponse>.value(
        const DiscoverySearchResponse(
          results: <DiscoveryResult>[
            DiscoveryResult(
              id: 'help',
              title: 'Help and support',
              description: 'Open support information.',
              category: DiscoveryCategory.services,
              destination: '/settings',
              icon: AfriIcons.help,
            ),
          ],
        ),
      );
    }
    return _pending.future;
  }

  void completePending() {
    if (_pending.isCompleted) {
      return;
    }
    _pending.complete(
      const DiscoverySearchResponse(results: <DiscoveryResult>[]),
    );
  }
}
