import 'dart:async';

import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';
import '../prediction_result_copy.dart';
import '../widgets/tier_label.dart';

class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<FetFriendProfile> _friends = const <FetFriendProfile>[];
  List<FetFriendProfile> _matches = const <FetFriendProfile>[];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _controller.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final friends = await ref
          .read(fetRepositoryProvider)
          .loadFriends(limit: 12);
      if (!mounted) {
        return;
      }
      setState(() {
        _friends = friends;
        _isLoading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AfriLogger.warn(
        'FriendsListScreen',
        'Operation failed (non-critical).',
        error,
        stackTrace,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = context.afriL10n.gameSupportersTemporarilyUnavailable;
      });
    }
  }

  void _onQueryChanged() {
    final query = _controller.text.trim();
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() {
        _matches = const <FetFriendProfile>[];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(AfriMotion.debounce, () async {
      setState(() {
        _isSearching = true;
      });
      try {
        final matches = await ref
            .read(fetRepositoryProvider)
            .searchSupporters(query);
        if (!mounted) {
          return;
        }
        setState(() {
          _matches = matches;
          _isSearching = false;
        });
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'FriendsListScreen',
          'Operation failed (non-critical).',
          error,
          stackTrace,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _matches = const <FetFriendProfile>[];
          _isSearching = false;
        });
      }
    });
  }

  Future<void> _refreshVisibleData() async {
    final query = _controller.text.trim();
    if (query.length >= 2) {
      setState(() {
        _isSearching = true;
      });
      try {
        final matches = await ref
            .read(fetRepositoryProvider)
            .searchSupporters(query);
        if (!mounted) {
          return;
        }
        setState(() {
          _matches = matches;
          _isSearching = false;
        });
      } catch (error, stackTrace) {
        AfriLogger.warn(
          'FriendsListScreen',
          'Operation failed (non-critical).',
          error,
          stackTrace,
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _matches = const <FetFriendProfile>[];
          _isSearching = false;
        });
      }
      return;
    }

    await _load();
  }

  Future<void> _handlePrimaryAction(FetFriendProfile supporter) async {
    if (supporter.isFriend) {
      unawaited(context.push('/fanzone'));
      return;
    }

    if (supporter.hasPendingOutgoing) {
      return;
    }

    final repo = ref.read(fetRepositoryProvider);
    final result =
        supporter.hasPendingIncoming && supporter.friendshipId != null
        ? await repo.respondToFriendRequest(
            friendshipId: supporter.friendshipId!,
            action: 'accepted',
          )
        : await repo.requestFriend(targetUserId: supporter.userId);

    if (!mounted) {
      return;
    }

    AfriToast.info(
      context,
      result.message.isNotEmpty
          ? context.localizePredictionResultMessage(result.message)
          : context.afriL10n.gameDone,
    );
    unawaited(_refreshVisibleData());
  }

  @override
  Widget build(BuildContext context) {
    final searchMode = _controller.text.trim().length >= 2;
    final visibleSupporters = searchMode ? _matches : _friends;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text(
          context.afriL10n.gameFriendsTitle,
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: TypographyTokens.trackingNone,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: context.afriL10n.gameBack,
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: context.afriL10n.gameSupportersUnavailable,
                  message: _error!,
                  actionLabel: context.afriL10n.gameRetry,
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _refreshVisibleData,
              color: ColorTokens.primaryContainer,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  AfriInputField(
                    controller: _controller,
                    hint: context.afriL10n.gameSearchSupporterHint,
                    prefixIcon: AfriIcons.search,
                    onChanged: (_) {},
                  ),
                  if (_isSearching) ...[
                    const SizedBox(height: SpacingTokens.spacing3),
                    const AfriLinearProgressIndicator(
                      minHeight: SpacingTokens.spacing1,
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.spacing4),
                  FriendSupportersSection(
                    searchMode: searchMode,
                    supporters: visibleSupporters,
                    onAction: _handlePrimaryAction,
                  ),
                ],
              ),
            ),
    );
  }
}

class FriendSupportersSection extends StatelessWidget {
  const FriendSupportersSection({
    super.key,
    required this.searchMode,
    required this.supporters,
    required this.onAction,
  });

  final bool searchMode;
  final List<FetFriendProfile> supporters;
  final ValueChanged<FetFriendProfile> onAction;

  @override
  Widget build(BuildContext context) {
    if (supporters.isEmpty) {
      return const SizedBox.shrink(key: ValueKey<String>('friends-list-empty'));
    }

    return AfriSectionCard(
      title: searchMode
          ? context.afriL10n.gameResults
          : context.afriL10n.gameYourFriends,
      child: Column(
        children: supporters
            .asMap()
            .entries
            .map((entry) {
              final supporter = entry.value;
              return Column(
                children: [
                  if (entry.key > 0) const AfriDivider(),
                  _SupporterRow(
                    name: supporter.displayName,
                    details: _supporterDetails(context, supporter),
                    isOnline: supporter.isOnline,
                    actionLabel: searchMode
                        ? _actionLabel(context, supporter)
                        : context.afriL10n.gameChallenge,
                    actionEnabled: !supporter.hasPendingOutgoing,
                    onAction: () => onAction(supporter),
                  ),
                ],
              );
            })
            .toList(growable: false),
      ),
    );
  }

  String _actionLabel(BuildContext context, FetFriendProfile supporter) {
    if (supporter.isFriend) {
      return context.afriL10n.gameChallenge;
    }
    if (supporter.hasPendingIncoming) {
      return context.afriL10n.gameAccept;
    }
    if (supporter.hasPendingOutgoing) {
      return context.afriL10n.gamePending;
    }
    return context.afriL10n.gameAdd;
  }

  String _supporterDetails(BuildContext context, FetFriendProfile supporter) {
    final parts = <String>[
      if (supporter.publicUserId != null) '#${supporter.publicUserId}',
      fanTierLabel(context.afriL10n, supporter.tier),
      context.afriL10n.gamePointBalance(supporter.balance),
    ];
    return parts.join(' · ');
  }
}

class _SupporterRow extends StatelessWidget {
  const _SupporterRow({
    required this.name,
    required this.details,
    required this.isOnline,
    required this.actionLabel,
    required this.actionEnabled,
    required this.onAction,
  });

  final String name;
  final String details;
  final bool isOnline;
  final String actionLabel;
  final bool actionEnabled;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpacingTokens.spacing3),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TypographyTokens.titleSmall()),
                const SizedBox(height: SpacingTokens.spacing1 / 2),
                Text(details, style: TypographyTokens.bodySmall()),
              ],
            ),
          ),
          if (isOnline) ...[
            Text(
              context.afriL10n.gameOnline,
              style: TypographyTokens.labelSmall(ColorTokens.success),
            ),
            const SizedBox(width: SpacingTokens.spacing3),
          ],
          AfriButton(
            onTap: onAction,
            label: actionLabel,
            enabled: actionEnabled,
            variant: AfriButtonVariant.ghost,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}
