import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Map<String, dynamic>> _messages = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _sending = false;
  String _groupName = 'GROUP CHAT';
  int _memberCount = 0;
  String? _error;
  RealtimeService? _realtimeService;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    unawaited(_subscribe());
  }

  @override
  void dispose() {
    unawaited(_realtimeService?.dispose());
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final scope = await ClubScopeResolver(client: client).requireResolved();
      if (scope.clubId == null) {
        throw StateError('Contribution circles require a numeric club scope.');
      }
      final group = await client
          .from('contribution_groups')
          .select('name, member_count')
          .eq('id', widget.groupId)
          .eq('club_id', scope.clubId!)
          .maybeSingle();
      if (group == null) {
        throw StateError('This circle is no longer available.');
      }

      final messages = await client
          .from('group_messages')
          .select('id, group_id, sender_id, alias, content, created_at')
          .eq('group_id', widget.groupId)
          .order('created_at', ascending: true)
          .limit(200);

      final senderIds = messages
          .map((row) => row['sender_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList(growable: false);

      final aliases = <String, String>{};
      if (senderIds.isNotEmpty) {
        try {
          final profiles = await client
              .from('profiles')
              .select('id, public_user_id')
              .inFilter('id', senderIds);
          for (final profile in profiles) {
            final id = profile['id']?.toString();
            final alias = profile['public_user_id']?.toString();
            if (id != null && alias != null && alias.isNotEmpty) {
              aliases[id] = alias;
            }
          }
        } catch (_) {
          // Alias lookup is best-effort only.
        }
      }

      if (!mounted) return;

      setState(() {
        _groupName = group['name']?.toString().toUpperCase() ?? 'GROUP CHAT';
        _memberCount = (group['member_count'] as num?)?.toInt() ?? 0;
        _messages = messages
            .map((row) {
              final map = Map<String, dynamic>.from(row);
              final senderId = map['sender_id']?.toString() ?? '';
              map['resolved_alias'] =
                  map['alias']?.toString() ?? aliases[senderId] ?? '000000';
              return map;
            })
            .toList(growable: false);
        _isLoading = false;
        _error = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Circle chat is temporarily unavailable.';
      });
    }
  }

  Future<void> _subscribe() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final scope = await ClubScopeResolver(client: client).requireResolved();
      await _realtimeService?.dispose();

      final realtimeService = RealtimeService(
        clubId: _realtimeScopeId(scope),
        client: client,
      );
      realtimeService.onTableChanges(
        table: 'group_messages',
        filterColumn: 'group_id',
        filterValue: widget.groupId,
        callback: (_) => _loadMessages(),
      );

      if (!mounted) {
        await realtimeService.dispose();
        return;
      }
      _realtimeService = realtimeService;
    } catch (_) {
      // Subscription is best-effort; initial load still drives the screen.
    }
  }

  String _realtimeScopeId(ClubScope scope) {
    return scope.clubId?.toString() ?? scope.partnerId;
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (content.isEmpty || userId == null) {
      return;
    }

    setState(() => _sending = true);

    try {
      await ref.read(supabaseClientProvider).from('group_messages').insert({
        'group_id': widget.groupId,
        'content': content,
      });
      _messageController.clear();
      await _loadMessages();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not send your message right now.'),
          backgroundColor: ColorTokens.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _addQuickEmoji(String emoji) {
    final text = _messageController.text;
    final needsSpace = text.isNotEmpty && !text.endsWith(' ');
    _messageController.text = '$text${needsSpace ? ' ' : ''}$emoji'.trimLeft();
    _messageController.selection = TextSelection.collapsed(
      offset: _messageController.text.length,
    );
  }

  bool _isTransactionMessage(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('contributed frw') ||
        normalized.contains('contributed rwf') ||
        normalized.contains('contribution received') ||
        normalized.contains('payment confirmed');
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _groupName,
              style: TypographyTokens.monolithFont(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.6,
              ),
            ),
            Text(
              _memberCount == 1 ? '1 MEMBER' : '$_memberCount MEMBERS',
              style: TypographyTokens.bodySmall().copyWith(
                color: ColorTokens.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(AfriIcons.back),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                context.push('/contribute/group/${widget.groupId}/settings'),
            tooltip: 'Open circle settings',
            icon: const Icon(AfriIcons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
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
                        title: 'Chat unavailable',
                        message: _error!,
                        actionLabel: 'Retry',
                        onAction: _loadMessages,
                      ),
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(SpacingTokens.spacing6),
                      child: Text(
                        'No messages yet.',
                        style: TypographyTokens.bodyMedium(),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(SpacingTokens.spacing6),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final content = message['content']?.toString() ?? '';
                      if (_isTransactionMessage(content)) {
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: SpacingTokens.spacing3,
                          ),
                          child: _TransactionMessageBanner(message: content),
                        );
                      }

                      final outgoing =
                          message['sender_id']?.toString() == currentUserId;
                      return Padding(
                        padding: const EdgeInsets.only(
                          bottom: SpacingTokens.spacing3,
                        ),
                        child: _ChatBubble(
                          alias:
                              '#${message['resolved_alias']?.toString() ?? '000000'}',
                          message: content,
                          outgoing: outgoing,
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing4),
              child: Row(
                children: [
                  _ComposerIconButton(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    semanticLabel: 'Add celebration emoji',
                    onPressed: () => _addQuickEmoji('👏'),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: GlassCard(
                      animate: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: SpacingTokens.spacing4,
                        vertical: SpacingTokens.spacing1,
                      ),
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sending ? null : _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Send a message',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Tooltip(
                    message: 'Send message',
                    child: Semantics(
                      button: true,
                      label: 'Send message',
                      child: GestureDetector(
                        onTap: _sending ? null : _sendMessage,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _sending
                                ? ColorTokens.surfaceContainerHigh
                                : Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: _sending
                              ? Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ColorTokens.onSurface,
                                  ),
                                )
                              : Icon(
                                  Icons.send_rounded,
                                  color: ColorTokens.onSurface,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: semanticLabel,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ColorTokens.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
              border: BorderTokens.ghost(),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: ColorTokens.clubAccent),
          ),
        ),
      ),
    );
  }
}

class _TransactionMessageBanner extends StatelessWidget {
  const _TransactionMessageBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing4,
        vertical: SpacingTokens.spacing3,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: BorderTokens.all(color: ColorTokens.success, opacity: 0.24),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TypographyTokens.bodyMedium().copyWith(
          color: ColorTokens.success,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.alias,
    required this.message,
    required this.outgoing,
  });

  final String alias;
  final String message;
  final bool outgoing;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        decoration: BoxDecoration(
          color: outgoing
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
              : ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: outgoing
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(alias, style: TypographyTokens.numericAlias(fontSize: 15)),
            const SizedBox(height: SpacingTokens.spacing2),
            Text(message, style: TypographyTokens.bodyMedium()),
          ],
        ),
      ),
    );
  }
}
