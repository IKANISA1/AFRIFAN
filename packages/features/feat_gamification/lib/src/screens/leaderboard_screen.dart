import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/fet_models.dart';
import '../models/prediction_models.dart';
import '../prediction_providers.dart';
import '../providers/leaderboard_provider.dart';
import '../repositories/prediction_repository.dart';
import '../widgets/leaderboard_widgets.dart';
/// Dual-tab leaderboard: FET ranking (fans) and Supporters ranking.
///
/// Uses [FetLeaderboardNotifier] and [SupporterLeaderboardNotifier] via
/// Riverpod for async state management. Keeps `ConsumerStatefulWidget`
/// only for the TabController's vsync requirement.
///
/// Accepts an optional `tab` query parameter:
///   - `?tab=fet` — opens on the FET tab (default)
///   - `?tab=supporters` — opens on the Supporters tab
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key, this.initialTab});

  /// Optional initial tab from deep-link query parameter.
  final String? initialTab;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _topTabController;

  /// Local-only UI state for the period filter chip selection.
  int _fetPeriodIndex = 0; // 0=all, 1=weekly, 2=monthly

  @override
  void initState() {
    super.initState();
    final initialIndex = widget.initialTab == 'supporters' ? 1 : 0;
    _topTabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _topTabController.addListener(() {
      if (!_topTabController.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _topTabController.dispose();
    super.dispose();
  }

  String get _currentFetPeriod {
    return switch (_fetPeriodIndex) {
      1 => 'weekly',
      2 => 'monthly',
      _ => 'all',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing6,
                  0,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(AfriIcons.back),
                    ),
                    const SizedBox(width: SpacingTokens.spacing2),
                    Text(
                      'LEADERBOARD',
                      style: TypographyTokens.monolithFont(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Top-level tabs: FET / SUPPORTERS ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                  vertical: SpacingTokens.spacing3,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: ColorTokens.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: TabBar(
                    controller: _topTabController,
                    isScrollable: false,
                    indicator: BoxDecoration(
                      color: ColorTokens.clubAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: ColorTokens.background,
                    unselectedLabelColor: ColorTokens.onSurfaceVariant,
                    labelStyle: TypographyTokens.editorialFont(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                    dividerColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                    tabs: const [
                      Tab(text: 'FET RANKING'),
                      Tab(text: 'SUPPORTERS'),
                    ],
                  ),
                ),
              ),

              // ── Tab content ──
              Expanded(
                child: TabBarView(
                  controller: _topTabController,
                  children: [
                    _buildFetTab(),
                    _buildSupporterTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FET RANKING TAB
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildFetTab() {
    return Column(
      children: [
        // Period filter chips
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: Row(
            children: [
              LeaderboardPeriodChip(
                label: 'ALL TIME',
                selected: _fetPeriodIndex == 0,
                onTap: () => _selectFetPeriod(0),
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              LeaderboardPeriodChip(
                label: 'WEEKLY',
                selected: _fetPeriodIndex == 1,
                onTap: () => _selectFetPeriod(1),
              ),
              const SizedBox(width: SpacingTokens.spacing2),
              LeaderboardPeriodChip(
                label: 'MONTHLY',
                selected: _fetPeriodIndex == 2,
                onTap: () => _selectFetPeriod(2),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        Expanded(child: _buildFetContent()),
      ],
    );
  }

  void _selectFetPeriod(int index) {
    if (_fetPeriodIndex == index) return;
    setState(() => _fetPeriodIndex = index);
    // The provider is keyed by period — switching index triggers a new watch.
  }

  Widget _buildFetContent() {
    final period = _currentFetPeriod;
    final asyncFet = ref.watch(fetLeaderboardProvider(period));

    return asyncFet.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriSkeletonList(),
      ),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriStateView.offline(
            title: 'Leaderboard unavailable',
            message: 'Leaderboard is temporarily unavailable.',
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(fetLeaderboardProvider(period).notifier).refresh(),
          ),
        ),
      ),
      data: (snapshot) {
        if (snapshot.rows.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriEmptyView(
                title: 'No ranks yet',
                message: 'The board fills as predictions settle.',
              ),
            ),
          );
        }

        final podium = snapshot.rows.take(3).toList(growable: false);
        final currentUserId =
            ref.read(predictionRepositoryProvider).currentUserId;
        final userEntry = currentUserId == null || currentUserId.isEmpty
            ? null
            : snapshot.rows.cast<PredictionLeaderboardEntry?>().firstWhere(
                  (e) => e?.userId == currentUserId,
                  orElse: () => null,
                );

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          children: [
            // Podium
            if (podium.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: FetPodiumCard(
                      entry: podium.length > 1 ? podium[1] : null,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: FetPodiumCard(
                      entry: podium.first,
                      featured: true,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: FetPodiumCard(
                      entry: podium.length > 2 ? podium[2] : null,
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.04, end: 0, duration: 400.ms),
            const SizedBox(height: SpacingTokens.spacing4),

            // Pinned user row
            if (userEntry != null) FetUserRow(entry: userEntry),

            if (userEntry != null)
              const SizedBox(height: SpacingTokens.spacing3),

            // Full list
            for (int i = 0; i < snapshot.rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: SpacingTokens.spacing3,
                ),
                child: FetListRow(
                  entry: snapshot.rows[i],
                  isMe: currentUserId != null &&
                      currentUserId.isNotEmpty &&
                      snapshot.rows[i].userId == currentUserId,
                ),
              )
                  .animate(delay: (i * 40).ms)
                  .fadeIn(duration: 200.ms)
                  .slideY(begin: 0.03, end: 0, duration: 200.ms),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SUPPORTERS TAB
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildSupporterTab() {
    final asyncSupporter = ref.watch(supporterLeaderboardProvider);

    return asyncSupporter.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing6),
        child: AfriSkeletonList(),
      ),
      error: (_, __) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: AfriStateView.offline(
            title: 'Rankings unavailable',
            message: 'Supporter rankings are temporarily unavailable.',
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(supporterLeaderboardProvider.notifier).refresh(),
          ),
        ),
      ),
      data: (snapshot) {
        if (snapshot.rows.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriEmptyView(
                title: 'No supporters yet',
                message: 'Supporter rankings update with contributions.',
              ),
            ),
          );
        }

        final podium = snapshot.rows.take(3).toList(growable: false);
        final currentUser = snapshot.rows
            .cast<FetLeaderboardRow?>()
            .firstWhere(
              (e) => e?.isCurrentUser == true,
              orElse: () => null,
            );

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          children: [
            // Podium
            if (podium.isNotEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: SupporterPodiumCard(
                      entry: podium.length > 1 ? podium[1] : null,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: SupporterPodiumCard(
                      entry: podium.first,
                      featured: true,
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: SupporterPodiumCard(
                      entry: podium.length > 2 ? podium[2] : null,
                    ),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.04, end: 0, duration: 400.ms),
            const SizedBox(height: SpacingTokens.spacing4),

            // Pinned user row
            if (currentUser != null)
              SupporterUserRow(entry: currentUser),

            if (currentUser != null)
              const SizedBox(height: SpacingTokens.spacing3),

            // Full list
            for (int i = 0; i < snapshot.rows.length; i++)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: SpacingTokens.spacing3,
                ),
                child: SupporterListRow(
                  entry: snapshot.rows[i],
                  isMe: snapshot.rows[i].isCurrentUser,
                ),
              )
                  .animate(delay: (i * 40).ms)
                  .fadeIn(duration: 200.ms)
                  .slideY(begin: 0.03, end: 0, duration: 200.ms),
          ],
        );
      },
    );
  }
}
