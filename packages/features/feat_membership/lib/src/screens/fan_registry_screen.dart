import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    _reloadFans();
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
    } catch (_) {
      if (!mounted || token != _reloadToken) return;
      setState(() {
        _fans = const [];
        _hasMore = false;
        _isLoading = false;
        _isLoadingMore = false;
        _error = 'Fan registry is temporarily unavailable.';
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
    } catch (_) {
      if (!mounted || token != _reloadToken) return;
      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more fans right now.')),
      );
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter < 280) {
      _loadMore();
    }
  }

  void _handleSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), _reloadFans);
    setState(() {});
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _reloadFans();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final fansLabel = _fans.length == 1
        ? '1 fan loaded'
        : '${_fans.length} fans loaded';
    final summaryLabel = _searchQuery == null
        ? 'This registry mirrors the club membership roster.'
        : 'Filtered results for "${_searchQuery!}".';

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
          'FAN REGISTRY',
          style: TypographyTokens.monolithFont(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: ColorTokens.onSurface,
            letterSpacing: 2.0,
          ),
        ),
      ),
      body: RefreshIndicator(
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
                          Icons.badge_rounded,
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
                              style: TypographyTokens.monolithFont(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: ColorTokens.onSurface,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: SpacingTokens.spacing1),
                            Text(
                              summaryLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: ColorTokens.onSurfaceVariant,
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
                  hint: 'Search fans by name',
                  prefixIcon: AfriIcons.search,
                  onChanged: _handleSearchChanged,
                  textInputAction: TextInputAction.search,
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(AfriIcons.close),
                          tooltip: 'Clear search',
                        ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: AfriSkeletonList(),
                ),
              )
            else if (_error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: AfriStateView.offline(
                    title: 'Registry unavailable',
                    message: _error!,
                    actionLabel: 'Retry',
                    onAction: _reloadFans,
                  ),
                ),
              )
            else if (_fans.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SpacingTokens.spacing6,
                  ),
                  child: AfriStateView.empty(
                    title: _searchQuery == null
                        ? 'No registered fans yet'
                        : 'No fan matches that search',
                    message: _searchQuery == null
                        ? 'Once supporters start registering, they will appear in this roster.'
                        : 'Try a different fan name or clear the current search.',
                    actionLabel: _searchQuery == null
                        ? 'Refresh'
                        : 'Clear search',
                    onAction: _searchQuery == null ? _reloadFans : _clearSearch,
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final fan = _fans[index];
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      SpacingTokens.spacing6,
                      0,
                      SpacingTokens.spacing6,
                      index == _fans.length - 1 && !_isLoadingMore
                          ? SpacingTokens.spacing20
                          : SpacingTokens.spacing3,
                    ),
                    child: _FanRegistryCard(fan: fan),
                  );
                }, childCount: _fans.length),
              ),
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing2,
                    SpacingTokens.spacing6,
                    SpacingTokens.spacing12,
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.6,
                      color: ColorTokens.clubAccent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FanRegistryCard extends StatelessWidget {
  const _FanRegistryCard({required this.fan});

  final FanMembership fan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                      style: TypographyTokens.monolithFont(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: ColorTokens.onSurface,
                        letterSpacing: 0.8,
                      ),
                    ),
                    if (membershipNumber.isNotEmpty) ...[
                      const SizedBox(height: SpacingTokens.spacing1),
                      Text(
                        membershipNumber,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: ColorTokens.onSurfaceVariant,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: SpacingTokens.spacing3),
              Text(
                '${fan.points} FET',
                style: TypographyTokens.monolithFont(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColorTokens.clubAccent,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: [
              _RegistryChip(
                label: fan.tier.label.toUpperCase(),
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
            'Joined ${AfriDateFormatter.formatDate(fan.joinedAt.toLocal())}'
            '${fan.expiresAt != null ? '  •  Renews ${AfriDateFormatter.formatDate(fan.expiresAt!.toLocal())}' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: ColorTokens.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Color _tierColor(FanTier tier) {
    return switch (tier) {
      FanTier.fan => ColorTokens.info,
      FanTier.bronze => ColorTokens.warning,
      FanTier.gold => ColorTokens.clubAccent,
      FanTier.platinum => ColorTokens.success,
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
        style: TypographyTokens.monolithFont(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
