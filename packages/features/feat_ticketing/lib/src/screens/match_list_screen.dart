import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ticketing_providers.dart';

class MatchListScreen extends ConsumerStatefulWidget {
  const MatchListScreen({super.key});

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  CurrencyFormatter get _currencyFormatter => CurrencyFormatter(
        currencyCode: context.afriCurrencyCode,
        currencySymbol: context.afriCurrencySymbol,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchesAsync = ref.watch(ticketMatchesProvider);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
        ),
        title: Text('TICKETS', style: TypographyTokens.headlineLarge()),
        actions: [
          IconButton(
            icon: Icon(Icons.tune_rounded, color: ColorTokens.onSurface),
            onPressed: () => showAfriFilterSortSheet(
              context: context,
              title: 'Match Filters',
              sortOptions: const [
                AfriFilterOption(value: 'soonest', label: 'Soonest'),
                AfriFilterOption(value: 'latest', label: 'Latest'),
                AfriFilterOption(value: 'cheapest', label: 'Cheapest'),
              ],
              typeOptions: const [
                AfriFilterOption(value: 'available', label: 'Available'),
                AfriFilterOption(value: 'sold_out', label: 'Sold Out'),
                AfriFilterOption(value: 'vip', label: 'VIP Zones'),
              ],
              showDateRange: true,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: ColorTokens.onSurface,
            ),
            onPressed: () => ref.invalidate(ticketMatchesProvider),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: ColorTokens.clubPrimary,
          indicatorWeight: 3,
          labelStyle: TypographyTokens.labelLarge(),
          unselectedLabelStyle: TypographyTokens.labelLarge().copyWith(
            color: ColorTokens.onSurfaceVariant,
          ),
          labelColor: ColorTokens.onSurface,
          unselectedLabelColor: ColorTokens.onSurfaceVariant,
          tabs: const [
            Tab(text: 'UPCOMING'),
            Tab(text: 'PAST'),
          ],
        ),
      ),
      body: matchesAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(SpacingTokens.spacing4),
          child: AfriSkeletonList(),
        ),
        error: (error, _) => _TicketState(
          title: 'Unable to load fixtures',
          body: 'Ticket inventory is unavailable right now.',
          actionLabel: 'Retry',
          onPressed: () => ref.invalidate(ticketMatchesProvider),
        ),
        data: (matches) {
          final now = DateTime.now();
          final upcoming = matches
              .where((match) => !match.matchDate.isBefore(now))
              .toList(growable: false);
          final past = matches
              .where((match) => match.matchDate.isBefore(now))
              .toList(growable: false);

          return TabBarView(
            controller: _tabController,
            children: [
              _buildMatchList(
                context,
                matches: upcoming,
                emptyTitle: 'No upcoming fixtures on sale',
                emptyBody: 'New fixtures will appear when published.',
              ),
              _buildMatchList(
                context,
                matches: past,
                emptyTitle: 'No past fixtures yet',
                emptyBody: 'Past fixtures will appear after archival.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMatchList(
    BuildContext context, {
    required List<ClubMatch> matches,
    required String emptyTitle,
    required String emptyBody,
  }) {
    if (matches.isEmpty) {
      return _TicketState(
        title: emptyTitle,
        body: emptyBody,
        actionLabel: 'Back Home',
        onPressed: () => context.go('/home'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      itemCount: matches.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: SpacingTokens.spacing4),
      itemBuilder: (context, index) {
        final match = matches[index];
        final soldOut = match.isSoldOut;
        final onSale = match.isOnSale && !soldOut;
        final price = _currencyFormatter.format(match.ticketGeneralPrice);

        return Container(
          decoration: BoxDecoration(
            color: ColorTokens.surface,
            borderRadius: ShapeTokens.cardRadius,
            border: BorderTokens.ghost(),
          ),
          padding: const EdgeInsets.all(SpacingTokens.spacing4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      _buildCrest(),
                      const SizedBox(width: SpacingTokens.spacing2),
                      Text('VS', style: TypographyTokens.labelMedium()),
                      const SizedBox(width: SpacingTokens.spacing2),
                      _buildCrest(),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: soldOut
                          ? ColorTokens.outlineVariant.withValues(alpha: 0.2)
                          : onSale
                              ? ColorTokens.success.withValues(alpha: 0.2)
                              : ColorTokens.info.withValues(alpha: 0.16),
                      borderRadius: ShapeTokens.chipRadius,
                    ),
                    child: Text(
                      soldOut
                          ? 'SOLD OUT'
                          : onSale
                              ? 'AVAILABLE'
                              : 'UPCOMING',
                      style: TypographyTokens.labelSmall().copyWith(
                        color: soldOut
                            ? ColorTokens.onSurfaceVariant
                            : onSale
                                ? ColorTokens.success
                                : ColorTokens.info,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                '${match.homeTeam} vs ${match.awayTeam}',
                style: TypographyTokens.titleLarge(ColorTokens.onSurface),
              ),
              const SizedBox(height: SpacingTokens.spacing1),
              Text(
                match.competition.toUpperCase(),
                style: TypographyTokens.labelMedium().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    AfriDateFormatter.formatDate(match.matchDate),
                    style: TypographyTokens.bodySmall(),
                  ),
                  const SizedBox(width: SpacingTokens.spacing4),
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      match.venue,
                      style: TypographyTokens.bodySmall(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final priceBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FROM', style: TypographyTokens.labelSmall()),
                      Text(
                        price,
                        style: TypographyTokens.headlineMedium().copyWith(
                          color: ColorTokens.clubAccent,
                        ),
                      ),
                    ],
                  );
                  final actionButton = FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: ColorTokens.clubPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: ShapeTokens.buttonRadius,
                      ),
                    ),
                    onPressed: () =>
                        context.push('/tickets/detail/${match.id}'),
                    child: Text(
                      'Buy Ticket',
                      style: TypographyTokens.labelLarge().copyWith(
                        color: ColorTokens.onSurface,
                      ),
                    ),
                  );
                  final isCompactActionRow =
                      onSale && constraints.maxWidth < 360;

                  if (isCompactActionRow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        priceBlock,
                        const SizedBox(height: SpacingTokens.spacing3),
                        SizedBox(
                          width: double.infinity,
                          child: actionButton,
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: priceBlock),
                      if (onSale) ...[
                        const SizedBox(width: SpacingTokens.spacing4),
                        actionButton,
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCrest() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: ColorTokens.clubSecondary,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.shield,
        color: ColorTokens.onSurfaceVariant,
        size: 20,
      ),
    );
  }
}

class _TicketState extends StatelessWidget {
  const _TicketState({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 56,
              color: ColorTokens.onSurfaceVariant,
            ),
            const SizedBox(height: SpacingTokens.spacing4),
            Text(title, style: TypographyTokens.headlineSmall()),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodyMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            ClaymorphicButton(
              label: actionLabel,
              onPressed: onPressed,
            ),
          ],
        ),
      ),
    );
  }
}
