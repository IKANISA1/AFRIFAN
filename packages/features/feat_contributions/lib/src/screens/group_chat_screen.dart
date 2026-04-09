import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

int? _currentClubId(SupabaseClient client) {
  final user = client.auth.currentUser;
  final candidates = <Object?>[
    user?.appMetadata['club_id'],
    user?.userMetadata?['club_id'],
    user?.appMetadata['clubId'],
    user?.userMetadata?['clubId'],
  ];

  for (final candidate in candidates) {
    final parsed = int.tryParse(candidate?.toString().trim() ?? '');
    if (parsed != null) {
      return parsed;
    }
  }

  return null;
}

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
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final clubId = _currentClubId(client);
      if (clubId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }
      final group = await client
          .from('contribution_groups')
          .select('name, member_count')
          .eq('id', widget.groupId)
          .eq('club_id', clubId)
          .maybeSingle();

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
        _groupName = group?['name']?.toString().toUpperCase() ?? 'GROUP CHAT';
        _memberCount = (group?['member_count'] as num?)?.toInt() ?? 0;
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
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _subscribe() {
    _channel = ref
        .read(supabaseClientProvider)
        .channel('group-chat-${widget.groupId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: widget.groupId,
          ),
          callback: (_) => _loadMessages(),
        )
        .subscribe();
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
              style: GoogleFonts.barlowCondensed(
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
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                context.push('/contribute/group/${widget.groupId}/settings'),
            tooltip: 'Open circle settings',
            icon: const Icon(Icons.settings_outlined),
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
              border: Border.all(color: ColorTokens.ghostBorder),
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
        border: Border.all(color: ColorTokens.success.withValues(alpha: 0.24)),
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
