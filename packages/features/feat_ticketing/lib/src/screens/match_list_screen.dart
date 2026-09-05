import 'package:club_data/club_data.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ticketing_providers.dart';
import 'my_tickets_screen.dart';

class MatchListScreen extends ConsumerStatefulWidget {
  const MatchListScreen({super.key, this.autofocusMatchId});

  final String? autofocusMatchId;

  @override
  ConsumerState<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends ConsumerState<MatchListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _sortBy = 'soonest';
  Set<String> _selectedTypes = const <String>{};
  DateTimeRange? _dateRange;
  bool _syncedInitialTab = false;
  List<ClubMatch>? _cachedMatches;
  bool _isStale = false;
  late bool _wasOnline;

  CurrencyFormatter get _currencyFormatter => CurrencyFormatter(
    currencyCode: context.afriCurrencyCode,
    currencySymbol: context.afriCurrencySymbol,
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _wasOnline = ConnectivityService.isOnline;
    ConnectivityService.onlineNotifier.addListener(_handleConnectivityChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedInitialTab) return;
    _syncedInitialTab = true;
    String? tab;
    try {
      tab = GoRouterState.of(context).uri.queryParameters['tab'];
    } on GoError {
      tab = null;
    }
    if (tab == 'mine') {
      _tabController.index = 2;
    }
  }

  @override
  void dispose() {
    ConnectivityService.onlineNotifier.removeListener(
      _handleConnectivityChange,
    );
    _tabController.dispose();
    super.dispose();
  }

