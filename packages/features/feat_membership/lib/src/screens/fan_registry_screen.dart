import 'dart:async';

import 'package:core_feature_config/core_feature_config.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../official_membership_tiers.dart';

/// Fan registry screen — searchable supporter list for the active club scope.
class FanRegistryScreen extends ConsumerStatefulWidget {
  const FanRegistryScreen({super.key});

  @override
  ConsumerState<FanRegistryScreen> createState() => _FanRegistryScreenState();
}

class _FanRegistryScreenState extends ConsumerState<FanRegistryScreen> {
  static const int _pageSize = 50;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<FanMembership> _fans = const [];
  String? _partnerId;
  String? _error;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _reloadToken = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    unawaited(_reloadFans());
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _resolvePartnerId() async {
    if (_partnerId != null && _partnerId!.isNotEmpty) {
      return _partnerId!;
    }
    final client = ref.read(supabaseClientProvider);
    final resolver = ClubScopeResolver(client: client);
    final scope = await resolver.requireResolved();

    final resolvedPartnerId = scope.partnerId.isNotEmpty
        ? scope.partnerId
        : scope.clubId?.toString();
    if (resolvedPartnerId == null || resolvedPartnerId.isEmpty) {
      throw StateError('Fan registry requires an active club scope.');
    }

    _partnerId = resolvedPartnerId;
    return resolvedPartnerId;
  }

  String? get _searchQuery {
    if (!ref.read(storeReleasePolicyProvider).allowsCrossUserText) {
      return null;
    }
    final query = _searchController.text.trim();
    return query.isEmpty ? null : query;
  }

  Future<void> _reloadFans() async {
    final token = ++_reloadToken;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final fans = await _fetchFans(limit: _pageSize, offset: 0);
      if (!mounted || token != _reloadToken) return;
      setState(() {
        _fans = fans;
        _hasMore = fans.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FanRegistryScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted || token != _reloadToken) return;
      setState(() {
        _fans = const [];
        _hasMore = false;
        _isLoading = false;
        _isLoadingMore = false;
        _error = context.afriL10n.fanRegistryUnavailableMessage;
      });
    }
  }

  Future<List<FanMembership>> _fetchFans({
    required int limit,
    required int offset,
  }) async {
    final partnerId = await _resolvePartnerId();
    return ref
        .read(clubRepositoryProvider)
        .getMembers(
          partnerId,
          searchQuery: _searchQuery,
          limit: limit,
          offset: offset,
        );
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final token = _reloadToken;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = await _fetchFans(limit: _pageSize, offset: _fans.length);
      if (!mounted || token != _reloadToken) return;
      setState(() {
        _fans = [..._fans, ...nextPage];
        _hasMore = nextPage.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FanRegistryScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted || token != _reloadToken) return;
      setState(() {
        _isLoadingMore = false;
      });
      AfriToast.error(context, context.afriL10n.fanRegistryLoadMoreFailure);
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 280) {
      unawaited(_loadMore());
    }
  }

  void _handleSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      AfriMotion.emphasized,
      () => unawaited(_reloadFans()),
    );
    setState(() {});
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    unawaited(_reloadFans());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final primary = ColorTokens.clubPrimary;
    final allowsCrossUserText = ref.watch(
      storeReleasePolicyProvider.select((policy) => policy.allowsCrossUserText),
    );
    final fansLabel = l10n.fanRegistryLoaded(_fans.length);
    final summaryLabel = _searchQuery == null
        ? l10n.fanRegistrySummary
        : l10n.fanRegistryFiltered(_searchQuery!);

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
          l10n.fanRegistryTitle.toUpperCase(),
          style: TypographyTokens.titleLarge().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      scrollable: false,
      child: AfriRefreshIndicator(
        color: ColorTokens.clubAccent,
        onRefresh: _reloadFans,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                  SpacingTokens.spacing6,
                  SpacingTokens.spacing4,
                ),
                child: GlassCard(
                  animate: false,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            ShapeTokens.radiusMd,
                          ),
                        ),
                        child: Icon(
                          AfriIcons.members,
                          color: primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: SpacingTokens.spacing4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fansLabel.toUpperCase(),
                              style: TypographyTokens.titleMedium().copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing1),
                            Text(
                              summaryLabel,
                              style: TypographyTokens.bodyMedium(
                                ColorTokens.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (allowsCrossUserText)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    0,
                    SpacingTokens.screenPadding,
                    SpacingTokens.spacing4,
                  ),
                  child: AfriInputField(
                    controller: _searchController,
                    hint: l10n.fanRegistrySearchHint,
                    prefixIcon: AfriIcons.search,
                    onChanged: _handleSearchChanged,
                    textInputAction: TextInputAction.search,
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : AfriIconButton(
                            icon: AfriIcons.close,
                            onTap: _clearSearch,
                            tooltip: l10n.searchClearTooltip,
                            filled: false,
                          ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.screenPadding,
                    0,
                    SpacingTokens.screenPadding,
                    SpacingTokens.spacing4,
                  ),
                  child: AfriStateBanner(
                    icon: AfriIcons.visibilityOff,
                    title: context.afriL10n.gameAliasOnly,
                    subtitle: context.afriL10n.gameAliasOnlyDescription,
                    tone: AfriStateBannerTone.info,
                    compact: true,
                  ),
                ),
              ),
            FanRegistryResultsSliver(
              isLoading: _isLoading,
              error: _error,
              fans: _fans,
              isLoadingMore: _isLoadingMore,
              onRetry: () => unawaited(_reloadFans()),
            ),
            FanRegistryLoadingMoreSliver(isLoadingMore: _isLoadingMore),
          ],
        ),
      ),
    );
  }
}

