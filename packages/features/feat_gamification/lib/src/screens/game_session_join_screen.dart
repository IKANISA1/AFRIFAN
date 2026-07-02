import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../game_session_providers.dart';

class GameSessionJoinScreen extends ConsumerStatefulWidget {
  const GameSessionJoinScreen({super.key});

  @override
  ConsumerState<GameSessionJoinScreen> createState() =>
      _GameSessionJoinScreenState();
}

class _GameSessionJoinScreenState extends ConsumerState<GameSessionJoinScreen> {
  late final TextEditingController _codeController;
  late final TextEditingController _displayNameController;
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _displayNameController = TextEditingController(text: 'Supporter');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        title: Text(
          'Join Game',
          style: TypographyTokens.headlineSmall().copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          children: [
            AfriSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SESSION CODE',
                    style: TypographyTokens.labelSmall(ColorTokens.clubAccent),
                  ),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Text(
                    'Enter the code shown on the TV display.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriInputField(
                    controller: _codeController,
                    enabled: !_joining,
                    textCapitalization: TextCapitalization.characters,
                    label: 'Code',
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  AfriInputField(
                    controller: _displayNameController,
                    enabled: !_joining,
                    maxLength: 48,
                    label: 'Display name',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _joining ? null : _joinByCode(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing5),
                  AfriButton(
                    label: 'Join session',
                    icon: AfriIcons.live,
                    isLoading: _joining,
                    onTap: _joinByCode,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _joinByCode() async {
    if (_joining) {
      return;
    }

    final joinCode = _codeController.text.trim();
    if (joinCode.isEmpty) {
      AfriToast.info(context, 'Enter the TV session code.');
      return;
    }

    setState(() {
      _joining = true;
    });

    try {
      final result = await ref
          .read(gameSessionRepositoryProvider)
          .joinSessionByCode(
            joinCode: joinCode,
            displayName: _displayNameController.text,
          );
      if (!mounted) {
        return;
      }
      context.go(
        '/fanzone/game/${result.sessionId}?session_player_id=${result.sessionPlayerId}',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      AfriToast.error(context, 'Could not join. Check the code and try again.');
    } finally {
      if (mounted) {
        setState(() {
          _joining = false;
        });
      }
    }
  }
}
