import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../search/discovery_search.dart';
import '../search/discovery_search_provider.dart';

class DiscoverySearchScreen extends ConsumerStatefulWidget {
  const DiscoverySearchScreen({super.key});

  @override
  ConsumerState<DiscoverySearchScreen> createState() =>
      _DiscoverySearchScreenState();
}

class _DiscoverySearchScreenState extends ConsumerState<DiscoverySearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  DiscoveryCategory _category = DiscoveryCategory.all;
  bool _hasSettledSearch = false;

  @override
  void initState() {
    super.initState();
    unawaited(FirebaseAnalyticsService.logEvent('search_entry'));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    _debounce = Timer(AfriMotion.debounce, () {
      if (mounted) {
        setState(() => _query = value.trim());
      }
    });
  }

  void _submit(String value) {
    _debounce?.cancel();
    final normalized = value.trim();
    setState(() => _query = normalized);
    unawaited(
      ref.read(recentDiscoverySearchesProvider.notifier).add(normalized),
    );
  }

  void _selectRecent(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _submit(query);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    final recent =
        ref.watch(recentDiscoverySearchesProvider).valueOrNull ??
        const <String>[];
    final hasSearch = _query.length >= 2;
    final draftLength = _controller.text.trim().length;
    final request = DiscoverySearchQuery(
      text: _query,
      category: _category,
      localeName: l10n.localeName,
    );

    return AfriScreenScaffold(
      title: l10n.searchTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AfriInputField(
            key: const ValueKey<String>('discovery-search-input'),
            controller: _controller,
            hint: l10n.searchHint,
            prefixIcon: AfriIcons.search,
            suffixIcon: _controller.text.isEmpty
                ? null
                : AfriIconButton(
                    icon: AfriIcons.close,
                    tooltip: l10n.searchClearTooltip,
                    onTap: () {
                      _debounce?.cancel();
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
            autofocus: true,
            textInputAction: TextInputAction.search,
            maxLength: 80,
            onChanged: _onChanged,
            onSubmitted: _submit,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
          AfriSegmentedControl(
            items: DiscoveryCategory.values
                .map((category) => AfriSegment(label: category.label(l10n)))
                .toList(growable: false),
            selectedIndex: DiscoveryCategory.values.indexOf(_category),
            onChanged: (index) {
              setState(() => _category = DiscoveryCategory.values[index]);
            },
          ),
          const SizedBox(height: SpacingTokens.spacing6),
          if (!hasSearch)
            if (draftLength == 1)
              AfriStateView.empty(
                key: const ValueKey<String>('discovery-search-disabled'),
                title: l10n.searchKeepTypingTitle,
                message: l10n.searchKeepTypingMessage,
                icon: AfriIcons.search,
                compact: true,
              )
            else
              _SearchStartState(
                recentSearches: recent,
                onRecentTap: _selectRecent,
                onClearRecent: () => unawaited(
                  ref.read(recentDiscoverySearchesProvider.notifier).clear(),
                ),
              )
          else
            ref
                .watch(discoverySearchProvider(request))
                .when(
                  loading: () => AfriStateView.loading(
                    key: ValueKey<String>(
                      _hasSettledSearch
                          ? 'discovery-search-syncing'
                          : 'discovery-search-loading',
                    ),
                    title: _hasSettledSearch
                        ? l10n.searchUpdatingTitle
                        : l10n.searchSearchingTitle,
                    message: _hasSettledSearch
                        ? l10n.searchUpdatingMessage
                        : l10n.searchSearchingMessage,
                    compact: true,
                  ),
                  error: (error, stackTrace) {
                    _markSearchSettled();
                    final failure = _SearchFailureContent.fromError(
                      error,
                      l10n,
                    );
                    return AfriStateView.error(
                      key: ValueKey<String>(
                        'discovery-search-${failure.stateId}',
                      ),
                      title: failure.title,
                      message: failure.message,
                      actionLabel: failure.canRetry ? l10n.retry : null,
                      onAction: failure.canRetry
                          ? () {
                              unawaited(
                                FirebaseAnalyticsService.logErrorRecovery(
                                  surface: 'search',
                                  outcome: 'retry_requested',
                                ),
                              );
                              ref.invalidate(discoverySearchProvider(request));
                            }
                          : null,
                      compact: true,
                    );
                  },
                  data: (response) {
                    _markSearchSettled();
                    return _SearchResults(
                      query: _query,
                      response: response,
                      onResultTap: (result) {
                        unawaited(
                          ref
                              .read(recentDiscoverySearchesProvider.notifier)
                              .add(_query),
                        );
                        unawaited(
                          FirebaseAnalyticsService.logSearchSuccess(
                            category: result.category.name,
                            resultCount: response.results.length,
                          ),
                        );
                        unawaited(context.push<Object?>(result.destination));
                      },
                      onClearFilters: () {
                        setState(() => _category = DiscoveryCategory.all);
                      },
                    );
                  },
                ),
        ],
      ),
    );
  }

  void _markSearchSettled() {
    if (_hasSettledSearch) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasSettledSearch) {
        setState(() => _hasSettledSearch = true);
      }
    });
  }
}