class FanRegistryResultsSliver extends StatelessWidget {
  const FanRegistryResultsSliver({
    super.key,
    required this.isLoading,
    required this.error,
    required this.fans,
    required this.isLoadingMore,
    required this.onRetry,
  });

  final bool isLoading;
  final String? error;
  final List<FanMembership> fans;
  final bool isLoadingMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: SpacingTokens.spacing6),
          child: AfriSkeletonList(),
        ),
      );
    }

    if (error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpacingTokens.spacing6,
          ),
          child: AfriStateView.offline(
            title: context.afriL10n.fanRegistryUnavailable,
            message: error!,
            actionLabel: context.afriL10n.retry,
            onAction: onRetry,
          ),
        ),
      );
    }

    if (fans.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final fan = fans[index];
        return Padding(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            0,
            SpacingTokens.spacing6,
            index == fans.length - 1 && !isLoadingMore
                ? SpacingTokens.spacing20
                : SpacingTokens.spacing3,
          ),
          child: _FanRegistryCard(fan: fan),
        );
      }, childCount: fans.length),
    );
  }
}

class FanRegistryLoadingMoreSliver extends StatelessWidget {
  const FanRegistryLoadingMoreSliver({super.key, required this.isLoadingMore});

  final bool isLoadingMore;

  @override
  Widget build(BuildContext context) {
    if (!isLoadingMore) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return const SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          SpacingTokens.spacing6,
          SpacingTokens.spacing2,
          SpacingTokens.spacing6,
          SpacingTokens.spacing12,
        ),
        child: AfriLoadingIndicator(strokeWidth: 2.6),
      ),
    );
  }
}

class _FanRegistryCard extends StatelessWidget {
  const _FanRegistryCard({required this.fan});

  final FanMembership fan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final tierColor = _tierColor(fan.tier);
    final statusColor = _statusColor(fan.paymentStatus);
    final membershipNumber = fan.membershipNumber.trim();

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(ShapeTokens.radiusMd),
                ),
                child: Icon(fan.tier.icon, color: tierColor, size: 24),
              ),
              const SizedBox(width: SpacingTokens.spacing4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fan.displayName.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TypographyTokens.titleMedium().copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (membershipNumber.isNotEmpty) ...[
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        membershipNumber,
                        style: TypographyTokens.bodyMedium(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Text(
                fan.points <= 0
                    ? l10n.fanRegistryPending
                    : l10n.fanRegistryActivity(fan.points),
                style: TypographyTokens.titleSmall(
                  ColorTokens.clubAccent,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: [
              _RegistryChip(
                label: officialMembershipLabel(fan.tier.value).toUpperCase(),
                color: tierColor,
              ),
              _RegistryChip(
                label: fan.paymentStatus.label.toUpperCase(),
                color: statusColor,
              ),
              _RegistryChip(
                label: fan.chapter.toUpperCase(),
                color: ColorTokens.info,
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Text(
            fan.expiresAt == null
                ? l10n.fanRegistryJoined(
                    AfriDateFormatter.formatDate(fan.joinedAt.toLocal()),
                  )
                : l10n.fanRegistryJoinedRenews(
                    AfriDateFormatter.formatDate(fan.joinedAt.toLocal()),
                    AfriDateFormatter.formatDate(fan.expiresAt!.toLocal()),
                  ),
            style: TypographyTokens.bodyMedium(
              ColorTokens.onSurfaceVariant,
            ).copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }

  Color _tierColor(FanTier tier) {
    return switch (normalizeMembershipSlug(tier.value)) {
      'gold' => ColorTokens.clubAccent,
      'silver' => ColorTokens.success,
      'bronze' => ColorTokens.warning,
      _ => ColorTokens.info,
    };
  }

  Color _statusColor(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.pendingVerification => ColorTokens.warning,
      PaymentStatus.failed => ColorTokens.error,
      PaymentStatus.verified => ColorTokens.success,
    };
  }
}

class _RegistryChip extends StatelessWidget {
  const _RegistryChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: ShapeTokens.chipRadius,
      ),
      child: Text(
        label,
        style: TypographyTokens.labelMedium(
          color,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
