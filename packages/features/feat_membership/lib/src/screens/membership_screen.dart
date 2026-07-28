import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:url_launcher/url_launcher.dart';

import '../official_membership_tiers.dart';
import '../providers/membership_provider.dart';
import '../widgets/contribution_history.dart';
import '../widgets/digital_membership_card.dart';
import '../widgets/membership_card.dart';
import '../widgets/tier_progress.dart';

typedef MembershipPackageActivator =
    Future<void> Function(Map<String, dynamic> package);

/// Membership screen — tier display, digital card, membership packages.
class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({
    super.key,
    this.packageActivator,
    this.activationTimeout = const Duration(seconds: 30),
    this.autofocusTier,
  });

  final MembershipPackageActivator? packageActivator;
  final Duration activationTimeout;
  final String? autofocusTier;

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  static const String _supportWhatsApp = String.fromEnvironment(
    'APP_SUPPORT_WHATSAPP',
    defaultValue: '',
  );

  // M-3: Read-side data comes from membershipProvider (AsyncNotifier).
  // Only write-side transient state remains here.
  bool _isJoining = false;
  String? _joiningTier;
  MembershipFailure? _activationFailure;

  MembershipSnapshot? get _snapshot => ref.read(membershipProvider).valueOrNull;

  Map<String, dynamic>? get _membership => _snapshot?.membership;

  List<Map<String, dynamic>> get _applications =>
      _snapshot?.applications ?? const <Map<String, dynamic>>[];

  /// Refresh membership data from the provider after a write operation.
  Future<void> _refreshMembership() async {
    await ref.read(membershipProvider.notifier).refresh();
  }

  Future<void> _activatePackage(Map<String, dynamic> pkg) async {
    if (!ConnectivityService.isOnline) {
      _showError('Connect before changing membership.');
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showInfo('Sign in first to activate membership.');
      context.go('/onboarding');
      return;
    }

    final tierValue = (pkg['tier'] ?? 'imena').toString().toLowerCase();
    final tierLabel = _membershipPackageLabel(tierValue);
    final amount = _packagePrice(pkg);

    setState(() {
      _isJoining = true;
      _joiningTier = tierValue;
      _activationFailure = null;
    });

    try {
      final packageActivator = widget.packageActivator;
      if (packageActivator != null) {
        await packageActivator(pkg).timeout(widget.activationTimeout);
        if (!mounted) return;
        _showSuccess('$tierLabel membership request submitted.');
        return;
      }

      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      final hasPendingRequest = _hasPendingApplicationForTier(tierValue);
      if (hasPendingRequest) {
        _showInfo(
          '$tierLabel membership is already pending payment verification.',
        );
        return;
      }

      if (amount <= 0) {
        await _upsertMembership(
          client: client,
          scope: scope,
          user: user,
          tierValue: tierValue,
        );
        await _refreshMembership();
        if (!mounted) return;
        _showSuccess('$tierLabel membership started.');
        return;
      }

      final route = await _findActivePaymentRoute(client, resolver, scope);
      if (route == null) {
        _showError('Membership payment setup is pending club activation.');
        return;
      }

      final paymentReference =
          'membership-$tierValue-${DateTime.now().millisecondsSinceEpoch}';
      await _createMembershipApplication(
        client: client,
        user: user,
        clubId: scope.clubId!,
        tierValue: tierValue,
        amount: amount,
        paymentReference: paymentReference,
        route: route,
        pkg: pkg,
      );
      await _refreshMembership();
      if (!mounted) return;

      final launched = await MomoDialerService.launchMomoUssd(
        recipient: route.recipientCode,
        amount: amount,
        country: route.country,
        recipientType: PaymentRecipientType.code,
      );

      if (!mounted) return;
      if (!launched) {
        _showError(
          '$tierLabel request was saved, but the MOMO dialer could not open.',
        );
        return;
      }
      _showSuccess(
        '$tierLabel request submitted. Payment verification happens in the background.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _activationFailure = MembershipFailure.fromError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
          _joiningTier = null;
        });
      }
    }
  }

  Future<void> _createMembershipApplication({
    required SupabaseClient client,
    required UserProfile user,
    required int clubId,
    required String tierValue,
    required int amount,
    required String paymentReference,
    required PartnerPaymentRoute route,
    required Map<String, dynamic> pkg,
  }) async {
    final pending = _applications.firstWhere(
      (application) =>
          (application['tier'] ?? '').toString().toLowerCase() == tierValue &&
          (application['status'] ?? '').toString().toLowerCase() == 'pending',
      orElse: () => const <String, dynamic>{},
    );
    if (pending.isNotEmpty) {
      return;
    }

    await client.from('membership_applications').insert({
      'user_id': user.id,
      'club_id': clubId,
      'tier': tierValue,
      'status': 'pending',
      'payment_status': 'unpaid',
      'metadata': {
        'amount': amount,
        'currency_code': context.afriCurrencyCode,
        'currency_symbol': context.afriCurrencySymbol,
        'package_id': pkg['id']?.toString(),
        'package_title': pkg['title']?.toString(),
        'chapter':
            _membership?['chapter']?.toString() ??
            pkg['chapter']?.toString() ??
            'Central',
        'payment_reference': paymentReference,
        'payment_route_id': route.id,
        'payment_route_recipient': route.recipientCode,
        'payment_route_country': route.country.name,
        'payer_phone': user.momoNumber,
      },
    });
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
        'tier': tierValue,
        'status': 'active',
        'points': 0,
        'chapter': 'Main',
        'payment_status': PaymentStatus.verified.value,
        'renewed_at': now.toIso8601String(),
        'expires_at': expiry.toIso8601String(),
      });
      return;
    }

    final currentPoints = (existing['points'] as num?)?.toInt() ?? 0;
    await client
        .from('fan_memberships')
        .update({
          'tier': tierValue,
          'status': 'active',
          'payment_status': PaymentStatus.verified.value,
          'points': currentPoints,
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
    final membership = ref.read(membershipProvider).valueOrNull?.membership;
    final currentTier = (membership?['tier'] ?? '').toString().toLowerCase();
    return currentTier.isNotEmpty && currentTier == tierValue.toLowerCase();
  }

  bool _hasPendingApplicationForTier(String tierValue) {
    final applications =
        ref.read(membershipProvider).valueOrNull?.applications ?? const [];
    return applications.any(
      (application) =>
          (application['tier'] ?? '').toString().toLowerCase() ==
              tierValue.toLowerCase() &&
          (application['status'] ?? '').toString().toLowerCase() == 'pending',
    );
  }

  String _membershipActionLabel(String tierValue) {
    if (_hasPendingApplicationForTier(tierValue)) {
      return 'Pending review';
    }
    final membership = ref.read(membershipProvider).valueOrNull?.membership;
    if (membership == null) {
      return 'Activate';
    }
    if (_isCurrentTier(tierValue)) {
      return 'Renew';
    }
    return 'Switch';
  }

  String _membershipPackageLabel(String tierValue) {
    return officialMembershipLabel(tierValue);
  }

  void _showInfo(String message) {
    if (!mounted) return;
    AfriToast.info(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    AfriToast.success(context, message);
  }

  void _showError(String message) {
    if (!mounted) return;
    AfriToast.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final user = ref.watch(currentUserProvider);

    // M-3: Data from AsyncNotifier provider.
    final asyncMembership = ref.watch(membershipProvider);
    final snapshot = asyncMembership.valueOrNull;
    final isLoading = asyncMembership.isLoading;
    final errorMessage = asyncMembership.hasError
        ? 'Membership details are temporarily unavailable.'
        : null;
    final isSyncing =
        asyncMembership.isRefreshing ||
        (asyncMembership.isLoading && snapshot != null);
    final packages = snapshot?.packages ?? const <Map<String, dynamic>>[];
    final membership = snapshot?.membership;
    final contributions =
        snapshot?.contributions ?? const <ContributionRecord>[];
    final emptyMessage =
        (packages.isEmpty && !isLoading && errorMessage == null)
        ? 'Membership packages will appear once the club publishes them.'
        : null;

    final currentFet = (membership?['points'] as num?)?.toInt() ?? 0;
    final currentTier = _currentTierLabel(
      membership?['tier']?.toString(),
      currentFet,
    );
    final latestPendingApplication = snapshot?.latestPendingApplication;
    final paymentStatus = PaymentStatusX.fromValue(
      membership?['payment_status']?.toString(),
    );

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        elevation: 0,
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
        title: Text('Membership', style: TypographyTokens.headlineSmall()),
      ),
      scrollable: false,
      bodyWrapper: (child) =>
          GradientBackground(routePath: '/membership', child: child),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Digital membership card
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SpacingTokens.spacing6,
                SpacingTokens.spacing4,
                SpacingTokens.spacing6,
                SpacingTokens.spacing6,
              ),
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

          if (snapshot?.isStale == true)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  0,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing6,
                ),
                child: AfriStateBanner(
                  icon: AfriIcons.statusWarning,
                  title: 'Saved membership details',
                  subtitle: snapshot?.recoveryMessage,
                  tone: AfriStateBannerTone.warning,
                ),
              ),
            ),

          // ── Digital card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AfriSectionHeader(
                    title: 'Digital card',
                    padding: EdgeInsets.zero,
                    trailing: AfriInfoChip(
                      icon: AfriIcons.share,
                      label: 'Share',
                      onTap: () async {
                        final supporterId = user?.publicUserId != null
                            ? AliasGenerator.format(user!.publicUserId!)
                            : '000000';
                        await Clipboard.setData(
                          ClipboardData(
                            text:
                                '${RuntimeBranding.displayHomeTeamName} membership\n'
                                'Tier: $currentTier\n'
                                'Supporter ID: #$supporterId',
                          ),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        AfriToast.success(
                          context,
                          'Membership details copied.',
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  DigitalMembershipCardFull(
                    clubName: RuntimeBranding.displayHomeTeamName,
                    tier: currentTier,
                    fanId: user?.publicUserId != null
                        ? AliasGenerator.format(user!.publicUserId!)
                        : '#000000',
                    memberSince: membership?['joined_at'] != null
                        ? _formatMembershipDate(
                            membership?['joined_at']?.toString(),
                          )
                        : null,
                    accentColor: primary,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing8),
          ),

          // ── Status summary ──
          if (!isLoading && errorMessage == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: latestPendingApplication != null
                    ? AfriStateBanner(
                        icon: AfriIcons.statusWarning,
                        title: 'Membership review',
                        subtitle:
                            '${_membershipPackageLabel(latestPendingApplication['tier']?.toString() ?? 'imena')} request is awaiting payment verification.',
                        tone: AfriStateBannerTone.warning,
                      )
                    : GlassCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    currentTier,
                                    style: TypographyTokens.metricValue(
                                      ColorTokens.clubAccent,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: SpacingTokens.spacing2,
                                  ),
                                  Text(
                                    currentFet == 0
                                        ? 'Membership activity appears after ticket, fanclub, and contribution reviews.'
                                        : '$currentFet activity points recorded.',
                                    style: TypographyTokens.bodyMedium(),
                                  ),
                                  if (membership?['expires_at'] != null) ...[
                                    const SizedBox(
                                      height: SpacingTokens.spacing2,
                                    ),
                                    Text(
                                      'Renews on ${_formatMembershipDate(membership?['expires_at']?.toString())}',
                                      style: TypographyTokens.bodySmall(
                                        ColorTokens.onSurfaceVariant,
                                      ),
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

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing6),
          ),

          // ── B-3: Payment Lifecycle Status Card ──
          if (!isLoading &&
              errorMessage == null &&
              latestPendingApplication != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: _PaymentStatusCard(
                  application: latestPendingApplication,
                  tierLabel: _membershipPackageLabel(
                    latestPendingApplication['tier']?.toString() ?? 'imena',
                  ),
                  formatDate: _formatMembershipDate,
                  onContactSupport: () {
                    final phoneNumber = _supportWhatsApp.trim();
                    if (phoneNumber.isNotEmpty) {
                      final sanitizedPhoneNumber = phoneNumber.replaceAll(
                        '+',
                        '',
                      );
                      final uri = Uri.parse(
                        'https://wa.me/$sanitizedPhoneNumber?text=${Uri.encodeComponent('Hi, I need help with my membership payment verification.')}',
                      );
                      unawaited(
                        launchUrl(
                          uri,
                          mode: LaunchMode.externalApplication,
                        ).then((launched) {
                          if (!launched && mounted) {
                            _showError(
                              'Could not open WhatsApp. Please contact support.',
                            );
                          }
                        }),
                      );
                    } else {
                      _showInfo('Support contact is not configured yet.');
                    }
                  },
                ),
              ),
            ),

          // ── Contribution History ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.spacing6,
              ),
              child: ContributionHistorySection(
                contributions: contributions,
                currencySymbol: context.afriCurrencySymbol,
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing8),
          ),

          // ── Registry ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpacingTokens.screenPadding,
              ),
              child: AfriListRow(
                icon: AfriIcons.clubZone,
                title: 'Fan registry',
                subtitle: 'Browse all supporters',
                onTap: () => context.go('/fanzone?section=supporters'),
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing8),
          ),

          // ── Packages ──
          const SliverToBoxAdapter(child: AfriSectionHeader(title: 'Packages')),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing4),
          ),

          if (_isJoining || isSyncing)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  0,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                ),
                child: AfriStateView.loading(
                  key: const ValueKey<String>('membership-syncing'),
                  title: _isJoining
                      ? 'Submitting membership request'
                      : 'Updating membership',
                  message: _isJoining
                      ? 'Keep this screen open while the club receives your request.'
                      : 'Refreshing packages and current membership details.',
                  compact: true,
                ),
              ),
            ),

          if (_activationFailure case final failure?)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  0,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                ),
                child: _MembershipFailureView(
                  failure: failure,
                  onRefresh: () {
                    setState(() => _activationFailure = null);
                    unawaited(_refreshMembership());
                  },
                ),
              ),
            ),

          SliverToBoxAdapter(
            child: AfriAsyncStateView<MembershipSnapshot>(
              value: asyncMembership,
              loading: (_) => const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing6,
                ),
                child: AfriSkeletonList(),
              ),
              error: (_, error, stackTrace) => ConnectivityBuilder(
                builder: (context, isOnline) {
                  if (!isOnline) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing6,
                      ),
                      child: AfriStateView.offline(
                        title: 'Membership unavailable',
                        message: 'Connect to load current membership details.',
                        actionLabel: 'Connection required',
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.spacing6,
                    ),
                    child: _MembershipFailureView(
                      failure: MembershipFailure.fromError(error),
                      onRefresh: _refreshMembership,
                    ),
                  );
                },
              ),
              data: (context, resolvedSnapshot) {
                final resolvedPackages = resolvedSnapshot.packages;
                if (resolvedPackages.isEmpty) {
                  return emptyMessage == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.spacing6,
                          ),
                          child: AfriStateView.empty(
                            title: 'Membership setup pending',
                            message: emptyMessage,
                          ),
                        );
                }

                return _MembershipPackageList(
                  packages: resolvedPackages,
                  user: user,
                  changesBlocked:
                      _activationFailure?.kind ==
                          MembershipFailureKind.permissionDenied ||
                      _activationFailure?.kind ==
                          MembershipFailureKind.securityTimeout,
                  autofocusTier: widget.autofocusTier,
                  packagePriceLabel: _packagePriceLabel,
                  packageLabel: _membershipPackageLabel,
                  actionLabel: _membershipActionLabel,
                  isCurrentJoiningTier: (tierId) =>
                      _isJoining && _joiningTier == tierId,
                  isCurrentTier: _isCurrentTier,
                  hasPendingApplication: _hasPendingApplicationForTier,
                  onActivatePackage: _activatePackage,
                );
              },
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing20),
          ),
        ],
      ),
    );
  }

  String _tierLabelFromFet(int fet) {
    if (fet >= 5000) return 'Gold';
    if (fet >= 2000) return 'Gold';
    if (fet >= 1000) return 'Bronze';
    return 'Imena';
  }

  String _currentTierLabel(String? tierValue, int fet) {
    final trimmed = tierValue?.trim().toLowerCase();
    if (trimmed != null && trimmed.isNotEmpty) {
      return _membershipPackageLabel(trimmed);
    }
    return _tierLabelFromFet(fet);
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

class _MembershipFailureView extends StatelessWidget {
  const _MembershipFailureView({
    required this.failure,
    required this.onRefresh,
  });

  final MembershipFailure failure;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final content = switch (failure.kind) {
      MembershipFailureKind.permissionDenied => (
        stateId: 'permission-denied',
        title: 'Membership change not permitted',
        message:
            'Your account cannot change membership right now. Your current membership remains unchanged.',
        canRefresh: false,
      ),
      MembershipFailureKind.conflict => (
        stateId: 'conflict',
        title: 'Membership details changed',
        message:
            'The club updated these details while you were reviewing them. Refresh before choosing a package.',
        canRefresh: true,
      ),
      MembershipFailureKind.securityTimeout => (
        stateId: 'security-timeout',
        title: 'Membership request timed out',
        message:
            'The secure request window expired. Refresh membership status before trying again.',
        canRefresh: true,
      ),
      MembershipFailureKind.unknown => (
        stateId: 'error',
        title: 'Membership unavailable',
        message: 'Membership details are temporarily unavailable.',
        canRefresh: true,
      ),
    };

    return AfriStateView.error(
      key: ValueKey<String>('membership-${content.stateId}'),
      title: content.title,
      message: content.message,
      actionLabel: content.canRefresh ? 'Refresh' : null,
      onAction: content.canRefresh ? onRefresh : null,
      compact: true,
    );
  }
}

