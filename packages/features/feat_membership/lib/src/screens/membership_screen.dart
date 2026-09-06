import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
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
import '../providers/membership_mutation_gateway.dart';
import '../providers/membership_provider.dart';
import '../widgets/contribution_history.dart';
import '../widgets/digital_membership_card.dart';
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

  /// Refresh membership data from the provider after a write operation.
  Future<void> _refreshMembership() async {
    await ref.read(membershipProvider.notifier).refresh();
  }

  Future<void> _activatePackage(Map<String, dynamic> pkg) async {
    final l10n = context.afriL10n;
    if (!ConnectivityService.isOnline) {
      _showError(l10n.membershipConnectBeforeChange);
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showInfo(l10n.membershipSignInFirst);
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
        _showSuccess(l10n.membershipRequestSubmitted(tierLabel));
        return;
      }

      final hasPendingRequest = _hasPendingApplicationForTier(tierValue);
      if (hasPendingRequest) {
        _showInfo(l10n.membershipAlreadyPending(tierLabel));
        return;
      }

      final mutationGateway = ref.read(membershipMutationGatewayProvider);
      if (amount <= 0) {
        if (tierValue != 'fan') {
          throw UnsupportedError(
            'Only the server-authorized free fan tier can be activated.',
          );
        }
        await mutationGateway.activateFreeMembership().timeout(
          widget.activationTimeout,
        );
        await _refreshMembership();
        if (!mounted) return;
        _showSuccess(l10n.membershipStarted(tierLabel));
        return;
      }

      if (!_isPhysicalMembershipPackage(pkg)) {
        throw UnsupportedError(
          'This payment route supports approved physical memberships only.',
        );
      }

      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();
      final route = await _findActivePaymentRoute(client, resolver, scope);
      if (route == null) {
        _showError(l10n.membershipPaymentSetupPending);
        return;
      }

      final paymentReference =
          'membership-$tierValue-${DateTime.now().millisecondsSinceEpoch}';
      final application = await mutationGateway
          .submitPhysicalApplication(
            tier: tierValue,
            paymentReference: paymentReference,
            chapter: _membershipChapter(pkg),
          )
          .timeout(widget.activationTimeout);
      final authoritativeAmount = _applicationAmount(application);
      if (authoritativeAmount <= 0) {
        throw StateError(
          'The server did not return an authoritative membership price.',
        );
      }
      await _refreshMembership();
      if (!mounted) return;

      final launched = await MomoDialerService.launchMomoUssd(
        recipient: route.recipientCode,
        amount: authoritativeAmount,
        country: route.country,
        recipientType: PaymentRecipientType.code,
      );

      if (!mounted) return;
      if (!launched) {
        _showError(l10n.membershipDialerFailed(tierLabel));
        return;
      }
      _showSuccess(l10n.membershipSubmittedBackground(tierLabel));
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

  Future<PartnerPaymentRoute?> _findActivePaymentRoute(
    SupabaseClient client,
    ClubScopeResolver resolver,
    ClubScope scope,
  ) async {
    var query = client
        .from('partner_payment_routes')
        .select(
          'id,partner_id,club_id,partner_name,partner_slug,country,provider,'
          'recipient_code,reconciliation_label,status',
        )
        .eq('status', 'active');
    query = resolver.apply(query, scope);
    final rows = await query.limit(1);
    if (rows.isEmpty) {
      return null;
    }
    return PartnerPaymentRoute.fromJson(rows.first);
  }

  int _packagePrice(Map<String, dynamic> pkg) {
    final annual = (pkg['annual_price'] as num?)?.toInt();
    final standard = (pkg['price'] as num?)?.toInt();
    return annual ?? standard ?? 0;
  }

  bool _isPhysicalMembershipPackage(Map<String, dynamic> pkg) {
    if (pkg['store_billing_required'] != false) return false;
    final benefitScope = pkg['benefit_scope']?.toString().trim().toLowerCase();
    if (benefitScope == 'physical_membership') return true;

    final packageId = pkg['id']?.toString() ?? '';
    final storePolicyScope = pkg['store_policy_scope']
        ?.toString()
        .trim()
        .toLowerCase();
    return packageId.startsWith('official-') &&
        storePolicyScope == 'physical_membership_and_live_event_access';
  }

  String _membershipChapter(Map<String, dynamic> pkg) {
    final value =
        _membership?['chapter']?.toString().trim() ??
        pkg['chapter']?.toString().trim();
    return value == null || value.isEmpty ? 'Main' : value;
  }

  int _applicationAmount(Map<String, dynamic> application) {
    final metadata = application['metadata'];
    if (metadata is! Map) return 0;
    final rawAmount = metadata['amount'];
    if (rawAmount is num) return rawAmount.toInt();
    return int.tryParse(rawAmount?.toString() ?? '') ?? 0;
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
    final l10n = context.afriL10n;
    if (_hasPendingApplicationForTier(tierValue)) {
      return l10n.membershipPendingReviewAction;
    }
    final membership = ref.read(membershipProvider).valueOrNull?.membership;
    if (membership == null) {
      return l10n.membershipActivateAction;
    }
    if (_isCurrentTier(tierValue)) {
      return l10n.membershipRenewAction;
    }
    return l10n.membershipSwitchAction;
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
    final l10n = context.afriL10n;
    final user = ref.watch(currentUserProvider);

    // M-3: Data from AsyncNotifier provider.
    final asyncMembership = ref.watch(membershipProvider);
    final snapshot = asyncMembership.valueOrNull;
    final isLoading = asyncMembership.isLoading;
    final errorMessage = asyncMembership.hasError
        ? l10n.membershipUnavailableMessage
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
        ? l10n.membershipPackageEmpty
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
      showAppBar: false,
      bottomNavigationAware: true,
      scrollable: false,
      bodyWrapper: (child) =>
          GradientBackground(routePath: '/membership', child: child),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                child: AfriTopCommandBar(
                  searchHint: l10n.homeSearchHint,
                  onSearchTap: () => context.push('/search'),
                  onAvatarTap: () => context.go('/settings'),
                  actions: [
                    AfriTopCommandAction(
                      icon: AfriIcons.notifications,
                      label: l10n.homeNotifications,
                      onTap: () => context.push('/settings/notifications'),
                    ),
                  ],
                ),
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
                    title: l10n.membershipDigitalCard,
                    padding: EdgeInsets.zero,
                    trailing: AfriInfoChip(
                      icon: AfriIcons.share,
                      label: l10n.share,
                      onTap: () async {
                        final supporterId = user?.publicUserId != null
                            ? AliasGenerator.format(user!.publicUserId!)
                            : '------';
                        await Clipboard.setData(
                          ClipboardData(
                            text: l10n.membershipShareText(
                              RuntimeBranding.displayHomeTeamName,
                              currentTier,
                              supporterId,
                            ),
                          ),
                        );
                        if (!context.mounted) {
                          return;
                        }
                        AfriToast.success(context, l10n.membershipCopied);
                      },
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  DigitalMembershipCardFull(
                    statusLabel:
                        paymentStatus == PaymentStatus.pendingVerification
                        ? l10n.contributionPendingVerification
                        : null,
                    clubName: RuntimeBranding.displayHomeTeamName,
                    tier: currentTier,
                    fanId: user?.publicUserId != null
                        ? AliasGenerator.format(user!.publicUserId!)
                        : '#------',
                    memberSince: membership?['joined_at'] != null
                        ? _formatMembershipDate(
                            membership?['joined_at']?.toString(),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: SpacingTokens.spacing4),
          ),
          DecoratedSliver(
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerLowest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(ShapeTokens.radiusXl),
              ),
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                    child: TierProgress(qualification: snapshot?.qualification),
                  ),
                ),
                if (snapshot?.isStale == true)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(
                        SpacingTokens.screenPadding,
                      ),
                      child: AfriStateBanner(
                        icon: AfriIcons.statusWarning,
                        title: l10n.membershipSavedDetails,
                        subtitle: snapshot?.recoveryMessage,
                        tone: AfriStateBannerTone.warning,
                      ),
                    ),
                  ),
                // ── Status summary ──
                if (!isLoading && errorMessage == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.screenPadding,
                      ),
                      child: latestPendingApplication != null
                          ? AfriStateBanner(
                              icon: AfriIcons.statusWarning,
                              title: l10n.membershipReviewTitle,
                              subtitle: l10n.membershipReviewSubtitle(
                                _membershipPackageLabel(
                                  latestPendingApplication['tier']
                                          ?.toString() ??
                                      'imena',
                                ),
                              ),
                              tone: AfriStateBannerTone.warning,
                            )
                          : GlassCard(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          currentTier,
                                          style: TypographyTokens.metricValue(
                                            ColorTokens.primaryContainer,
                                          ),
                                        ),
                                        const SizedBox(
                                          height: SpacingTokens.spacing2,
                                        ),
                                        Text(
                                          currentFet == 0
                                              ? l10n.membershipActivityPending
                                              : l10n.membershipActivityRecorded(
                                                  currentFet,
                                                ),
                                          style: TypographyTokens.bodyMedium(),
                                        ),
                                        if (membership?['expires_at'] !=
                                            null) ...[
                                          const SizedBox(
                                            height: SpacingTokens.spacing2,
                                          ),
                                          Text(
                                            l10n.membershipRenewsOn(
                                              _formatMembershipDate(
                                                membership?['expires_at']
                                                    ?.toString(),
                                              ),
                                            ),
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
                        horizontal: SpacingTokens.screenPadding,
                      ),
                      child: _PaymentStatusCard(
                        application: latestPendingApplication,
                        tierLabel: _membershipPackageLabel(
                          latestPendingApplication['tier']?.toString() ??
                              'imena',
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
                              'https://wa.me/$sanitizedPhoneNumber?text=${Uri.encodeComponent(l10n.membershipSupportMessage)}',
                            );
                            unawaited(
                              launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              ).then((launched) {
                                if (!launched && mounted) {
                                  _showError(
                                    l10n.membershipWhatsAppUnavailable,
                                  );
                                }
                              }),
                            );
                          } else {
                            _showInfo(l10n.membershipSupportNotConfigured);
                          }
                        },
                      ),
                    ),
                  ),

                // ── Contribution History ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SpacingTokens.screenPadding,
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
                      title: l10n.fanRegistryTitle,
                      subtitle: l10n.fanRegistryBrowseAll,
                      onTap: () => context.go('/fan-clubs'),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: SpacingTokens.spacing8),
                ),

                // ── Packages ──
                SliverToBoxAdapter(
                  child: AfriSectionHeader(title: l10n.membershipPackagesTitle),
                ),

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
                            ? l10n.membershipSubmittingTitle
                            : l10n.membershipUpdatingTitle,
                        message: _isJoining
                            ? l10n.membershipSubmittingMessage
                            : l10n.membershipUpdatingMessage,
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
                        horizontal: SpacingTokens.screenPadding,
                      ),
                      child: AfriSkeletonList(),
                    ),
                    error: (_, error, stackTrace) => ConnectivityBuilder(
                      builder: (context, isOnline) {
                        if (!isOnline) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SpacingTokens.screenPadding,
                            ),
                            child: AfriStateView.offline(
                              title: l10n.membershipOfflineTitle,
                              message: l10n.membershipOfflineMessage,
                              actionLabel: l10n.connectionRequired,
                            ),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SpacingTokens.screenPadding,
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
                                  horizontal: SpacingTokens.screenPadding,
                                ),
                                child: AfriStateView.empty(
                                  title: l10n.membershipSetupPending,
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
          ),
        ],
      ),
    );
  }

  String _currentTierLabel(String? tierValue, int fet) {
    final trimmed = tierValue?.trim().toLowerCase();
    if (trimmed != null && trimmed.isNotEmpty) {
      return _membershipPackageLabel(trimmed);
    }
    return context.afriL10n.membershipStatusUnconfirmed;
  }

  String _formatMembershipDate(String? rawValue) {
    final date = DateTime.tryParse(rawValue ?? '');
    if (date == null) {
      return context.afriL10n.membershipDateUnconfirmed;
    }
    final local = date.toLocal();
    final l10n = context.afriL10n;
    final month = switch (local.month) {
      1 => l10n.membershipMonthJan,
      2 => l10n.membershipMonthFeb,
      3 => l10n.membershipMonthMar,
      4 => l10n.membershipMonthApr,
      5 => l10n.membershipMonthMay,
      6 => l10n.membershipMonthJun,
      7 => l10n.membershipMonthJul,
      8 => l10n.membershipMonthAug,
      9 => l10n.membershipMonthSep,
      10 => l10n.membershipMonthOct,
      11 => l10n.membershipMonthNov,
      _ => l10n.membershipMonthDec,
    };
    return l10n.membershipDate(local.day, month, local.year);
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
    final l10n = context.afriL10n;
    final content = switch (failure.kind) {
      MembershipFailureKind.permissionDenied => (
        stateId: 'permission-denied',
        title: l10n.membershipChangeDeniedTitle,
        message: l10n.membershipChangeDeniedMessage,
        canRefresh: false,
      ),
      MembershipFailureKind.conflict => (
        stateId: 'conflict',
        title: l10n.membershipChangedTitle,
        message: l10n.membershipChangedMessage,
        canRefresh: true,
      ),
      MembershipFailureKind.securityTimeout => (
        stateId: 'security-timeout',
        title: l10n.membershipTimeoutTitle,
        message: l10n.membershipTimeoutMessage,
        canRefresh: true,
      ),
      MembershipFailureKind.unknown => (
        stateId: 'error',
        title: l10n.membershipOfflineTitle,
        message: l10n.membershipUnavailableMessage,
        canRefresh: true,
      ),
    };

    return AfriStateView.error(
      key: ValueKey<String>('membership-${content.stateId}'),
      title: content.title,
      message: content.message,
      actionLabel: content.canRefresh ? l10n.membershipRefreshAction : null,
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
    final l10n = context.afriL10n;
    final tierId = (pkg['tier'] ?? 'bronze').toString().toLowerCase();
    final isJoiningTier = isCurrentJoiningTier(tierId);
    final isCurrent = isCurrentTier(tierId);
    final useLargeTextLayout = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final tierLabel = packageLabel(pkg['tier']?.toString() ?? '');
    final statusChip = AfriStatusChip(
      label: isCurrent ? l10n.membershipCurrentStatus(tierLabel) : tierLabel,
      tone: isCurrent ? AfriStatusTone.success : AfriStatusTone.info,
    );
    final action = ConnectivityBuilder(
      builder: (context, isOnline) => AfriButton(
        key: ValueKey<String>('membership-action-$tierId'),
        autofocus: autofocus,
        label: changesBlocked
            ? l10n.membershipRefreshRequired
            : !isOnline
            ? l10n.connectionRequired
            : isJoiningTier
            ? l10n.membershipSubmittingAction
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
            ? l10n.membershipPackageCurrentSemantic(
                packageLabel(pkg['tier']?.toString() ?? ''),
              )
            : null,
        child: AfriSurfaceCard(
          onTap: () => context.push('/membership/tier/$tierId'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (useLargeTextLayout) ...[
                Text(
                  (pkg['title'] ??
                          pkg['tier'] ??
                          l10n.membershipPackageFallback)
                      .toString(),
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
                        (pkg['title'] ??
                                pkg['tier'] ??
                                l10n.membershipPackageFallback)
                            .toString(),
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
                        ColorTokens.primaryContainer,
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
                          ColorTokens.primaryContainer,
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
    final l10n = context.afriL10n;
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
        label: l10n.membershipPaymentSent,
        isComplete: paymentStatus != 'unpaid',
        isCurrent: paymentStatus == 'unpaid',
      ),
      _PaymentStep(
        label: l10n.membershipPaymentVerifying,
        isComplete: paymentStatus == 'verified',
        isCurrent: paymentStatus == 'pending' || paymentStatus == 'unpaid',
      ),
      _PaymentStep(
        label: l10n.membershipConfirmed,
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
                  l10n.membershipRequestTitle(tierLabel),
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
                l10n.membershipAmount(
                  currencySymbol.toString(),
                  CurrencyFormatter(
                    currencyCode: currencySymbol.toString(),
                    currencySymbol: currencySymbol.toString(),
                  ).formatPlain(
                    amount is num
                        ? amount.toInt()
                        : int.tryParse(amount.toString()) ?? 0,
                  ),
                ),
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
            l10n.membershipVerificationTime,
            style: TypographyTokens.bodySmall(ColorTokens.onSurfaceVariant),
          ),

          if (applicationDate != null) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(
              l10n.membershipRequestedOn(formatDate(applicationDate)),
              style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
            ),
          ],

          const SizedBox(height: SpacingTokens.spacing4),

          // Contact support CTA
          AfriButton(
            label: l10n.contactSupport,
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
