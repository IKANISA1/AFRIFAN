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
  String _sortBy = 'soonest';
  Set<String> _selectedTypes = const <String>{};
  DateTimeRange? _dateRange;

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
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        title: Text('TICKETS', style: TypographyTokens.headlineLarge()),
        actions: [
          AfriIconButton(
            icon: AfriIcons.filter,
            tooltip: 'Filter matches',
            onTap: () async {
              final result = await showAfriFilterSortSheet(
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
                initialSortBy: _sortBy,
                initialSelectedTypes: _selectedTypes,
                initialDateRange: _dateRange,
                showDateRange: true,
              );

              if (result == null || !mounted) {
                return;
              }
              setState(() {
                _sortBy = result.sortBy;
                _selectedTypes = result.selectedTypes;
                _dateRange = result.dateRange;
              });
            },
          ),
          AfriIconButton(
            icon: AfriIcons.refresh,
            onTap: () => ref.invalidate(ticketMatchesProvider),
            tooltip: 'Refresh matches',
          ),
        ],
        bottom: AfriTabBar.line(
          controller: _tabController,
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
          body:
              'Ticket inventory is unavailable right now. Check your connection and try again.',
          actionLabel: 'Retry',
          onPressed: () => ref.invalidate(ticketMatchesProvider),
        ),
        data: (matches) {
          final filteredMatches = _applyFilters(matches);
          final now = DateTime.now();
          final upcoming = filteredMatches
              .where((match) => !match.matchDate.isBefore(now))
              .toList(growable: false);
          final past = filteredMatches
              .where((match) => match.matchDate.isBefore(now))
              .toList(growable: false);

          return TabBarView(
            controller: _tabController,
            children: [
              _buildMatchList(
                context,
                matches: upcoming,
              ),
              _buildMatchList(
                context,
                matches: past,
              ),
            ],
          );
        },
      ),
    );
  }

  List<ClubMatch> _applyFilters(List<ClubMatch> matches) {
    final filtered = matches.where((match) {
      if (_selectedTypes.contains('available') &&
          (!match.isOnSale || match.isSoldOut)) {
        return false;
      }
      if (_selectedTypes.contains('sold_out') && !match.isSoldOut) {
        return false;
      }
      if (_selectedTypes.contains('vip') && match.ticketVipPrice <= 0) {
        return false;
      }
      if (_dateRange != null) {
        final start = DateTime(
          _dateRange!.start.year,
          _dateRange!.start.month,
          _dateRange!.start.day,
        );
        final end = DateTime(
          _dateRange!.end.year,
          _dateRange!.end.month,
          _dateRange!.end.day,
          23,
          59,
          59,
        );
        if (match.matchDate.isBefore(start) || match.matchDate.isAfter(end)) {
          return false;
        }
      }
      return true;
    }).toList(growable: false);

    final sorted = List<ClubMatch>.from(filtered);
    switch (_sortBy) {
      case 'latest':
        sorted.sort((a, b) => b.matchDate.compareTo(a.matchDate));
        break;
      case 'cheapest':
        sorted.sort(
          (a, b) => a.ticketGeneralPrice.compareTo(b.ticketGeneralPrice),
        );
        break;
      case 'soonest':
      default:
        sorted.sort((a, b) => a.matchDate.compareTo(b.matchDate));
        break;
    }
    return sorted;
  }

  Widget _buildMatchList(
    BuildContext context, {
    required List<ClubMatch> matches,
  }) {
    if (matches.isEmpty) {
      return const SizedBox.shrink();
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
                    AfriIcons.calendar,
                    size: 14,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                  const SizedBox(width: SpacingTokens.spacing1),
                  Text(
                    AfriDateFormatter.formatDate(match.matchDate),
                    style: TypographyTokens.bodySmall(),
                  ),
                  const SizedBox(width: SpacingTokens.spacing4),
                  Icon(
                    AfriIcons.location,
                    size: 14,
                    color: ColorTokens.onSurfaceVariant,
                  ),
                  const SizedBox(width: SpacingTokens.spacing1),
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
                  final actionButton = AfriButton(
                    label: 'Buy ticket',
                    fullWidth: false,
                    onTap: () => context.push('/tickets/detail/${match.id}'),
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
        AfriIcons.shield,
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
              AfriIcons.tickets,
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
            AfriButton(label: actionLabel, onTap: onPressed),
          ],
        ),
      ),
    );
  }
}
