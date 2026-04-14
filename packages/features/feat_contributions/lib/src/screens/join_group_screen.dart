import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:feat_club/feat_club.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final TextEditingController _inviteController = TextEditingController();

  bool _isPreviewLoading = false;
  bool _isJoining = false;
  String? _error;
  Map<String, dynamic>? _preview;

  bool get _hasInviteCode => _inviteController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _inviteController.addListener(_onChanged);
    final initialCode = widget.initialCode?.trim();
    if (initialCode != null && initialCode.isNotEmpty) {
      _inviteController.text = initialCode.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _previewInvite();
      });
    }
  }

  @override
  void dispose() {
    _inviteController
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) {
      return;
    }
    setState(() {
      _error = null;
      _preview = null;
    });
  }

  String get _inviteCode => _inviteController.text.trim().toUpperCase();

  Future<void> _previewInvite() async {
    if (_isPreviewLoading || _isJoining || !_hasInviteCode) {
      return;
    }

    setState(() {
      _isPreviewLoading = true;
      _error = null;
    });

    try {
      final preview = await ref
          .read(clubRepositoryProvider)
          .previewInvite(_inviteCode);
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = preview;
        _error = preview == null
            ? 'No circle was found for this invite code.'
            : null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = null;
        _error = 'Could not verify this invite code right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isPreviewLoading = false);
      }
    }
  }

  Future<void> _joinGroup() async {
    if (_isPreviewLoading || _isJoining || !_hasInviteCode) {
      return;
    }

    final profile = ref.read(currentUserProvider);
    if (profile == null) {
      context.go('/onboarding');
      return;
    }

    setState(() {
      _isJoining = true;
      _error = null;
    });

    try {
      final result = await ref
          .read(clubRepositoryProvider)
          .joinGroupViaInvite(_inviteCode);
      final status = result['status']?.toString().toLowerCase();
      final groupId = result['group_id']?.toString();
      final groupName =
          result['group_name']?.toString() ??
          _preview?['group_name']?.toString() ??
          'circle';

      if (!mounted) {
        return;
      }

      if ((status == 'success' || status == 'already_member') &&
          groupId != null &&
          groupId.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'already_member'
                  ? 'You are already in $groupName.'
                  : 'Joined $groupName successfully.',
            ),
            backgroundColor: ColorTokens.success,
          ),
        );
        context.go('/contribute/group/$groupId');
        return;
      }

      setState(() {
        _error =
            result['message']?.toString() ??
            'Could not join this circle with the supplied invite.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Could not join this circle right now.';
      });
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final groupName = preview?['group_name']?.toString() ?? 'Support circle';
    final description = preview?['description']?.toString();
    final memberCount = (preview?['member_count'] as num?)?.toInt() ?? 0;
    final inviteCode = preview?['invite_code']?.toString() ?? _inviteCode;
    final visibility = preview?['visibility']?.toString() ?? 'private';
    final groupType = preview?['type']?.toString() ?? 'community';
    final alreadyMember = preview?['already_member'] == true;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'JOIN A CIRCLE',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: GradientBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(SpacingTokens.spacing6),
            children: [
              Text(
                'Enter an invite code to preview a circle before you join it.',
                style: TypographyTokens.bodyLarge(ColorTokens.onSurfaceVariant),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('INVITE CODE', style: TypographyTokens.labelMedium()),
                    const SizedBox(height: SpacingTokens.spacing3),
                    TextField(
                      controller: _inviteController,
                      textCapitalization: TextCapitalization.characters,
                      enabled: !_isPreviewLoading && !_isJoining,
                      decoration: const InputDecoration(
                        hintText: 'ABCD1234',
                        prefixIcon: Icon(Icons.qr_code_rounded),
                      ),
                    ),
                    const SizedBox(height: SpacingTokens.spacing4),
                    FilledButton(
                      onPressed: _isPreviewLoading || !_hasInviteCode
                          ? null
                          : _previewInvite,
                      child: Text(
                        _isPreviewLoading ? 'CHECKING...' : 'PREVIEW CIRCLE',
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: SpacingTokens.spacing4),
                AfriStateView.offline(
                  title: 'Invite unavailable',
                  message: _error!,
                  actionLabel: 'Try again',
                  onAction: _hasInviteCode ? _previewInvite : null,
                  compact: true,
                ),
              ],
              if (preview != null) ...[
                const SizedBox(height: SpacingTokens.spacing5),
                GlassCard(
                  animate: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: SpacingTokens.spacing2,
                        runSpacing: SpacingTokens.spacing2,
                        children: [
                          _PreviewChip(label: visibility.toUpperCase()),
                          _PreviewChip(label: groupType.toUpperCase()),
                          _PreviewChip(label: '$memberCount MEMBERS'),
                        ],
                      ),
                      const SizedBox(height: SpacingTokens.spacing4),
                      Text(
                        groupName.toUpperCase(),
                        style: TypographyTokens.monolithFont(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: ColorTokens.onSurface,
                        ),
                      ),
                      if (description != null &&
                          description.trim().isNotEmpty) ...[
                        const SizedBox(height: SpacingTokens.spacing2),
                        Text(
                          description.trim(),
                          style: TypographyTokens.bodyMedium(),
                        ),
                      ],
                      const SizedBox(height: SpacingTokens.spacing4),
                      Text(
                        'Invite code: $inviteCode',
                        style: TypographyTokens.labelMedium(
                          ColorTokens.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: SpacingTokens.spacing5),
                      FilledButton(
                        onPressed: _isJoining ? null : _joinGroup,
                        child: Text(
                          _isJoining
                              ? 'JOINING...'
                              : alreadyMember
                              ? 'OPEN CIRCLE'
                              : 'JOIN CIRCLE',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SpacingTokens.spacing3,
        vertical: SpacingTokens.spacing2,
      ),
      decoration: BoxDecoration(
        color: ColorTokens.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: BorderTokens.all(color: ColorTokens.ghostBorder),
      ),
      child: Text(
        label,
        style: TypographyTokens.labelSmall(ColorTokens.onSurfaceVariant),
      ),
    );
  }
}
