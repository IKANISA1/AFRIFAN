import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../ticketing_providers.dart';

class MyTicketsScreen extends ConsumerStatefulWidget {
  const MyTicketsScreen({super.key});

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

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        title: Text('MY TICKETS', style: TypographyTokens.headlineLarge()),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(myTicketsProvider),
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
      body: ticketsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(SpacingTokens.spacing4),
          child: AfriSkeletonList(),
        ),
        error: (error, _) => _TicketWalletState(
          title: 'Ticket wallet unavailable',
          body: 'We could not load your issued tickets right now.',
          actionLabel: 'Retry',
          onPressed: () => ref.invalidate(myTicketsProvider),
        ),
        data: (tickets) {
          final now = DateTime.now();
          final upcoming = tickets.where((ticket) {
            return ticket.status == TicketStatus.active &&
                !ticket.match.matchDate.isBefore(now);
          }).toList(growable: false);
          final past =
              tickets.where((ticket) => !upcoming.contains(ticket)).toList(
                    growable: false,
                  );

          return TabBarView(
            controller: _tabController,
            children: [
              _buildTicketList(
                context,
                tickets: upcoming,
                emptyTitle: 'No active tickets yet',
                emptyBody: 'Tickets appear after payment.',
              ),
              _buildTicketList(
                context,
                tickets: past,
                emptyTitle: 'No ticket history yet',
                emptyBody:
                    'Used and expired tickets will move here automatically.',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTicketList(
    BuildContext context, {
    required List<ClubTicket> tickets,
    required String emptyTitle,
    required String emptyBody,
  }) {
    if (tickets.isEmpty) {
      return _TicketWalletState(
        title: emptyTitle,
        body: emptyBody,
        actionLabel: 'Browse Matches',
        onPressed: () => context.go('/tickets'),
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

        return GestureDetector(
          onTap: isActive ? () => context.push('/e-ticket/${ticket.id}') : null,
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
                          ticket.status.value.toUpperCase(),
                          style: TypographyTokens.labelSmall().copyWith(
                            color: isActive
                                ? ColorTokens.success
                                : ColorTokens.onSurfaceVariant,
                            letterSpacing: 1,
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
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.qr_code_2_rounded,
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
              Icons.local_activity_outlined,
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
            ClaymorphicButton(label: actionLabel, onPressed: onPressed),
          ],
        ),
      ),
    );
  }
}