  void _handleConnectivityChange() {
    final isOnline = ConnectivityService.isOnline;
    final restored = !_wasOnline && isOnline;
    _wasOnline = isOnline;

    if (!mounted) return;
    if (!isOnline && _cachedMatches != null) {
      setState(() => _isStale = true);
    } else if (restored) {
      setState(() => _isStale = _cachedMatches != null);
      ref.invalidate(ticketMatchesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final usesLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final matchesAsync = ref.watch(ticketMatchesProvider);
    final currentMatches = matchesAsync.valueOrNull;
    if (currentMatches != null) {
      _cachedMatches = currentMatches;
      if (!matchesAsync.isRefreshing && ConnectivityService.isOnline) {
        _isStale = false;
      }
    } else if (matchesAsync.hasError && _cachedMatches != null) {
      _isStale = true;
    }
    final displayedMatches =
        _cachedMatches != null &&
            (matchesAsync.hasError || matchesAsync.isLoading)
        ? AsyncData<List<ClubMatch>>(_cachedMatches!)
        : matchesAsync;
    final isRefreshing = matchesAsync.isRefreshing && _cachedMatches != null;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        title: Text(
          l10n.ticketListTitle,
          style: TypographyTokens.headlineLarge(),
        ),
        actions: [
          AfriIconButton(
            icon: AfriIcons.filter,
            tooltip: l10n.ticketFilterMatches,
            onTap: () async {
              final result = await showAfriFilterSortSheet(
                context: context,
                title: l10n.ticketMatchFilters,
                sortOptions: [
                  AfriFilterOption(
                    value: 'soonest',
                    label: l10n.ticketSortSoonest,
                  ),
                  AfriFilterOption(
                    value: 'latest',
                    label: l10n.ticketSortLatest,
                  ),
                  AfriFilterOption(
                    value: 'cheapest',
                    label: l10n.ticketSortCheapest,
                  ),
                ],
                typeOptions: [
                  AfriFilterOption(
                    value: 'available',
                    label: l10n.ticketTypeAvailable,
                  ),
                  AfriFilterOption(
                    value: 'sold_out',
                    label: l10n.ticketTypeSoldOut,
                  ),
                  AfriFilterOption(
                    value: 'vip',
                    label: l10n.ticketTypeVipZones,
                  ),
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
          ConnectivityBuilder(
            builder: (context, isOnline) => AfriIconButton(
              icon: AfriIcons.refresh,
              onTap: isOnline
                  ? () => ref.invalidate(ticketMatchesProvider)
                  : null,
              tooltip: isOnline
                  ? l10n.ticketRefreshMatches
                  : l10n.ticketRefreshMatchesOffline,
            ),
          ),
        ],
        bottom: AfriTabBar.line(
          controller: _tabController,
          tabs: [
            Tab(
              child: Text(
                usesLargeTextLayout ? l10n.ticketNext : l10n.ticketUpcoming,
                semanticsLabel: l10n.ticketUpcomingSemantic,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
            Tab(
              child: Text(
                l10n.ticketPast,
                semanticsLabel: l10n.ticketPastSemantic,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
            Tab(
              child: Text(
                l10n.ticketMine,
                semanticsLabel: l10n.ticketMineSemantic,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
      scrollable: false,
      child: Column(
        children: [
          if (_isStale || isRefreshing)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing4,
                SpacingTokens.spacing3,
                SpacingTokens.spacing4,
                0,
              ),
              child: AfriStateBanner(
                icon: isRefreshing
                    ? AfriIcons.refresh
                    : AfriIcons.statusWarning,
                title: isRefreshing
                    ? l10n.ticketRefreshingInventoryTitle
                    : l10n.ticketSavedInventoryTitle,
                subtitle: isRefreshing
                    ? l10n.ticketRefreshingInventoryMessage
                    : l10n.ticketSavedInventoryMessage,
                tone: isRefreshing
                    ? AfriStateBannerTone.info
                    : AfriStateBannerTone.warning,
              ),
            ),
          Expanded(
            child: AfriAsyncStateView<List<ClubMatch>>(
              value: displayedMatches,
              loading: (_) => const Padding(
                padding: EdgeInsets.all(SpacingTokens.spacing4),
                child: AfriSkeletonList(),
              ),
              error: (_, error, stackTrace) => ConnectivityBuilder(
                builder: (context, isOnline) => _TicketFailureView(
                  failure: TicketMatchesFailure.fromError(error),
                  isOnline: isOnline,
                  onRetry: () => ref.invalidate(ticketMatchesProvider),
                ),
              ),
              data: (context, matches) {
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
                      emptyTitle: l10n.ticketNoUpcomingTitle,
                      emptyBody: l10n.ticketNoUpcomingMessage,
                    ),
                    _buildMatchList(
                      context,
                      matches: past,
                      emptyTitle: l10n.ticketNoPastTitle,
                      emptyBody: l10n.ticketNoPastMessage,
                    ),
                    const MyTicketsScreen(embedded: true),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<ClubMatch> _applyFilters(List<ClubMatch> matches) {
    final filtered = matches
        .where((match) {
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
            if (match.matchDate.isBefore(start) ||
                match.matchDate.isAfter(end)) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);

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
    required String emptyTitle,
    required String emptyBody,
  }) {
    if (matches.isEmpty) {
      return _TicketState(
        title: emptyTitle,
        body: emptyBody,
        actionLabel: context.afriL10n.ticketRefresh,
        onPressed: () => ref.invalidate(ticketMatchesProvider),
      );
    }

    final usesLargeTextLayout =
        MediaQuery.textScalerOf(context).scale(1) >= 1.5;

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
        final l10n = context.afriL10n;

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
              _MatchAvailabilityHeader(
                status: soldOut
                    ? l10n.ticketStatusSoldOut
                    : onSale
                    ? l10n.ticketStatusAvailable
                    : l10n.ticketUpcoming,
                statusColor: soldOut
                    ? ColorTokens.onSurfaceVariant
                    : onSale
                    ? ColorTokens.success
                    : ColorTokens.info,
                statusBackground: soldOut
                    ? ColorTokens.outlineVariant.withValues(alpha: 0.2)
                    : onSale
                    ? ColorTokens.success.withValues(alpha: 0.2)
                    : ColorTokens.info.withValues(alpha: 0.16),
                usesLargeTextLayout: usesLargeTextLayout,
                brandMarkBuilder: _buildBrandMark,
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                l10n.ticketMatchVersus(match.homeTeam, match.awayTeam),
                style: TypographyTokens.titleLarge(ColorTokens.onSurface),
              ),
              const SizedBox(height: SpacingTokens.spacing1),
              Text(
                match.competition,
                style: TypographyTokens.labelMedium().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing2),
              _MatchMetadata(
                date: AfriDateFormatter.formatDate(match.matchDate),
                venue: match.venue,
                usesLargeTextLayout: usesLargeTextLayout,
              ),
              const SizedBox(height: SpacingTokens.spacing6),
              LayoutBuilder(
                builder: (context, constraints) {
                  final priceBlock = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ticketFrom,
                        style: TypographyTokens.labelSmall(),
                      ),
                      Text(
                        price,
                        style: TypographyTokens.headlineMedium().copyWith(
                          color: ColorTokens.primaryContainer,
                        ),
                      ),
                    ],
                  );
                  final actionLabel = soldOut
                      ? l10n.ticketSoldOut
                      : onSale
                      ? l10n.ticketBuyAction
                      : l10n.ticketSalesNotOpen;
                  final actionButton = AfriButton(
                    key: ValueKey<String>('ticket-action-${match.id}'),
                    label: actionLabel,
                    fullWidth: false,
                    enabled: onSale,
                    autofocus: widget.autofocusMatchId == match.id,
                    onTap: onSale
                        ? () => context.push('/tickets/detail/${match.id}')
                        : () {},
                  );
                  final isCompactActionRow =
                      (constraints.maxWidth < 360 || usesLargeTextLayout);

                  if (isCompactActionRow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        priceBlock,
                        const SizedBox(height: SpacingTokens.spacing3),
                        SizedBox(width: double.infinity, child: actionButton),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: priceBlock),
                      const SizedBox(width: SpacingTokens.spacing4),
                      actionButton,
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

  Widget _buildBrandMark() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerHigh,
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

class _MatchAvailabilityHeader extends StatelessWidget {
  const _MatchAvailabilityHeader({
    required this.status,
    required this.statusColor,
    required this.statusBackground,
    required this.usesLargeTextLayout,
    required this.brandMarkBuilder,
  });

  final String status;
  final Color statusColor;
  final Color statusBackground;
  final bool usesLargeTextLayout;
  final Widget Function() brandMarkBuilder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final teams = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        brandMarkBuilder(),
        const SizedBox(width: SpacingTokens.spacing2),
        Text(l10n.ticketVersusUpper, style: TypographyTokens.labelMedium()),
        const SizedBox(width: SpacingTokens.spacing2),
        brandMarkBuilder(),
      ],
    );
    final statusChip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusBackground,
        borderRadius: ShapeTokens.chipRadius,
      ),
      child: Text(
        status,
        maxLines: usesLargeTextLayout ? 2 : 1,
        overflow: usesLargeTextLayout
            ? TextOverflow.visible
            : TextOverflow.ellipsis,
        style: TypographyTokens.labelSmall().copyWith(color: statusColor),
      ),
    );

    if (usesLargeTextLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          teams,
          const SizedBox(height: SpacingTokens.spacing3),
          statusChip,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        teams,
        const SizedBox(width: SpacingTokens.spacing2),
        Flexible(
          child: Align(alignment: Alignment.centerRight, child: statusChip),
        ),
      ],
    );
  }
}

class _MatchMetadata extends StatelessWidget {
  const _MatchMetadata({
    required this.date,
    required this.venue,
    required this.usesLargeTextLayout,
  });

  final String date;
  final String venue;
  final bool usesLargeTextLayout;

  @override
  Widget build(BuildContext context) {
    final dateRow = _MetadataRow(icon: AfriIcons.calendar, label: date);
    final venueRow = _MetadataRow(icon: AfriIcons.location, label: venue);

    if (usesLargeTextLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dateRow,
          const SizedBox(height: SpacingTokens.spacing2),
          venueRow,
        ],
      );
    }

    return Row(
      children: [
        Flexible(child: dateRow),
        const SizedBox(width: SpacingTokens.spacing4),
        Expanded(child: venueRow),
      ],
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: ColorTokens.onSurfaceVariant),
        ),
        const SizedBox(width: SpacingTokens.spacing1),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.visible,
            style: TypographyTokens.bodySmall(),
          ),
        ),
      ],
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
  final VoidCallback? onPressed;

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
            AfriButton(
              label: actionLabel,
              onTap: onPressed ?? () {},
              enabled: onPressed != null,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketFailureView extends StatelessWidget {
  const _TicketFailureView({
    required this.failure,
    required this.isOnline,
    required this.onRetry,
  });

  final TicketMatchesFailure failure;
  final bool isOnline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    if (!isOnline) {
      return _TicketState(
        title: l10n.ticketListOfflineTitle,
        body: l10n.ticketListOfflineMessage,
        actionLabel: l10n.ticketConnectionRequired,
        onPressed: null,
      );
    }

    return switch (failure.kind) {
      TicketMatchesFailureKind.permissionDenied => _TicketState(
        title: l10n.ticketListAccessTitle,
        body: l10n.ticketListAccessMessage,
        actionLabel: l10n.ticketAccessRequired,
        onPressed: null,
      ),
      TicketMatchesFailureKind.conflict => _TicketState(
        title: l10n.ticketInventoryChangedTitle,
        body: l10n.ticketInventoryChangedMessage,
        actionLabel: l10n.ticketRefresh,
        onPressed: onRetry,
      ),
      TicketMatchesFailureKind.securityTimeout => _TicketState(
        title: l10n.ticketInventorySecurityTitle,
        body: l10n.ticketInventorySecurityMessage,
        actionLabel: l10n.ticketRefresh,
        onPressed: onRetry,
      ),
      TicketMatchesFailureKind.unknown => _TicketState(
        title: l10n.ticketFixturesUnavailableTitle,
        body: l10n.ticketFixturesUnavailableMessage,
        actionLabel: l10n.ticketRetry,
        onPressed: onRetry,
      ),
    };
  }
}
