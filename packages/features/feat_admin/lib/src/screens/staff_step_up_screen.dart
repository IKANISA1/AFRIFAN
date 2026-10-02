import 'dart:async';

import 'package:core_auth/core_auth.dart';
import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Factor IDs and setup secrets belong only to this account's mounted page.
/// They are never persisted, logged, placed in routes, or sent to analytics.
class StaffStepUpScreen extends ConsumerStatefulWidget {
  const StaffStepUpScreen({super.key});
  @override
  ConsumerState<StaffStepUpScreen> createState() => _StaffStepUpScreenState();
}

class _StaffStepUpScreenState extends ConsumerState<StaffStepUpScreen> {
  final _code = TextEditingController();
  StaffMfaRepository? _repository;
  List<sb.Factor> _factors = const [];
  StreamSubscription<sb.AuthState>? _sessionChanges;
  String? _ownerId;
  String? _factorId;
  String? _secret;
  bool _busy = true;
  bool _failed = false;
  int _operation = 0;
  @override
  void initState() {
    super.initState();
    final client = ref.read(supabaseClientProvider);
    _ownerId = client.auth.currentUser?.id;
    _sessionChanges = client.auth.onAuthStateChange.listen((_) {
      final currentId = client.auth.currentUser?.id;
      if (!mounted || currentId == _ownerId) return;
      _ownerId = currentId;
      _operation++;
      _repository?.invalidate();
      _code.clear();
      setState(() {
        _secret = null;
        _factorId = null;
        _factors = const [];
        _failed = currentId == null;
        _busy = currentId != null;
      });
      if (currentId != null) unawaited(_load());
    });
    unawaited(Future.microtask(_load));
  }

  @override
  void dispose() {
    _operation++;
    unawaited(_sessionChanges?.cancel());
    _repository?.invalidate();
    _secret = null;
    _factorId = null;
    _code.clear();
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final operation = ++_operation;
    _repository = ref.read(staffMfaRepositoryProvider);
    try {
      final factors = await _repository!.verifiedFactors();
      if (!mounted || operation != _operation) return;
      setState(() {
        _factors = factors;
        _factorId = factors.firstOrNull?.id;
        _busy = false;
        _failed = false;
      });
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _enroll() async {
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final enrollment = await _repository!.enroll();
      if (!mounted || operation != _operation) return;
      setState(() {
        _factorId = enrollment.id;
        _secret = enrollment.totp!.secret;
        _busy = false;
      });
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  Future<void> _verify() async {
    final factorId = _factorId;
    if (_busy || factorId == null || _code.text.length != 6) return;
    final operation = ++_operation;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final code = _code.text;
    _code.clear();
    try {
      await _repository!.verify(factorId, code);
      if (!mounted || operation != _operation) return;
      setState(() {
        _secret = null;
        _factorId = null;
      });
      await ref.read(authStateProvider.notifier).refreshAdminAccess();
      if (!mounted || operation != _operation) return;
      await ref.read(staffStepUpProvider.notifier).refresh();
      if (!mounted || operation != _operation) return;
      setState(() {
        _busy = false;
        _failed = !ref.read(staffStepUpProvider).isFresh;
      });
    } catch (_) {
      if (mounted && operation == _operation) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(staffMfaRepositoryProvider);
    final l10n = context.afriL10n;
    return AfriScreenScaffold(
      appBar: AfriAppBar(title: Text(l10n.staffStepUpTitle)),
      constrainContent: true,
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.staffStepUpTitle,
              style: TypographyTokens.headlineMedium(),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            Text(l10n.staffStepUpMessage, style: TypographyTokens.bodyMedium()),
            const SizedBox(height: SpacingTokens.spacing6),
            if (_busy) const Center(child: AfriLoadingIndicator()),
            if (_failed) ...[
              Text(
                l10n.staffStepUpFailure,
                style: TypographyTokens.bodyMedium(ColorTokens.error),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
            ],
            if (!_busy && _failed && _factorId == null)
              AfriButton(
                label: l10n.staffStepUpRetry,
                labelMaxLines: 3,
                onTap: _load,
              ),
            if (!_busy && !_failed && _factors.isEmpty && _secret == null) ...[
              Text(
                l10n.staffStepUpSetupMessage,
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              AfriButton(
                key: const ValueKey('staff-enroll'),
                label: l10n.staffStepUpSetup,
                labelMaxLines: 3,
                onTap: _enroll,
              ),
            ],
            if (_secret != null) ...[
              Text(
                l10n.staffStepUpSecretLabel,
                style: TypographyTokens.labelLarge(),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SizeTokens.touchTargetMin,
                ),
                child: SelectableText(
                  _secret!,
                  key: const ValueKey('staff-setup-secret'),
                  style: TypographyTokens.bodyLarge(),
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                l10n.staffStepUpSetupMessage,
                style: TypographyTokens.bodySmall(),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
            ],
            if (_factorId != null) ...[
              ExcludeSemantics(
                child: Text(
                  l10n.staffStepUpCode,
                  key: const ValueKey('staff-totp-label'),
                  style: TypographyTokens.labelLarge(),
                ),
              ),
              AfriInputField(
                key: const ValueKey('staff-totp-code'),
                controller: _code,
                label: l10n.staffStepUpCode,
                tonal: true,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                autofillHints: const [AutofillHints.oneTimeCode],
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(
                key: const ValueKey('staff-verify'),
                label: l10n.staffStepUpVerify,
                labelMaxLines: 3,
                enabled: !_busy && _code.text.length == 6,
                onTap: _verify,
              ),
            ],
            const SizedBox(height: SpacingTokens.spacing6),
            Text(l10n.staffStepUpRecovery, style: TypographyTokens.bodySmall()),
            const SizedBox(height: SpacingTokens.spacing4),
            AfriButton(
              label: l10n.adminBackToSettings,
              labelMaxLines: 3,
              variant: AfriButtonVariant.outline,
              onTap: () => context.go('/settings'),
            ),
          ],
        ),
      ),
    );
  }
}