class _MembershipPackageList extends StatelessWidget {
  const _MembershipPackageList({
    required this.packages,
    required this.user,
    required this.changesBlocked,
    required this.autofocusTier,
    required this.packagePriceLabel,
    required this.packageLabel,
    required this.actionLabel,
    required this.isCurrentJoiningTier,
    required this.isCurrentTier,
    required this.hasPendingApplication,
    required this.onActivatePackage,
  });

  final List<Map<String, dynamic>> packages;
  final UserProfile? user;
  final bool changesBlocked;
  final String? autofocusTier;
  final String Function(Map<String, dynamic> pkg) packagePriceLabel;
  final String Function(String tierValue) packageLabel;
  final String Function(String tierValue) actionLabel;
  final bool Function(String tierId) isCurrentJoiningTier;
  final bool Function(String tierId) isCurrentTier;
  final bool Function(String tierId) hasPendingApplication;
  final Future<void> Function(Map<String, dynamic> pkg) onActivatePackage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final pkg in packages)
          _MembershipPackageTile(
            pkg: pkg,
            user: user,
            changesBlocked: changesBlocked,
            autofocus: autofocusTier == (pkg['tier'] ?? '').toString(),
            packagePriceLabel: packagePriceLabel,
            packageLabel: packageLabel,
            actionLabel: actionLabel,
            isCurrentJoiningTier: isCurrentJoiningTier,
            isCurrentTier: isCurrentTier,
            hasPendingApplication: hasPendingApplication,
            onActivatePackage: onActivatePackage,
          ),
      ],
    );
  }
}

