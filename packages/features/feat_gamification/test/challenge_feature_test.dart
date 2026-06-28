import 'package:core_theme/core_theme.dart';
import 'package:feat_gamification/src/fet_providers.dart';
import 'package:feat_gamification/src/models/challenge_models.dart';
import 'package:feat_gamification/src/models/prediction_models.dart';
import 'package:feat_gamification/src/prediction_providers.dart';
import 'package:feat_gamification/src/screens/challenge_detail_screen.dart';
import 'package:feat_gamification/src/screens/challenge_feed_screen.dart';
import 'package:feat_gamification/src/screens/create_challenge_screen.dart';
import 'package:feat_gamification/src/screens/my_challenges_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'challenge_test_helpers.dart';

Future<void> _scrollTo(
  WidgetTester tester,
  Finder finder, {
  double delta = 300,
  int maxScrolls = 8,
}) async {
  final scrollable = find.byType(Scrollable).first;
  var scrolls = 0;

  while (finder.evaluate().isEmpty && scrolls < maxScrolls) {
    await tester.drag(scrollable, Offset(0, -delta));
    await tester.pumpAndSettle();
    scrolls += 1;
  }

  if (finder.evaluate().isEmpty) {
    throw TestFailure('Could not find the requested widget after scrolling.');
  }

  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Challenge feature widgets', () {
    testWidgets(
      'feed hides challenge list section when no pools are available',
      (tester) async {
        final challengeRepository = FakeChallengeRepository();

        await pumpTestWidget(
          tester,
          child: const ChallengeFeedScreen(),
          overrides: <Override>[
            challengeRepositoryProvider.overrideWithValue(challengeRepository),
          ],
        );

        expect(find.text('No challenges yet'), findsNothing);
        expect(find.text('CREATE A NEW CHALLENGE'), findsOneWidget);
      },
    );

    testWidgets('feed renders featured, open, mine, and settled sections', (
      tester,
    ) async {
      final fixture = buildFixture(homeTeamShort: 'RAY', awayTeamShort: 'APR');
      final challengeRepository = FakeChallengeRepository()
        ..featuredChallenges = <Challenge>[
          buildChallenge(
            id: 'featured',
            fixture: fixture,
            totalParticipants: 8,
            totalPoolFet: 24000,
          ),
        ]
        ..openChallenges = <Challenge>[
          buildChallenge(
            id: 'open',
            fixture: buildFixture(
              id: 'fixture-open',
              homeTeamShort: 'KIG',
              awayTeamShort: 'MUS',
            ),
          ),
        ]
        ..myOpenChallenges = <Challenge>[
          buildChallenge(
            id: 'mine',
            fixture: buildFixture(
              id: 'fixture-mine',
              homeTeamShort: 'GAS',
              awayTeamShort: 'ETO',
            ),
            permissions: const ChallengePermissions(hasJoined: true),
            myEntry: buildEntry(challengeId: 'mine', userName: 'Me'),
          ),
        ]
        ..settledChallenges = <Challenge>[
          buildChallenge(
            id: 'settled',
            fixture: buildFixture(
              id: 'fixture-settled',
              homeTeamShort: 'POL',
              awayTeamShort: 'BUG',
              status: 'finished',
              homeScore: 2,
              awayScore: 1,
            ),
            status: ChallengeStatus.settled,
            settlement: buildSettlement(
              challengeId: 'settled',
              matchId: 'fixture-settled',
            ),
            permissions: const ChallengePermissions(hasJoined: true),
            myEntry: buildEntry(
              challengeId: 'settled',
              status: ChallengeEntryStatus.winner,
              payoutFet: 9000,
              userName: 'Me',
            ),
          ),
        ];

      await pumpTestWidget(
        tester,
        child: const ChallengeFeedScreen(),
        overrides: <Override>[
          challengeRepositoryProvider.overrideWithValue(challengeRepository),
        ],
      );

      expect(find.text('Featured / Popular Challenges'), findsOneWidget);
      expect(find.text('RAY'), findsOneWidget);
      await _scrollTo(tester, find.text('Open Challenges'));
      expect(find.text('Open Challenges'), findsOneWidget);
      await _scrollTo(tester, find.text('My Challenges'));
      expect(find.text('My Challenges'), findsOneWidget);
      await _scrollTo(tester, find.text('Settled Challenges'));
      expect(find.text('Settled Challenges'), findsOneWidget);
      await _scrollTo(tester, find.text('GAS'));
      expect(find.text('GAS'), findsOneWidget);
      await _scrollTo(tester, find.text('POL'));
      expect(find.text('POL'), findsOneWidget);
    });

    testWidgets('create screen shows insufficient balance state', (
      tester,
    ) async {
      final fixturesGateway = FakeChallengeFixturesGateway(
        fixtures: <FixtureSummary>[buildFixture()],
      );
      final fetRepository = FakeFetRepository()
        ..wallet = buildWallet(balance: 250);
      final challengeRepository = FakeChallengeRepository();

      await pumpTestWidget(
        tester,
        child: const CreateChallengeScreen(),
        overrides: <Override>[
          challengeFixturesGatewayProvider.overrideWithValue(fixturesGateway),
          fetRepositoryProvider.overrideWithValue(fetRepository),
          challengeRepositoryProvider.overrideWithValue(challengeRepository),
        ],
      );

      await _scrollTo(
        tester,
        find.text('Your current FET balance does not cover this stake.'),
      );
      expect(
        find.text('Your current FET balance does not cover this stake.'),
        findsOneWidget,
      );

      final createButton = find.widgetWithText(AfriButton, 'CREATE CHALLENGE');
      await _scrollTo(tester, createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      expect(find.text('CONFIRM CHALLENGE'), findsNothing);
      expect(challengeRepository.lastCreateRequest, isNull);
    });

    testWidgets('create screen confirms submission and navigates to detail', (
      tester,
    ) async {
      final fixture = buildFixture();
      final fixturesGateway = FakeChallengeFixturesGateway(
        fixtures: <FixtureSummary>[fixture],
      );
      final fetRepository = FakeFetRepository()
        ..wallet = buildWallet(balance: 8000);
      final challengeRepository = FakeChallengeRepository()
        ..createResult = ChallengeMutationResult(
          status: 'created',
          challenge: buildChallenge(
            id: 'challenge-created',
            fixture: fixture,
            permissions: const ChallengePermissions(isCreator: true),
          ),
        );

      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (context, state) => const CreateChallengeScreen(),
          ),
          GoRoute(
            path: '/challenge/:id',
            builder: (context, state) =>
                Text('Detail ${state.pathParameters['id']}'),
          ),
        ],
      );

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            challengeFixturesGatewayProvider.overrideWithValue(fixturesGateway),
            fetRepositoryProvider.overrideWithValue(fetRepository),
            challengeRepositoryProvider.overrideWithValue(challengeRepository),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final createButton = find.widgetWithText(AfriButton, 'CREATE CHALLENGE');
      await _scrollTo(tester, createButton);
      await tester.tap(createButton);
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM CHALLENGE'), findsOneWidget);

      final lockButton = find.widgetWithText(AfriButton, 'LOCK 1000 FET');
      await _scrollTo(tester, lockButton);
      await tester.tap(lockButton);
      await tester.pumpAndSettle();

      expect(challengeRepository.lastCreateRequest?['matchId'], fixture.id);
      expect(challengeRepository.lastCreateRequest?['homeScore'], 2);
      expect(challengeRepository.lastCreateRequest?['awayScore'], 1);
      expect(challengeRepository.lastCreateRequest?['stakeFet'], 1000);
      expect(find.text('Detail challenge-created'), findsOneWidget);
    });

    testWidgets('detail screen renders settled outcome for current user', (
      tester,
    ) async {
      final settledFixture = buildFixture(
        id: 'fixture-settled',
        homeTeamShort: 'RAY',
        awayTeamShort: 'APR',
        status: 'finished',
        homeScore: 2,
        awayScore: 1,
      );
      final myEntry = buildEntry(
        challengeId: 'settled-challenge',
        status: ChallengeEntryStatus.winner,
        payoutFet: 9000,
        userName: 'Jeanne Mukamana',
      );
      final settlement = buildSettlement(
        challengeId: 'settled-challenge',
        matchId: settledFixture.id,
        payoutPerWinnerFet: 9000,
      );
      final challenge = buildChallenge(
        id: 'settled-challenge',
        fixture: settledFixture,
        status: ChallengeStatus.settled,
        myEntry: myEntry,
        permissions: const ChallengePermissions(hasJoined: true),
        settlement: settlement,
      );
      final challengeRepository = FakeChallengeRepository()
        ..detailsById['settled-challenge'] = buildDetail(
          challenge: challenge,
          entries: <ChallengeEntry>[
            myEntry,
            buildEntry(
              id: 'entry-loser',
              challengeId: 'settled-challenge',
              userId: 'supporter-2',
              homeScore: 3,
              awayScore: 1,
              status: ChallengeEntryStatus.loser,
              userName: 'Aimable',
            ),
          ],
        );

      await pumpTestWidget(
        tester,
        child: const ChallengeDetailScreen(id: 'settled-challenge'),
        overrides: <Override>[
          challengeRepositoryProvider.overrideWithValue(challengeRepository),
        ],
      );

      await _scrollTo(tester, find.text('SETTLEMENT'));
      expect(find.text('MY PICK'), findsOneWidget);
      expect(find.text('Won 9000 FET'), findsOneWidget);
      expect(find.text('SETTLEMENT'), findsOneWidget);
      expect(find.text('Official score'), findsOneWidget);
      expect(find.text('Payout / winner'), findsOneWidget);
      await _scrollTo(tester, find.text('Aimable'));
      expect(find.text('Aimable'), findsOneWidget);
    });

    testWidgets('detail screen joins an open challenge', (tester) async {
      final challenge = buildChallenge(
        id: 'joinable',
        permissions: const ChallengePermissions(canJoin: true),
      );
      final challengeRepository = FakeChallengeRepository()
        ..detailsById['joinable'] = buildDetail(
          challenge: challenge,
          entries: <ChallengeEntry>[
            buildEntry(
              challengeId: 'joinable',
              userId: challenge.creatorUserId,
              userName: challenge.creatorDisplayName,
            ),
          ],
        )
        ..joinResult = ChallengeMutationResult(
          status: 'joined',
          challenge: buildChallenge(
            id: 'joinable',
            permissions: const ChallengePermissions(hasJoined: true),
            myEntry: buildEntry(
              challengeId: 'joinable',
              userId: 'supporter-1',
              userName: 'Jeanne Mukamana',
            ),
          ),
        );

      await pumpTestWidget(
        tester,
        child: const ChallengeDetailScreen(id: 'joinable'),
        overrides: <Override>[
          challengeRepositoryProvider.overrideWithValue(challengeRepository),
        ],
      );

      await _scrollTo(tester, find.text('JOIN FOR 3000 FET'));
      await tester.tap(find.text('JOIN FOR 3000 FET'));
      await tester.pumpAndSettle();

      expect(challengeRepository.lastJoinRequest?['challengeId'], 'joinable');
      expect(challengeRepository.lastJoinRequest?['homeScore'], 1);
      expect(challengeRepository.lastJoinRequest?['awayScore'], 0);
      expect(find.text('Challenge joined successfully.'), findsOneWidget);
    });

    testWidgets('my challenges screen switches across status tabs', (
      tester,
    ) async {
      final challengeRepository = FakeChallengeRepository()
        ..myOpenChallenges = <Challenge>[
          buildChallenge(
            id: 'open-challenge',
            fixture: buildFixture(
              id: 'fixture-open',
              homeTeamShort: 'OPN',
              awayTeamShort: 'TAB',
            ),
            permissions: const ChallengePermissions(hasJoined: true),
            myEntry: buildEntry(challengeId: 'open-challenge'),
          ),
        ]
        ..myLockedChallenges = <Challenge>[
          buildChallenge(
            id: 'locked-challenge',
            fixture: buildFixture(
              id: 'fixture-locked',
              homeTeamShort: 'LOCK',
              awayTeamShort: 'TAB',
            ),
            status: ChallengeStatus.locked,
            permissions: const ChallengePermissions(hasJoined: true),
            myEntry: buildEntry(challengeId: 'locked-challenge'),
          ),
        ]
        ..mySettledChallenges = <Challenge>[
          buildChallenge(
            id: 'settled-tab-challenge',
            fixture: buildFixture(
              id: 'fixture-settled-tab',
              homeTeamShort: 'SET',
              awayTeamShort: 'TAB',
              status: 'finished',
              homeScore: 2,
              awayScore: 1,
            ),
            status: ChallengeStatus.settled,
            permissions: const ChallengePermissions(hasJoined: true),
            myEntry: buildEntry(
              challengeId: 'settled-tab-challenge',
              status: ChallengeEntryStatus.winner,
              payoutFet: 9000,
            ),
            settlement: buildSettlement(
              challengeId: 'settled-tab-challenge',
              matchId: 'fixture-settled-tab',
            ),
          ),
        ]
        ..myVoidedChallenges = <Challenge>[
          buildChallenge(
            id: 'voided-challenge',
            fixture: buildFixture(
              id: 'fixture-void',
              homeTeamShort: 'REF',
              awayTeamShort: 'TAB',
            ),
            status: ChallengeStatus.void_,
            voidReason: 'no_exact_winner',
            permissions: const ChallengePermissions(hasJoined: true),
            myEntry: buildEntry(
              challengeId: 'voided-challenge',
              status: ChallengeEntryStatus.refunded,
              payoutFet: 3000,
            ),
          ),
        ];

      await pumpTestWidget(
        tester,
        child: const MyChallengesScreen(),
        overrides: <Override>[
          challengeRepositoryProvider.overrideWithValue(challengeRepository),
        ],
      );

      expect(find.text('OPN'), findsOneWidget);

      await tester.tap(find.text('Locked'));
      await tester.pumpAndSettle();
      expect(find.text('LOCK'), findsOneWidget);

      await tester.tap(find.text('Settled'));
      await tester.pumpAndSettle();
      expect(find.text('SET'), findsOneWidget);

      await tester.tap(find.text('Refunded'));
      await tester.pumpAndSettle();
      expect(find.text('REF'), findsOneWidget);
      expect(challengeRepository.lastMyStatuses, contains('void'));
    });
  });
}
