import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../official_fanclub_register.dart';
import '../widgets/fan_club_cards.dart';

final fanClubsLoaderProvider =
    Provider<Future<List<Map<String, dynamic>>> Function()>((ref) {
      final client = ref.watch(supabaseClientProvider);
      return () async {
        final scope = await ClubScopeResolver(client: client).requireResolved();
        final rows = await client
            .from('fan_clubs')
            .select(
              'id,partner_id,club_id,name,region,description,member_count,'
              'event_count,rating,banner_emoji,is_active,created_at,updated_at,is_featured',
            )
            .eq('club_id', scope.requiredClubId)
            .eq('is_active', true)
            .order('member_count', ascending: false);
        return List<Map<String, dynamic>>.from(
          rows,
        ).map(normalizeFanclubRow).toList(growable: false);
      };
    });

class FanClubsListScreen extends ConsumerStatefulWidget {
  const FanClubsListScreen({super.key});

  @override
  ConsumerState<FanClubsListScreen> createState() => _FanClubsListScreenState();
}

class _FanClubsListScreenState extends ConsumerState<FanClubsListScreen> {
  static const _allFilter = '__all__';

  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _clubs = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  String _activeFilter = _allFilter;

  @override
  void initState() {
    super.initState();
    unawaited(_loadClubs());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clubs = await ref.read(fanClubsLoaderProvider)();

      if (!mounted) return;
      final loadedClubs = clubs;
      final availableFilters = _buildFilters(loadedClubs);
      setState(() {
        _clubs = loadedClubs;
        if (!availableFilters.contains(_activeFilter)) {
          _activeFilter = _allFilter;
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.fanClubsLoadError;
      });
    }
  }

  Future<void> _openClub(Map<String, dynamic> club) async {
    final clubId = club['id']?.toString();
    if (clubId == null || clubId.isEmpty) return;
    await context.push('/fan-clubs/${Uri.encodeComponent(clubId)}');
    if (mounted) await _loadClubs();
  }

  List<String> _buildFilters(List<Map<String, dynamic>> clubs) {
    final filters = <String>[_allFilter];
    final seen = <String>{'all'};

    for (final club in clubs) {
      final region = _trimmedRegion(club['region']);
      if (region == null) {
        continue;
      }
      final key = region.toLowerCase();
      if (seen.add(key)) {
        filters.add(region);
      }
    }

    return filters;
  }

  List<Map<String, dynamic>> get _visibleClubs {
    final query = _searchController.text.trim().toLowerCase();
    return _clubs
        .where((club) {
          final region = _trimmedRegion(club['region'])?.toLowerCase() ?? '';
          final name = club['name']?.toString().toLowerCase() ?? '';
          final normalizedFilter = _activeFilter.trim().toLowerCase();
          final matchesFilter =
              normalizedFilter == _allFilter || region == normalizedFilter;
          final matchesQuery =
              query.isEmpty ||
              name.contains(query) ||
              region.contains(query) ||
              (club['description']?.toString().toLowerCase() ?? '').contains(
                query,
              );
          return matchesFilter && matchesQuery;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = ColorTokens.primary;
    final visibleClubs = _visibleClubs;
    final filters = _buildFilters(_clubs);

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      showBackButton: false,
      scrollable: false,
      constrainContent: false,
      bodyWrapper: (child) => GradientBackground(child: child),
      child: SafeArea(
        child: AfriRefreshIndicator(
          onRefresh: _loadClubs,
          color: primary,
          child: CustomScrollView(
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
                    SpacingTokens.spacing0,
                  ),
                  child: Row(
                    children: [
                      AfriIconButton(
                        icon: AfriIcons.back,
                        onTap: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/membership');
                          }
                        },
                        tooltip: context.afriL10n.authBack,
                      ),
                      const SizedBox(width: SpacingTokens.spacing2),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.afriL10n.fanClubsCommunityEyebrow,
                              style: TypographyTokens.labelLarge(
                                ColorTokens.onSurfaceVariant,
                              ).copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              context.afriL10n.fanClubsTitle,
                              style: TypographyTokens.headlineLarge(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                  child: AfriInputField(
                    controller: _searchController,
                    hint: context.afriL10n.fanClubsSearchHint,
                    prefixIcon: AfriIcons.search,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              if (filters.length > 2)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SpacingTokens.spacing6,
                      SpacingTokens.spacing5,
                      SpacingTokens.spacing6,
                      0,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filters
                            .map((filter) {
                              final selected = filter == _activeFilter;
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: SpacingTokens.spacing2,
                                ),
                                child: AfriChoiceChip(
                                  selected: selected,
                                  label: Text(
                                    filter == _allFilter
                                        ? context.afriL10n.searchCategoryAll
                                        : filter,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => _activeFilter = filter),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ),
                ),
              const SliverToBoxAdapter(
                child: SizedBox(height: SpacingTokens.spacing4),
              ),
              if (_error != null && _clubs.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(SpacingTokens.screenPadding),
                    child: AfriListRow(
                      icon: AfriIcons.refresh,
                      title: _error!,
                      subtitle: context.afriL10n.fanClubsSavedRetry,
                      onTap: () => unawaited(_loadClubs()),
                    ),
                  ),
                ),
              FanClubsResultsSliver(
                isLoading: _isLoading && _clubs.isEmpty,
                error: _error,
                visibleClubs: visibleClubs,
                onRetry: () => unawaited(_loadClubs()),
                onOpenClub: (clubId) => unawaited(_openClub({'id': clubId})),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FanClubsResultsSliver extends StatelessWidget {
  const FanClubsResultsSliver({
    super.key,
    required this.isLoading,
    required this.error,
    required this.visibleClubs,
    required this.onRetry,
    required this.onOpenClub,
  });

  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> visibleClubs;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpenClub;

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

    if (error != null && visibleClubs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: AfriErrorView(compact: true, message: error, onRetry: onRetry),
        ),
      );
    }

    if (visibleClubs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: AfriStateView.empty(
            title: context.afriL10n.fanClubsEmptyTitle,
            message: context.afriL10n.fanClubsEmptyMessage,
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final club = visibleClubs[index];
        final clubId = club['id']?.toString() ?? '';

        return Padding(
          padding: EdgeInsets.fromLTRB(
            SpacingTokens.spacing6,
            0,
            SpacingTokens.spacing6,
            index == visibleClubs.length - 1
                ? SpacingTokens.spacing20
                : SpacingTokens.spacing3,
          ),
          child: FanClubCard(club: club, onTap: () => onOpenClub(clubId)),
        );
      }, childCount: visibleClubs.length),
    );
  }
}

String? _trimmedRegion(Object? value) {
  final trimmed = value?.toString().trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