class _MembershipPackageTile extends StatelessWidget {
  const _MembershipPackageTile({
    required this.pkg,
    required this.user,
    required this.changesBlocked,
    required this.autofocus,
    required this.packagePriceLabel,
    required this.packageLabel,
    required this.actionLabel,
    required this.isCurrentJoiningTier,
    required this.isCurrentTier,
    required this.hasPendingApplication,
    required this.onActivatePackage,
  });

  final Map<String, dynamic> pkg;
  final UserProfile? user;
  final bool changesBlocked;
  final bool autofocus;
  final String Function(Map<String, dynamic> pkg) packagePriceLabel;
  final String Function(String tierValue) packageLabel;
  final String Function(String tierValue) actionLabel;
  final bool Function(String tierId) isCurrentJoiningTier;
  final bool Function(String tierId) isCurrentTier;
  final bool Function(String tierId) hasPendingApplication;
  final Future<void> Function(Map<String, dynamic> pkg) onActivatePackage;

  @override
  Widget build(BuildContext context) {
    final tierId = (pkg['tier'] ?? 'bronze').toString().toLowerCase();
    final isJoiningTier = isCurrentJoiningTier(tierId);
    final isCurrent = isCurrentTier(tierId);
    final useLargeTextLayout = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final tierLabel = packageLabel(pkg['tier']?.toString() ?? '');
    final statusChip = AfriStatusChip(
      label: isCurrent ? '$tierLabel · Current' : tierLabel,
      tone: isCurrent ? AfriStatusTone.success : AfriStatusTone.info,
    );
    final action = ConnectivityBuilder(
      builder: (context, isOnline) => AfriButton(
        key: ValueKey<String>('membership-action-$tierId'),
        autofocus: autofocus,
        label: changesBlocked
            ? 'Refresh required'
            : !isOnline
            ? 'Connection required'
            : isJoiningTier
            ? 'Submitting'
            : actionLabel(tierId),
        onTap: () => onActivatePackage(pkg),
        isLoading: false,
        enabled:
            isOnline &&
            !changesBlocked &&
            !isJoiningTier &&
            !hasPendingApplication(tierId),
        fullWidth: useLargeTextLayout,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SpacingTokens.spacing6,
        0,
        SpacingTokens.spacing6,
        SpacingTokens.spacing3,
      ),
      child: Semantics(
        container: true,
        selected: isCurrent,
        label: isCurrent
            ? '${packageLabel(pkg['tier']?.toString() ?? '')} membership package, current'
            : null,
        child: AfriSurfaceCard(
          onTap: () => context.push('/membership/tier/$tierId'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (useLargeTextLayout) ...[
                Text(
                  (pkg['title'] ?? pkg['tier'] ?? 'Package').toString(),
                  maxLines: 2,
                  style: TypographyTokens.titleMedium(),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                Align(alignment: Alignment.centerLeft, child: statusChip),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (pkg['title'] ?? pkg['tier'] ?? 'Package').toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypographyTokens.titleMedium(),
                      ),
                    ),
                    const SizedBox(width: SpacingTokens.spacing3),
                    statusChip,
                  ],
                ),
              if (pkg['description'] != null) ...[
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  pkg['description'].toString(),
                  style: TypographyTokens.bodySmall(
                    ColorTokens.onSurfaceVariant,
                  ),
                  maxLines: useLargeTextLayout ? 5 : 2,
                  overflow: useLargeTextLayout
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: SpacingTokens.spacing4),
              if (useLargeTextLayout)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      packagePriceLabel(pkg),
                      style: TypographyTokens.titleMedium(
                        ColorTokens.clubAccent,
                      ),
                    ),
                    if (user != null) ...[
                      const SizedBox(height: SpacingTokens.spacing3),
                      action,
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        packagePriceLabel(pkg),
                        style: TypographyTokens.titleMedium(
                          ColorTokens.clubAccent,
                        ),
                      ),
                    ),
                    if (user != null) Flexible(child: action),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── B-3: Payment Lifecycle Status Card ──────────────────────────────────

/// Shows transparent payment verification status for a pending membership
/// application. Replaces the opaque "background verification" messaging
/// with a clear step-by-step lifecycle and support CTA.
class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard({
    required this.application,
    required this.tierLabel,
    required this.formatDate,
    required this.onContactSupport,
  });

  final Map<String, dynamic> application;
  final String tierLabel;
  final String Function(String?) formatDate;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    final metadata = application['metadata'] is Map
        ? Map<String, dynamic>.from(application['metadata'] as Map)
        : const <String, dynamic>{};
    final paymentStatus = (application['payment_status'] ?? 'unpaid')
        .toString()
        .toLowerCase();
    final applicationDate = application['application_date']?.toString();
    final amount = metadata['amount'];
    final currencySymbol = metadata['currency_symbol'] ?? 'RWF';

    final steps = <_PaymentStep>[
      _PaymentStep(
        label: 'Payment sent',
        isComplete: paymentStatus != 'unpaid',
        isCurrent: paymentStatus == 'unpaid',
      ),
      _PaymentStep(
        label: 'Verifying payment',
        isComplete: paymentStatus == 'verified',
        isCurrent: paymentStatus == 'pending' || paymentStatus == 'unpaid',
      ),
      _PaymentStep(
        label: 'Membership confirmed',
        isComplete: paymentStatus == 'verified',
        isCurrent: false,
      ),
    ];

    return AfriSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AfriIcons.statusInfo, size: 20, color: ColorTokens.warning),
              const SizedBox(width: SpacingTokens.spacing3),
              Expanded(
                child: Text(
                  '$tierLabel MEMBERSHIP REQUEST',
                  style: TypographyTokens.labelMedium(ColorTokens.warning),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),

          // Payment amount
          if (amount != null)
            Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: Text(
                'Amount: $currencySymbol ${CurrencyFormatter(currencyCode: currencySymbol.toString(), currencySymbol: currencySymbol.toString()).formatPlain(amount is num ? amount.toInt() : int.tryParse(amount.toString()) ?? 0)}',
                style: TypographyTokens.bodyMedium(),
              ),
            ),

