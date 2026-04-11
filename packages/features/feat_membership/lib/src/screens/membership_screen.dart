import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/membership_card.dart';
import '../widgets/tier_progress.dart';

/// Membership screen — tier display, digital card, membership packages.
class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  List<Map<String, dynamic>> _packages = [];
  Map<String, dynamic>? _membership;
  bool _isLoading = true;

  static const List<Map<String, dynamic>> _fallbackPackages = [
    <String, dynamic>{
      'tier': 'bronze',
      'title': 'Bronze Supporter',
      'description': 'Entry tier. Match access & starter rewards.',
    },
    <String, dynamic>{
      'tier': 'silver',
      'title': 'Silver Ultras',
      'description': 'Faster progression & earlier access.',
    },
    <String, dynamic>{
      'tier': 'gold',
      'title': 'Gold Faithful',
      'description': 'Premium recognition & matchday priority.',
    },
    <String, dynamic>{
      'tier': 'legend',
      'title': 'Legend Circle',
      'description': 'Reserved for long-term fan leaders.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  int? _currentClubId(SupabaseClient client) {
    final user = client.auth.currentUser;
    final candidates = <Object?>[
      user?.appMetadata['club_id'],
      user?.userMetadata?['club_id'],
      user?.appMetadata['clubId'],
      user?.userMetadata?['clubId'],
    ];

    for (final candidate in candidates) {
      final parsed = int.tryParse(candidate?.toString().trim() ?? '');
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  Future<void> _loadPackages() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final clubId = _currentClubId(client);
      if (clubId == null) {
        if (mounted) {
          setState(() {
            _packages = _fallbackPackages;
            _membership = null;
            _isLoading = false;
          });
        }
        return;
      }
      final packagesResponse = await client
          .from('membership_packages')
          .select()
          .eq('club_id', clubId)
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      Map<String, dynamic>? membership;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        membership = await client
            .from('fan_memberships')
            .select()
            .eq('user_id', userId)
            .eq('club_id', clubId)
            .order('joined_at', ascending: false)
            .limit(1)
            .maybeSingle();
      }

      if (mounted) {
        setState(() {
          final loadedPackages = List<Map<String, dynamic>>.from(
            packagesResponse,
          );
          _packages = loadedPackages.isEmpty
              ? _fallbackPackages
              : loadedPackages;
          _membership = membership == null
              ? null
              : Map<String, dynamic>.from(membership);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final currentXp = (_membership?['points'] as num?)?.toInt() ?? 0;
    final currentTier = _tierLabelFromXp(currentXp);

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: ColorTokens.onSurface),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text(
          'MEMBERSHIP',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurface,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Digital membership card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: MembershipCard(tierLabel: currentTier, xp: currentXp),
            ),
          ),

          // Tier progress
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing6,
              ),
              child: TierProgress(currentXp: currentXp),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing8),
          ),

          // Packages header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing6,
              ),
              child: Text(
                'MEMBERSHIP PACKAGES',
                style: TypographyTokens.monolithFont(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: ColorTokens.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing4),
          ),

          // Loading
          if (_isLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: AfriSkeletonList(),
              ),
            ),

          if (!_isLoading)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  0,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                ),
                child: GlassCard(
                  animate: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentTier.toUpperCase(),
                              style: TypographyTokens.monolithFont(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: ColorTokens.clubAccent,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing2),
                            Text(
                              currentXp == 0
                                  ? 'Earn XP from tickets, fan clubs & contributions.'
                                  : '$currentXp XP earned.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (!_isLoading && _packages.isNotEmpty)
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final pkg = _packages[index];
                final tierId = (pkg['tier'] ?? 'bronze')
                    .toString()
                    .toLowerCase();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    0,
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing2,
                  ),
                  child: GlassCard(
                    onTap: () => context.push('/membership/tier/$tierId'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                (pkg['title'] ?? pkg['tier'] ?? 'Package')
                                    .toString()
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TypographyTokens.monolithFont(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: ColorTokens.onSurface,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: SpacingTokens.spacing3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.15),
                                borderRadius: ShapeTokens.chipRadius,
                              ),
                              child: Text(
                                (pkg['tier'] ?? '').toString().toUpperCase(),
                                style: TypographyTokens.monolithFont(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (pkg['description'] != null) ...[
                          const SizedBox(height: SpacingTokens.spacing2),
                          Text(
                            pkg['description'].toString(),
                            style: theme.textTheme.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }, childCount: _packages.length),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing20),
          ),
        ],
      ),
    );
  }

  String _tierLabelFromXp(int xp) {
    if (xp >= 50000) return 'Legend';
    if (xp >= 15000) return 'Gold';
    if (xp >= 5000) return 'Silver';
    return 'Bronze';
  }
}
