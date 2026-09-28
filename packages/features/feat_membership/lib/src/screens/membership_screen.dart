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

import '../official_membership_tiers.dart';
import '../providers/membership_mutation_gateway.dart';
import '../providers/membership_provider.dart';
import '../widgets/contribution_history.dart';
import '../widgets/digital_membership_card.dart';

typedef MembershipPackageActivator =
    Future<void> Function(Map<String, dynamic> package);

/// Membership screen — tier display, digital card, membership packages.
class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({
    super.key,
    this.packageActivator,
    this.activationTimeout = const Duration(seconds: 30),
    this.autofocusTier,
    this.paymentLauncher,
  });

  final MembershipPackageActivator? packageActivator;
  final Duration activationTimeout;
  final String? autofocusTier;
  final Future<bool> Function(String recipient, int amount, String country)?
  paymentLauncher;

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen>
    with WidgetsBindingObserver {
  Timer? _paymentRefresh;
  int _paymentRefreshCount = 0;
  String? _paymentTier;
  String? _previousRenewedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _paymentRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _paymentTier != null) {
      unawaited(_refreshPayment());
    }
  }

  Future<void> _refreshPayment() async {
    if (!mounted ||
        !ConnectivityService.isOnline ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    await _refreshMembership();
    if (!mounted) return;
    final membership = _membership;
    if (++_paymentRefreshCount >= 60 ||
        (membership?['tier'] == _paymentTier &&
            membership?['renewed_at']?.toString() != _previousRenewedAt)) {
      _paymentRefresh?.cancel();
      _paymentTier = null;
    }
  }

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
    if (_isJoining) return;
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

      if (amount <= 0) {
        throw StateError('A paid membership price is required.');
      }
      final payment = await ref
          .read(membershipMutationGatewayProvider)
          .preparePayment(tier: tierValue, clubId: int.parse(user.clubId))
          .timeout(widget.activationTimeout);
      if (!mounted ||
          ref.read(currentUserProvider)?.id != user.id ||
          ref.read(currentUserProvider)?.clubId != user.clubId) {
        return;
      }
      final launched = widget.paymentLauncher != null
          ? await widget.paymentLauncher!(
              payment['recipient_code'] as String,
              (payment['amount'] as num).toInt(),
              payment['country'] as String,
            )
          : await MomoDialerService.launchPreparedUssd(
              payment['ussd_code'] as String,
            );

      if (!mounted) return;
      if (!launched) {
        _showError(l10n.membershipDialerFailed(tierLabel));
        return;
      }
      _paymentTier = tierValue;
      _previousRenewedAt = _membership?['renewed_at']?.toString();
      _paymentRefreshCount = 0;
      _paymentRefresh?.cancel();
      _paymentRefresh = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_refreshPayment()),
      );
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

  int _packagePrice(Map<String, dynamic> pkg) {
    final annual = (pkg['annual_price'] as num?)?.toInt();
    final standard = (pkg['price'] as num?)?.toInt();
    return annual ?? standard ?? 0;
  }

  String _packagePriceLabel(Map<String, dynamic> pkg) {
    final amount = _packagePrice(pkg);
    if (amount <= 0) {
      return 'Price unavailable';
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

  String _membershipActionLabel(String tierValue) {
    final l10n = context.afriL10n;
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

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
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
                      child: GlassCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                  if (membership?['expires_at'] != null) ...[
                                    const SizedBox(
                                      height: SpacingTokens.spacing2,
                                    ),
                                    Text(
                                      l10n.membershipRenewsOn(
                                        _formatMembershipDate(
                                          membership?['expires_at']?.toString(),
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
                      title: l10n.fanClubsTitle,
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
                      final resolvedPackages = resolvedSnapshot.packages
                          .where((pkg) => _packagePrice(pkg) > 0)
                          .toList(growable: false);
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
                        onActivatePackage: _activatePackage,
                      );
                    },
                  ),
                ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: AfriClubBottomNav.contentBottomInset(context),
                  ),
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
  final Future<void> Function(Map<String, dynamic> pkg) onActivatePackage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final tierId = (pkg['tier'] ?? 'bronze').toString().toLowerCase();
    final isJoiningTier = isCurrentJoiningTier(tierId);
    final isCurrent = isCurrentTier(tierId);
    final tierLabel = packageLabel(pkg['tier']?.toString() ?? '');
    final action = ConnectivityBuilder(
      builder: (context, isOnline) => AfriButton(
        key: ValueKey<String>('membership-action-$tierId'),
        autofocus: autofocus,
        labelMaxLines: 3,
        label: changesBlocked
            ? l10n.membershipRefreshRequired
            : !isOnline
            ? l10n.connectionRequired
            : isJoiningTier
            ? l10n.membershipSubmittingAction
            : actionLabel(tierId),
        onTap: () => onActivatePackage(pkg),
        isLoading: false,
        enabled: isOnline && !changesBlocked && !isJoiningTier,
        fullWidth: true,
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
        child: AfriEditorialCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      isCurrent
                          ? l10n.membershipCurrentStatus(tierLabel)
                          : tierLabel,
                      style: TypographyTokens.titleLarge(),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  AfriTeamCrest(
                    name: RuntimeBranding.displayHomeTeamName,
                    size: 36,
                  ),
                ],
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                packagePriceLabel(pkg),
                style: TypographyTokens.headlineMedium(),
              ),
              if ((pkg['description']?.toString().trim() ?? '').isNotEmpty) ...[
                const SizedBox(height: SpacingTokens.spacing3),
                Text(
                  pkg['description'].toString(),
                  style: TypographyTokens.bodyMedium(),
                ),
              ],
              if (user != null) ...[
                const SizedBox(height: SpacingTokens.spacing5),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
