import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../widgets/market_option_pill.dart';

class FriendChallengeScreen extends ConsumerStatefulWidget {
  const FriendChallengeScreen({super.key});

  @override
  ConsumerState<FriendChallengeScreen> createState() =>
      _FriendChallengeScreenState();
}

class _FriendChallengeScreenState extends ConsumerState<FriendChallengeScreen> {
  List<FetLeaderboardRow> _supporters = const <FetLeaderboardRow>[];
  List<_ChallengeFixture> _fixtures = const <_ChallengeFixture>[];
  FetLeaderboardRow? _selectedSupporter;
  _ChallengeFixture? _selectedFixture;
  String? _selectedOutcome;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final predictionRepo = ref.read(predictionRepositoryProvider);
      final fetRepo = ref.read(fetRepositoryProvider);
      final leaders = await fetRepo.loadLeaderboard(limit: 8);
      final now = DateTime.now();
      final weekLater = now.add(const Duration(days: 7));
      final dateFrom = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final dateTo = '${weekLater.year}-${weekLater.month.toString().padLeft(2, '0')}-${weekLater.day.toString().padLeft(2, '0')}';

      final fixtures = await predictionRepo.loadFixturesByDate(
        dateFrom: dateFrom,
        dateTo: dateTo,
        status: 'scheduled',
        limit: 5,
      );
      final marketResults = await Future.wait<List<FixtureMarket>>(
        fixtures.map(
          (fixture) => predictionRepo.loadFixtureMarkets(fixture.id),
        ),
      );
      final challengeFixtures = <_ChallengeFixture>[];
      for (var index = 0; index < fixtures.length; index++) {
        final market = marketResults[index].cast<FixtureMarket?>().firstWhere(
          (entry) =>
              entry != null &&
              entry.outcomes.isNotEmpty &&
              entry.marketGroup == MarketGroup.matchResult,
          orElse: () => null,
        );
        if (market != null) {
          challengeFixtures.add(
            _ChallengeFixture(fixture: fixtures[index], market: market),
          );
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _supporters = leaders
            .where((entry) => !entry.isCurrentUser)
            .toList(growable: false);
        _fixtures = challengeFixtures;
        _selectedSupporter = _supporters.isEmpty ? null : _supporters.first;
        _selectedFixture = challengeFixtures.isEmpty
            ? null
            : challengeFixtures.first;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Challenge flow is temporarily unavailable.';
      });
    }
  }

  Future<void> _copyInvite() async {
    final supporter = _selectedSupporter;
    final fixture = _selectedFixture;
    final outcome = _selectedOutcome;
    if (supporter == null || fixture == null || outcome == null) {
      return;
    }

    final text =
        'FANZONE challenge: @${supporter.supporterAlias} take me on in ${fixture.fixture.homeTeamShort} vs ${fixture.fixture.awayTeamShort}. '
        'I’m backing ${outcome.toUpperCase()} on ${fixture.market.marketShortName.isEmpty ? fixture.market.marketName : fixture.market.marketShortName}.';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Challenge invite copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'FRIEND CHALLENGE',
          style: TypographyTokens.monolithFont(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            0,
            SpacingTokens.spacing6,
            SpacingTokens.spacing6,
          ),
          child: AfriButton(
            onTap:
                _selectedSupporter != null &&
                    _selectedFixture != null &&
                    _selectedOutcome != null
                ? _copyInvite
                : () {},
            label: 'Copy Challenge Invite',
            enabled:
                _selectedSupporter != null &&
                _selectedFixture != null &&
                _selectedOutcome != null,
          ),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Challenge unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              children: [
                ClayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HEAD-TO-HEAD INVITE',
                        style: TypographyTokens.titleLarge(),
                      ),
                      const SizedBox(height: SpacingTokens.spacing3),
                      Text(
                        'Choose a supporter, pick a fixture, and generate a direct FANZONE challenge invite.',
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                ClayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SUPPORTER', style: TypographyTokens.titleLarge()),
                      const SizedBox(height: SpacingTokens.spacing3),
                      Wrap(
                        spacing: SpacingTokens.spacing2,
                        runSpacing: SpacingTokens.spacing2,
                        children: _supporters
                            .map((supporter) {
                              final selected =
                                  supporter.userId ==
                                  _selectedSupporter?.userId;
                              return AfriPressFeedback(
                                onTap: () => setState(
                                  () => _selectedSupporter = supporter,
                                ),
                                builder: (context, _) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: SpacingTokens.spacing3,
                                    vertical: SpacingTokens.spacing2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? ColorTokens.clubAccent.withValues(
                                            alpha: 0.16,
                                          )
                                        : ColorTokens.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    supporter.displayName,
                                    style: TypographyTokens.labelSmall(
                                      selected
                                          ? ColorTokens.clubAccent
                                          : ColorTokens.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                ClayCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FIXTURE', style: TypographyTokens.titleLarge()),
                      const SizedBox(height: SpacingTokens.spacing3),
                      ..._fixtures.map((fixture) {
                        final selected =
                            fixture.fixture.id == _selectedFixture?.fixture.id;
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing3,
                          ),
                          child: AfriPressFeedback(
                            onTap: () => setState(() {
                              _selectedFixture = fixture;
                              _selectedOutcome = null;
                            }),
                            builder: (context, _) => GlassCard(
                              animate: false,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      fixture.fixture.fixtureLabel,
                                      style: TypographyTokens.titleSmall(),
                                    ),
                                  ),
                                  Text(
                                    selected ? 'Selected' : 'Open',
                                    style: TypographyTokens.labelSmall(
                                      selected
                                          ? ColorTokens.clubAccent
                                          : ColorTokens.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (_selectedFixture != null) ...[
                  const SizedBox(height: SpacingTokens.spacing4),
                  ClayCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('YOUR PICK', style: TypographyTokens.titleLarge()),
                        const SizedBox(height: SpacingTokens.spacing3),
                        Wrap(
                          spacing: SpacingTokens.spacing2,
                          runSpacing: SpacingTokens.spacing2,
                          children: _selectedFixture!.market.outcomes
                              .map((outcome) {
                                return MarketOptionPill(
                                  label: outcome.label,
                                  isSelected: _selectedOutcome == outcome.key,
                                  onTap: () => setState(() {
                                    _selectedOutcome = outcome.key;
                                  }),
                                );
                              })
                              .toList(growable: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ChallengeFixture {
  const _ChallengeFixture({required this.fixture, required this.market});

  final FixtureSummary fixture;
  final FixtureMarket market;
}