class _SearchFailureContent {
  const _SearchFailureContent({
    required this.stateId,
    required this.title,
    required this.message,
    required this.canRetry,
  });

  final String stateId;
  final String title;
  final String message;
  final bool canRetry;

  factory _SearchFailureContent.fromError(
    Object error,
    AfriLocalizations l10n,
  ) {
    final failure = DiscoverySearchFailure.fromError(error);
    return switch (failure.kind) {
      DiscoverySearchFailureKind.permissionDenied => _SearchFailureContent(
        stateId: 'permission-denied',
        title: l10n.searchPermissionTitle,
        message: l10n.searchPermissionMessage,
        canRetry: false,
      ),
      DiscoverySearchFailureKind.conflict => _SearchFailureContent(
        stateId: 'conflict',
        title: l10n.searchConflictTitle,
        message: l10n.searchConflictMessage,
        canRetry: true,
      ),
      DiscoverySearchFailureKind.securityTimeout => _SearchFailureContent(
        stateId: 'security-timeout',
        title: l10n.searchTimeoutTitle,
        message: l10n.searchTimeoutMessage,
        canRetry: true,
      ),
      DiscoverySearchFailureKind.unknown => _SearchFailureContent(
        stateId: 'error',
        title: l10n.searchUnavailableTitle,
        message: l10n.searchUnavailableMessage,
        canRetry: true,
      ),
    };
  }
}

class _SearchStartState extends StatelessWidget {
  const _SearchStartState({
    required this.recentSearches,
    required this.onRecentTap,
    required this.onClearRecent,
  });

  final List<String> recentSearches;
  final ValueChanged<String> onRecentTap;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AfriStateView.empty(
          key: const ValueKey<String>('discovery-search-start'),
          title: l10n.searchStartTitle,
          message: l10n.searchStartMessage,
          icon: AfriIcons.search,
          compact: true,
        ),
        if (recentSearches.isNotEmpty) ...[
          const SizedBox(height: SpacingTokens.spacing6),
          AfriSectionHeader(
            title: l10n.searchRecentTitle,
            padding: EdgeInsets.zero,
            trailing: AfriButton(
              label: l10n.searchClear,
              onTap: onClearRecent,
              variant: AfriButtonVariant.ghost,
              fullWidth: false,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Wrap(
            spacing: SpacingTokens.spacing2,
            runSpacing: SpacingTokens.spacing2,
            children: recentSearches
                .map(
                  (query) => AfriChoiceChip(
                    label: Text(query),
                    selected: false,
                    tooltip: l10n.searchForTooltip(query),
                    onSelected: (_) => onRecentTap(query),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ],
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.response,
    required this.onResultTap,
    required this.onClearFilters,
  });

  final String query;
  final DiscoverySearchResponse response;
  final ValueChanged<DiscoveryResult> onResultTap;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.afriL10n;
    if (response.results.isEmpty) {
      return AfriStateView.empty(
        key: const ValueKey<String>('discovery-search-empty'),
        title: l10n.searchNoResultsTitle,
        message: l10n.searchNoResultsMessage(query),
        actionLabel: l10n.searchShowAllCategories,
        onAction: onClearFilters,
        compact: true,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (response.offline) ...[
          AfriStateView.offline(
            key: const ValueKey<String>('discovery-search-offline'),
            title: l10n.searchOfflineTitle,
            message: l10n.searchOfflineMessage,
            compact: true,
          ),
          const SizedBox(height: SpacingTokens.spacing4),
        ],
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.searchResultCount(response.results.length),
            style: TypographyTokens.labelLarge(ColorTokens.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        ...response.results.map(
          (result) => Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
            child: AfriListRow(
              icon: result.icon,
              title: result.title,
              subtitle: result.description,
              onTap: () => onResultTap(result),
            ),
          ),
        ),
      ],
    );
  }
}
