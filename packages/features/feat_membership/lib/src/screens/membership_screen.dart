import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../widgets/contribution_history.dart';
import '../widgets/digital_membership_card.dart';
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
  List<ContributionRecord> _contributions = const <ContributionRecord>[];
  bool _isLoading = true;
  bool _isJoining = false;
  String? _joiningTier;
  String? _error;
  String? _emptyMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPackages());
  }

  Future<void> _loadPackages() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      if (scope.clubId == null) {
        throw StateError('Membership requires a numeric club_id scope.');
      }
      final clubId = scope.clubId!;
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

      final contributions = userId == null
          ? const <ContributionRecord>[]
          : await _loadContributionHistory(
              client: client,
              clubId: clubId,
              userId: userId,
              membership: membership,
            );

      if (mounted) {
        setState(() {
          final loadedPackages = List<Map<String, dynamic>>.from(
            packagesResponse,
          );
          _packages = loadedPackages;
          _membership = membership == null
              ? null
              : Map<String, dynamic>.from(membership);
          _contributions = contributions;
          _isLoading = false;
          _error = null;
          _emptyMessage = loadedPackages.isEmpty
              ? 'Membership packages will appear once the club publishes them.'
              : null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _contributions = const <ContributionRecord>[];
          _isLoading = false;
          _error = 'Membership details are temporarily unavailable.';
          _emptyMessage = null;
        });
      }
    }
  }

  Future<List<ContributionRecord>> _loadContributionHistory({
    required SupabaseClient client,
    required int clubId,
    required String userId,
    required Map<String, dynamic>? membership,
  }) async {
    final rows = List<Map<String, dynamic>>.from(
      await client
          .from('initiative_contributions')
          .select('initiative_id, amount, status, created_at')
          .eq('user_id', userId)
          .eq('club_id', clubId)
          .order('created_at', ascending: false)
          .limit(8),
    );
    if (rows.isEmpty) {
      return const <ContributionRecord>[];
    }

    final initiativeIds = rows
        .map((row) => row['initiative_id']?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);

    final initiativeTitles = <String, String>{};
    if (initiativeIds.isNotEmpty) {
      final initiatives = List<Map<String, dynamic>>.from(
        await client
            .from('initiatives')
            .select('id, title')
            .inFilter('id', initiativeIds),
      );
      for (final initiative in initiatives) {
        final id = initiative['id']?.toString();
        final title = initiative['title']?.toString().trim();
        if (id != null && id.isNotEmpty && title != null && title.isNotEmpty) {
          initiativeTitles[id] = title;
        }
      }
    }

    final fallbackLabel = membership == null
        ? 'Club contribution'
        : '${_currentTierLabel(membership['tier']?.toString(), (membership['points'] as num?)?.toInt() ?? 0)} contribution';

    return rows
        .map(
          (row) => ContributionRecord(
            date: _formatMembershipDate(row['created_at']?.toString()),
            amount: (row['amount'] as num?)?.toInt() ?? 0,
            label:
                initiativeTitles[row['initiative_id']?.toString()] ??
                fallbackLabel,
            status: _normalizeContributionStatus(row['status']?.toString()),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _activatePackage(Map<String, dynamic> pkg) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showMessage('Sign in first to activate membership.');
      context.go('/onboarding');
      return;
    }

    final tierValue = (pkg['tier'] ?? 'fan').toString().toLowerCase();
    final tierLabel = _membershipPackageLabel(tierValue);
    final amount = _packagePrice(pkg);

    setState(() {
      _isJoining = true;
      _joiningTier = tierValue;
    });

    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      final route = await _findActivePaymentRoute(client, resolver, scope);

      if (route == null) {
        _showMessage('No active MOMO membership route is configured yet.');
        return;
      }

      if (amount > 0) {
        final launched = await MomoDialerService.launchMomoUssd(
          recipient: route.recipientCode,
          amount: amount,
          country: route.country,
          recipientType: PaymentRecipientType.code,
        );

        if (!mounted) return;
        if (!launched) {
          _showMessage('Could not launch the MOMO dialer.');
          return;
        }

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Confirm $tierLabel membership'),
            content: Text(
              'Finish the ${context.afriCurrencySymbol}$amount MoMo payment in your dialer, then confirm here to activate your membership.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              AfriButton(
                label: 'I completed payment',
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );

        if (confirmed != true || !mounted) {
          return;
        }
      }

      await _upsertMembership(
        client: client,
        scope: scope,
        user: user,
        tierValue: tierValue,
      );
      await _loadPackages();
      if (!mounted) return;
      _showMessage(
        amount > 0
            ? '$tierLabel membership activated.'
            : '$tierLabel membership started.',
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Membership activation failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
          _joiningTier = null;
        });
      }
    }
  }

  Future<PartnerPaymentRoute?> _findActivePaymentRoute(
    SupabaseClient client,
    ClubScopeResolver resolver,
    ClubScope scope,
  ) async {
    var query = client
        .from('partner_payment_routes')
        .select()
        .eq('status', 'active');
    query = resolver.apply(query, scope);
    final rows = await query.limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return PartnerPaymentRoute.fromJson(rows.first);
  }

  Future<void> _upsertMembership({
    required SupabaseClient client,
    required ClubScope scope,
    required UserProfile user,
    required String tierValue,
  }) async {
    final tier = FanTierX.fromValue(tierValue);
    final now = DateTime.now().toUtc();
    final expiry = now.add(const Duration(days: 365));
    final existing = await client
        .from('fan_memberships')
        .select('id, points, chapter')
        .eq('user_id', user.id)
        .eq('club_id', scope.clubId!)
        .limit(1)
        .maybeSingle();

    if (existing == null) {
      await client.from('fan_memberships').insert({
        'user_id': user.id,
        ...ClubScopeResolver(client: client).payload(scope),
        'tier': tier.value,
        'points': tier.minPoints,
        'chapter': 'Main',
        'renewed_at': now.toIso8601String(),
        'expires_at': expiry.toIso8601String(),
      });
      return;
    }

    final currentPoints = (existing['points'] as num?)?.toInt() ?? 0;
    await client
        .from('fan_memberships')
        .update({
          'tier': tier.value,
          'points': currentPoints >= tier.minPoints
              ? currentPoints
              : tier.minPoints,
          'renewed_at': now.toIso8601String(),
          'expires_at': expiry.toIso8601String(),
        })
        .eq('id', existing['id']);
  }

  int _packagePrice(Map<String, dynamic> pkg) {
    final annual = (pkg['annual_price'] as num?)?.toInt();
    final standard = (pkg['price'] as num?)?.toInt();
    return annual ?? standard ?? 0;
  }

  String _packagePriceLabel(Map<String, dynamic> pkg) {
    final amount = _packagePrice(pkg);
    if (amount <= 0) {
      return 'Included';
    }
    return CurrencyFormatter(
      currencyCode: context.afriCurrencyCode,
      currencySymbol: context.afriCurrencySymbol,
    ).format(amount);
  }

  bool _isCurrentTier(String tierValue) {
    final currentTier = (_membership?['tier'] ?? '').toString().toLowerCase();
    return currentTier.isNotEmpty && currentTier == tierValue.toLowerCase();
  }

  String _membershipActionLabel(String tierValue) {
    if (_membership == null) {
      return 'Activate';
    }
    if (_isCurrentTier(tierValue)) {
      return 'Renew';
    }
    return 'Switch';
  }

  String _membershipPackageLabel(String tierValue) {
    return switch (FanTierX.fromValue(tierValue)) {
      FanTier.fan => 'Fan',
      FanTier.bronze => 'Bronze',
      FanTier.gold => 'Gold',
      FanTier.platinum => 'Platinum',
    };
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final user = ref.watch(currentUserProvider);
    final currentFet = (_membership?['points'] as num?)?.toInt() ?? 0;
    final currentTier = _currentTierLabel(
      _membership?['tier']?.toString(),
      currentFet,
    );
    final paymentStatus = PaymentStatusX.fromValue(
      _membership?['payment_status']?.toString(),
    );

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AfriIcons.back, color: ColorTokens.onSurface),
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
              child: MembershipCard(
                tierLabel: currentTier,
                fet: currentFet,
                paymentStatus: paymentStatus,
              ),
            ),
          ),

          // Tier progress
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing6,
              ),
              child: TierProgress(currentFet: currentFet),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing8),
          ),

          // ── Enhanced Digital Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Digital card',
                          style: TypographyTokens.sectionTitle(),
                        ),
                      ),
                      AfriInfoChip(
                        icon: AfriIcons.share,
                        label: 'Share',
                        onTap: () {
                          // FIXME(#AFRI-104): Open share card modal.
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Share coming soon.')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  DigitalMembershipCardFull(
                    clubName: RuntimeBranding.displayHomeTeamName,
                    tier: currentTier,
                    fanId: user?.publicUserId != null
                        ? AliasGenerator.format(user!.publicUserId!)
                        : '#000000',
                    memberSince: _membership?['joined_at'] != null
                        ? _formatMembershipDate(
                            _membership?['joined_at']?.toString(),
                          )
                        : null,
                    accentColor: primary,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing6),
          ),

          // ── Contribution History ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing6,
              ),
              child: ContributionHistorySection(
                contributions: _contributions,
                currencySymbol: context.afriCurrencySymbol,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing8),
          ),

          // ── Packages header ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenPadding,
              ),
              child: Text('Packages', style: TypographyTokens.sectionTitle()),
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

          if (!_isLoading && _error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: AfriStateView.offline(
                  title: 'Membership unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadPackages,
                ),
              ),
            ),

          if (!_isLoading && _error == null && _packages.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: AfriStateView.empty(
                  title: 'No packages published',
                  message:
                      _emptyMessage ??
                      'Membership packages will appear once the club publishes them.',
                ),
              ),
            ),

          if (!_isLoading && _error == null)
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
                              currentFet == 0
                                  ? 'Earn FET from tickets, fan clubs & contributions.'
                                  : '$currentFet FET earned.',
                              style: theme.textTheme.bodyMedium,
                            ),
                            if (_membership?['expires_at'] != null) ...[
                              const SizedBox(height: SpacingTokens.spacing2),
                              Text(
                                'Renews on ${_formatMembershipDate(_membership?['expires_at']?.toString())}',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.screenPadding,
                0,
                SpacingTokens.screenPadding,
                SpacingTokens.spacing4,
              ),
              child: AfriListRow(
                icon: AfriIcons.clubZone,
                title: 'Fan registry',
                subtitle: 'Browse all supporters',
                onTap: () => context.push('/membership/fans'),
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
                                style: TypographyTokens.labelSmall(primary),
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
                        const SizedBox(height: SpacingTokens.spacing3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _packagePriceLabel(pkg),
                                style: TypographyTokens.monolithFont(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: ColorTokens.clubAccent,
                                ),
                              ),
                            ),
                            if (user != null)
                              AfriButton(
                                label: _isJoining && _joiningTier == tierId
                                    ? 'Processing…'
                                    : _membershipActionLabel(tierId),
                                onTap: () => _activatePackage(pkg),
                                isLoading: _isJoining && _joiningTier == tierId,
                                enabled:
                                    !(_isJoining && _joiningTier == tierId),
                                fullWidth: false,
                              ),
                          ],
                        ),
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

  String _tierLabelFromFet(int fet) {
    if (fet >= 5000) return 'Platinum';
    if (fet >= 2000) return 'Gold';
    if (fet >= 1000) return 'Bronze';
    return 'Fan';
  }

  String _currentTierLabel(String? tierValue, int fet) {
    final trimmed = tierValue?.trim().toLowerCase();
    if (trimmed != null && trimmed.isNotEmpty) {
      return _membershipPackageLabel(trimmed);
    }
    return _tierLabelFromFet(fet);
  }

  String _normalizeContributionStatus(String? rawStatus) {
    return switch ((rawStatus ?? '').trim().toLowerCase()) {
      'confirmed' || 'verified' => 'verified',
      'failed' || 'cancelled' || 'reversed' => 'failed',
      _ => 'pending',
    };
  }

  String _formatMembershipDate(String? rawValue) {
    final date = DateTime.tryParse(rawValue ?? '');
    if (date == null) {
      return 'next year';
    }
    final local = date.toLocal();
    final month = switch (local.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      _ => 'Dec',
    };
    return '${local.day} $month ${local.year}';
  }
}
