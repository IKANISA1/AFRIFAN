import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/gamification_overlays.dart';

class BadgesScreen extends ConsumerStatefulWidget {
  const BadgesScreen({super.key});

  @override
  ConsumerState<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends ConsumerState<BadgesScreen> {
  List<Map<String, dynamic>> _badges = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _badges = _defaultBadges(0, 0, 0, false);
        _isLoading = false;
        _error = null;
      });
      return;
    }

    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      var membershipQuery = client
          .from('fan_memberships')
          .select('points')
          .eq('user_id', userId)
          .limit(1);
      membershipQuery = resolver.apply(membershipQuery, scope);
      var groupsQuery = client
          .from('contribution_groups')
          .select('id')
          .eq('creator_id', userId)
          .limit(10);
      groupsQuery = resolver.apply(groupsQuery, scope);
      var ticketsQuery = client
          .from('tickets')
          .select('id')
          .eq('user_id', userId)
          .limit(10);
      ticketsQuery = resolver.apply(ticketsQuery, scope);
      final results = await Future.wait([
        client
            .from('user_private_contacts')
            .select('momo_number')
            .eq('user_id', userId)
            .maybeSingle(),
        membershipQuery.maybeSingle(),
        ticketsQuery,
        groupsQuery,
        client
            .from('fan_club_members')
            .select('club_id')
            .eq('user_id', userId)
            .limit(10),
      ]);

      final privateContact = results[0] as Map<String, dynamic>?;
      final membership = results[1] as Map<String, dynamic>?;
      final tickets = List<Map<String, dynamic>>.from(results[2] as List);
      final groups = List<Map<String, dynamic>>.from(results[3] as List);
      final clubs = List<Map<String, dynamic>>.from(results[4] as List);

      final xp = (membership?['points'] as num?)?.toInt() ?? 0;
      final ticketCount = tickets.length;
      final groupCount = groups.length;
      final clubCount = clubs.length;
      final hasMomo =
          privateContact?['momo_number']?.toString().trim().isNotEmpty ?? false;

      if (!mounted) return;
      setState(() {
        _badges = _defaultBadges(
          xp,
          ticketCount,
          groupCount,
          hasMomo || clubCount > 0,
        );
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _badges = const <Map<String, dynamic>>[];
        _isLoading = false;
        _error = 'Badges are temporarily unavailable.';
      });
    }
  }

  List<Map<String, dynamic>> _defaultBadges(
    int xp,
    int ticketCount,
    int groupCount,
    bool supporterSetup,
  ) {
    return <Map<String, dynamic>>[
      {
        'title': 'Profile Live',
        'description': 'Unlocked by completing your supporter setup.',
        'icon': Icons.verified_user_rounded,
        'earned': supporterSetup,
      },
      {
        'title': 'First Match',
        'description': 'Unlocked by issuing your first ticket.',
        'icon': Icons.sports_soccer_rounded,
        'earned': ticketCount > 0,
      },
      {
        'title': 'Circle Founder',
        'description': 'Unlocked by creating a supporter contribution circle.',
        'icon': Icons.volunteer_activism_rounded,
        'earned': groupCount > 0,
      },
      {
        'title': 'Bronze Pulse',
        'description': 'Unlocked at 500 XP.',
        'icon': Icons.workspace_premium_rounded,
        'earned': xp >= 500,
      },
      {
        'title': 'Silver Run',
        'description': 'Unlocked at 5,000 XP.',
        'icon': Icons.military_tech_rounded,
        'earned': xp >= 5000,
      },
      {
        'title': 'Gold Faithful',
        'description': 'Unlocked at 15,000 XP.',
        'icon': Icons.emoji_events_rounded,
        'earned': xp >= 15000,
      },
      {
        'title': 'Legend Circle',
        'description': 'Unlocked at 50,000 XP.',
        'icon': Icons.auto_awesome_rounded,
        'earned': xp >= 50000,
      },
      {
        'title': 'Triple Threat',
        'description':
            'Unlocked by joining tickets, circles, and profile setup.',
        'icon': Icons.star_rounded,
        'earned': supporterSetup && ticketCount > 0 && groupCount > 0,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'YOUR BADGES',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
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
                  title: 'Badges unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadBadges,
                ),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: GridView.builder(
                itemCount: _badges.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: SpacingTokens.spacing3,
                  mainAxisSpacing: SpacingTokens.spacing3,
                ),
                itemBuilder: (context, index) {
                  final badge = _badges[index];
                  final earned = badge['earned'] == true;
                  return GestureDetector(
                    onTap: earned
                        ? () => showBadgeEarnedModal(
                            context,
                            badgeName: badge['title']?.toString() ?? 'Badge',
                            description: badge['description']?.toString() ?? '',
                          )
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: earned
                            ? ColorTokens.clubAccent.withValues(alpha: 0.18)
                            : ColorTokens.surfaceContainerHigh,
                        border: BorderTokens.all(
                          color: earned
                              ? ColorTokens.clubAccent
                              : ColorTokens.ghostBorder,
                        ),
                      ),
                      child: Icon(
                        earned
                            ? (badge['icon'] as IconData? ??
                                  Icons.workspace_premium_rounded)
                            : Icons.lock_outline,
                        color: earned
                            ? ColorTokens.clubAccent
                            : ColorTokens.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
