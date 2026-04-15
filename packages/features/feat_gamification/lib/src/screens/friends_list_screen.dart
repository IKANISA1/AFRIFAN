import 'dart:async';

import 'package:core_theme/core_theme.dart';
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
  List<FetLeaderboardRow> _leaders = const <FetLeaderboardRow>[];
  List<FetWalletSupporter> _matches = const <FetWalletSupporter>[];
  bool _isLoading = true;
  bool _isSearching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
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
      final leaders = await ref
          .read(fetRepositoryProvider)
          .loadLeaderboard(limit: 12);
      if (!mounted) {
        return;
      }
      setState(() {
        _leaders = leaders;
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
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
        _matches = const <FetWalletSupporter>[];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() {
        _isSearching = true;
      });
      try {
        final matches = await ref
            .read(fetRepositoryProvider)
            .findSupporters(query);
        if (!mounted) {
          return;
        }
        setState(() {
          _matches = matches;
          _isSearching = false;
        });
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _matches = const <FetWalletSupporter>[];
          _isSearching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final searchMode = _controller.text.trim().length >= 2;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'FRIENDS & FANS',
          style: TypographyTokens.monolithFont(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      body: _isLoading
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
          : ListView(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              children: [
                AfriInputField(
                  controller: _controller,
                  hint: 'Search supporter alias or name',
                  prefixIcon: AfriIcons.search,
                  onChanged: (_) {},
                ),
                const SizedBox(height: SpacingTokens.spacing4),
                if (_isSearching) const LinearProgressIndicator(minHeight: 4),
                const SizedBox(height: SpacingTokens.spacing2),
                Text(
                  searchMode ? 'Search results' : 'Top supporters',
                  style: TypographyTokens.sectionTitle(),
                ),
                const SizedBox(height: SpacingTokens.spacing3),
                ...(searchMode
                    ? _matches.map<Widget>((supporter) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing3,
                          ),
                          child: GlassCard(
                            animate: false,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        supporter.displayName,
                                        style: TypographyTokens.titleSmall(),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '#${supporter.publicUserId ?? '000000'} · ${supporter.tier.toUpperCase()}',
                                        style: TypographyTokens.bodySmall(),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${supporter.balance} FET',
                                  style: TypographyTokens.monolithFont(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: ColorTokens.clubAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                    : _leaders.map<Widget>((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing3,
                          ),
                          child: GlassCard(
                            animate: false,
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    '#${entry.rank}',
                                    style: TypographyTokens.monolithFont(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    entry.displayName,
                                    style: TypographyTokens.titleSmall(),
                                  ),
                                ),
                                Text(
                                  '${entry.totalFet} FET',
                                  style: TypographyTokens.monolithFont(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: ColorTokens.clubAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      })),
              ],
            ),
    );
  }
}