          // Status steps
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing2),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: step.isComplete
                          ? ColorTokens.success.withValues(alpha: 0.2)
                          : step.isCurrent
                          ? ColorTokens.warning.withValues(alpha: 0.2)
                          : ColorTokens.surfaceContainerHighest,
                    ),
                    alignment: Alignment.center,
                    child: step.isComplete
                        ? Icon(
                            AfriIcons.verified,
                            size: 12,
                            color: ColorTokens.success,
                          )
                        : step.isCurrent
                        ? Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: ColorTokens.warning,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Text(
                    step.label,
                    style: TypographyTokens.bodySmall(
                      step.isComplete
                          ? ColorTokens.success
                          : step.isCurrent
                          ? ColorTokens.onSurface
                          : ColorTokens.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: SpacingTokens.spacing3),

          // Estimated wait time
          Text(
            'Verification typically takes 1–24 hours. '
            'You will be notified once confirmed.',
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),

          if (applicationDate != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              'Requested: ${formatDate(applicationDate)}',
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            ),
          ],

          const SizedBox(height: SpacingTokens.spacing4),

          // Contact support CTA
          AfriButton(
            label: 'CONTACT SUPPORT',
            variant: AfriButtonVariant.secondary,
            icon: AfriIcons.chat,
            onTap: onContactSupport,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _PaymentStep {
  const _PaymentStep({
    required this.label,
    required this.isComplete,
    required this.isCurrent,
  });

  final String label;
  final bool isComplete;
  final bool isCurrent;
}
