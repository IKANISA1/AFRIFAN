import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ticketing_providers.dart';

class MyTicketsScreen extends ConsumerStatefulWidget {
  const MyTicketsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends ConsumerState<MyTicketsScreen>
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
    final ticketsAsync = ref.watch(myTicketsProvider);
    final body = ticketsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(SpacingTokens.spacing4),
        child: AfriSkeletonList(),
      ),
      error: (error, _) => _TicketWalletState(
        title: 'Ticket wallet unavailable',
        body:
            'We could not load your ticket wallet right now. Check your connection and try again.',
        actionLabel: 'Retry',
        onPressed: () => ref.invalidate(myTicketsProvider),
      ),
      data: (tickets) {
        final now = DateTime.now();
        final upcoming = tickets.where((ticket) {
          final isOpenTicket = ticket.status == TicketStatus.pending ||
              ticket.status == TicketStatus.active;
          return isOpenTicket && !ticket.match.matchDate.isBefore(now);
        }).toList(growable: false);
        final past = tickets
            .where((ticket) => !upcoming.contains(ticket))
            .toList(growable: false);

        return TabBarView(
          controller: _tabController,
          children: [
            _buildTicketList(context, tickets: upcoming),
            _buildTicketList(context, tickets: past),
          ],
        );
      },
    );

    if (widget.embedded) {
      return Column(
        children: [
          AfriTabBar.line(
            controller: _tabController,
            tabs: const [
              Tab(text: 'UPCOMING'),
              Tab(text: 'PAST'),
            ],
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text('MY TICKETS', style: TypographyTokens.headlineLarge()),
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        actions: [
          AfriIconButton(
            icon: AfriIcons.refresh,
            onTap: () => ref.invalidate(myTicketsProvider),
            tooltip: 'Refresh tickets',
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
      body: body,
    );
  }

  Widget _buildTicketList(
    BuildContext context, {
    required List<ClubTicket> tickets,
  }) {
    if (tickets.isEmpty) {
      return Center(
        child: AfriButton(
          label: 'Browse matches',
          icon: AfriIcons.tickets,
          onTap: () => context.go('/tickets'),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(SpacingTokens.spacing4),
      itemCount: tickets.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: SpacingTokens.spacing4),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        final isActive = ticket.status == TicketStatus.active;
        final isPending = ticket.status == TicketStatus.pending;
        final statusColor = switch (ticket.status) {
          TicketStatus.active => ColorTokens.success,
          TicketStatus.pending => ColorTokens.warning,
          TicketStatus.used => ColorTokens.onSurfaceVariant,
          TicketStatus.expired => ColorTokens.onSurfaceVariant,
          TicketStatus.cancelled => ColorTokens.onSurfaceVariant,
          TicketStatus.voided => ColorTokens.error,
          TicketStatus.refunded => ColorTokens.info,
        };

        return AfriPressFeedback(
          onTap: isActive ? () => context.push('/e-ticket/${ticket.id}') : null,
          enabled: isActive,
          tooltip: isActive ? 'Open ticket QR code' : null,
          semanticsLabel:
              '${ticket.matchTitle}, ${ticket.status.name} ticket, ${ticket.seatType.label}',
          semanticsHint: isActive ? 'Open ticket QR code' : null,
          child: Container(
            decoration: BoxDecoration(
              color: ColorTokens.surface,
              borderRadius: ShapeTokens.cardRadius,
              border: BorderTokens.all(
                color: isActive
                    ? ColorTokens.clubPrimary.withValues(alpha: 0.5)
                    : ColorTokens.ghostBorder,
                width: isActive ? 1.5 : BorderTokens.standard,
              ),
            ),
            padding: const EdgeInsets.all(SpacingTokens.spacing4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.matchTitle,
                        style: TypographyTokens.labelLarge(),
                      ),
                      const SizedBox(height: SpacingTokens.spacing2),
                      Text(
                        AfriDateFormatter.formatDate(ticket.match.matchDate),
                        style: TypographyTokens.bodyMedium().copyWith(
                          color: ColorTokens.clubAccent,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing2),
                      Text(
                        '${ticket.seatType.label}  •  ${_currencyFormatter.format(ticket.amountPaid)}',
                        style: TypographyTokens.bodyMedium(),
                      ),
                      if (isPending) ...[
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          'Payment received on your phone still needs verification before the QR unlocks.',
                          style: TypographyTokens.bodySmall(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: SpacingTokens.spacing4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? ColorTokens.success.withValues(alpha: 0.2)
                              : ColorTokens.outlineVariant
                                  .withValues(alpha: 0.2),
                          borderRadius: ShapeTokens.chipRadius,
                        ),
                        child: Text(
                          ticket.status.label.toUpperCase(),
                          style: TypographyTokens.labelSmall().copyWith(
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: ColorTokens.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(ShapeTokens.radiusLg),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isPending ? AfriIcons.statusWait : AfriIcons.qrCode,
                    size: 56,
                    color: isActive
                        ? ColorTokens.onSurface
                        : ColorTokens.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TicketWalletState extends StatelessWidget {
  const _TicketWalletState({
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
