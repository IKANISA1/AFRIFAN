import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../fet_providers.dart';
import '../models/fet_models.dart';

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
        _error = 'Supporters are temporarily unavailable.';
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
      result.message.isNotEmpty ? result.message : 'Done.',
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
          'Friends',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
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
                  title: 'Supporters unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _load,
                ),
              ),
            )
          : AfriRefreshIndicator(
              onRefresh: _refreshVisibleData,
              color: ColorTokens.clubAccent,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  AfriInputField(
                    controller: _controller,
                    hint: 'Search supporter alias or ID',
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
      title: searchMode ? 'Results' : 'Your friends',
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
                    details: _supporterDetails(supporter),
                    isOnline: supporter.isOnline,
                    actionLabel: searchMode
                        ? _actionLabel(supporter)
                        : 'Challenge',
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

  String _actionLabel(FetFriendProfile supporter) {
    if (supporter.isFriend) {
      return 'Challenge';
    }
    if (supporter.hasPendingIncoming) {
      return 'Accept';
    }
    if (supporter.hasPendingOutgoing) {
      return 'Pending';
    }
    return 'Add';
  }

  String _supporterDetails(FetFriendProfile supporter) {
    final parts = <String>[
      if (supporter.publicUserId != null) '#${supporter.publicUserId}',
      supporter.tier.toUpperCase(),
      '${supporter.balance} pts',
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
              'Online',
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
