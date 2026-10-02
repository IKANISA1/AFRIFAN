import 'dart:async';
import 'dart:convert';

import 'package:core_network/core_network.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_providers.dart';

/// Presentation expiry from the SDK-held JWT. SQL remains the authority.
DateTime? staffTotpExpiry(Session? session, {DateTime? now}) {
  if (session == null) return null;
  final current = (now ?? DateTime.now()).millisecondsSinceEpoch / 1000;
  try {
    final parts = session.accessToken.split('.');
    if (parts.length != 3) return null;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (claims is! Map ||
        claims['sub'] != session.user.id ||
        claims['role'] != 'authenticated' ||
        claims['aal'] != 'aal2' ||
        claims['is_anonymous'] != false ||
        claims['amr'] is! List ||
        (claims['amr'] as List).isEmpty ||
        (claims['amr'] as List).length > 16) {
      return null;
    }
    final exp = claims['exp'];
    if (exp is! num ||
        !exp.isFinite ||
        exp <= current ||
        exp > 9007199254740991 ||
        exp != exp.truncateToDouble()) {
      return null;
    }
    num? expires;
    for (final entry in claims['amr'] as List) {
      if (entry is! Map || !{'totp', 'mfa/totp'}.contains(entry['method'])) {
        continue;
      }
      final timestamp = entry['timestamp'];
      if (timestamp is! num ||
          !timestamp.isFinite ||
          timestamp.abs() > 9007199254740991 ||
          timestamp != timestamp.truncateToDouble() ||
          timestamp < current - 300 ||
          timestamp > current + 30) {
        continue;
      }
      final candidate = timestamp + 300;
      if (expires == null || candidate > expires) expires = candidate;
    }
    if (expires == null) return null;
    if (exp < expires) expires = exp;
    return DateTime.fromMillisecondsSinceEpoch((expires * 1000).floor());
  } catch (_) {
    return null;
  }
}

class StaffMfaRepository {
  StaffMfaRepository({required SupabaseClient Function() clientProvider})
    : _clientProvider = clientProvider;
  final SupabaseClient Function() _clientProvider;
  final Set<GoTrueSessionMutationScope> _mutations = {};
  int _generation = 0;
  static const _factorName = 'AFRICLUB staff authenticator';
  void invalidate() {
    _generation++;
    for (final mutation in _mutations) {
      mutation.invalidate();
    }
  }

  SupabaseSessionAuthority _owner() {
    final session = _clientProvider().auth.currentSession;
    if (session == null || session.user.isAnonymous) {
      throw AuthSessionMissingException();
    }
    final generation = _generation;
    return SupabaseSessionAuthority.capture(
      clientProvider: _clientProvider,
      isOwnerCurrent: () => generation == _generation,
    );
  }

  Future<List<Factor>> verifiedFactors() async {
    final owner = _owner();
    try {
      owner.requireCurrent();
      final user = (await owner.client.auth.getUser()).user;
      owner.requireCurrent();
      if (user == null || user.id != owner.session?.user.id) {
        throw const SupabaseSessionChangedException();
      }
      return (user.factors ?? const <Factor>[])
          .where(
            (factor) =>
                factor.factorType == FactorType.totp &&
                factor.status == FactorStatus.verified,
          )
          .toList(growable: false);
    } finally {
      await owner.dispose();
    }
  }

  Future<AuthMFAEnrollResponse> enroll() async {
    final owner = _owner();
    try {
      owner.requireCurrent();
      final user = (await owner.client.auth.getUser()).user;
      owner.requireCurrent();
      if (user == null || user.id != owner.session?.user.id) {
        throw const SupabaseSessionChangedException();
      }
      final factors = user.factors ?? const <Factor>[];
      if (factors.any(
        (factor) =>
            factor.factorType == FactorType.totp &&
            factor.status == FactorStatus.verified,
      )) {
        throw StateError('Authenticator setup is already verified.');
      }
      // An abandoned setup's secret is deliberately not persisted. Restart
      // only our unverified factor when the user explicitly requests setup;
      // the provider also rejects deletion if it became verified meanwhile.
      for (final factor in factors.where(
        (factor) =>
            factor.factorType == FactorType.totp &&
            factor.status == FactorStatus.unverified &&
            factor.friendlyName == _factorName,
      )) {
        owner.requireCurrent();
        await owner.client.auth.mfa.unenroll(factor.id);
        owner.requireCurrent();
      }
      final result = await owner.client.auth.mfa.enroll(
        issuer: 'AFRICLUB',
        friendlyName: _factorName,
      );
      owner.requireCurrent();
      if (result.type != FactorType.totp || result.totp == null) {
        throw const FormatException('Authenticator setup was not confirmed.');
      }
      return result;
    } finally {
      await owner.dispose();
    }
  }

  Future<void> verify(String factorId, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException('Enter the six-digit authenticator code.');
    }
    invalidate();
    final generation = _generation;
    final client = _clientProvider();
    final owner = client.auth.createSessionMutationScope();
    _mutations.add(owner);
    final userId = client.auth.currentUser?.id;
    try {
      if (userId == null || client.auth.currentUser?.isAnonymous == true) {
        throw AuthSessionMissingException();
      }
      await owner.run(
        () =>
            client.auth.mfa.challengeAndVerify(factorId: factorId, code: code),
      );
      if (generation != _generation || client.auth.currentUser?.id != userId) {
        throw const SupabaseSessionChangedException();
      }
    } finally {
      _mutations.remove(owner);
    }
  }

  Future<bool> allowed() async {
    final owner = _owner();
    try {
      owner.requireCurrent();
      final allowed = await owner.client.rpc('staff_step_up_allowed');
      owner.requireCurrent();
      return allowed == true &&
          staffTotpExpiry(owner.client.auth.currentSession) != null;
    } finally {
      await owner.dispose();
    }
  }

  DateTime? get expiry =>
      staffTotpExpiry(_clientProvider().auth.currentSession);
}

final staffMfaRepositoryProvider = Provider.autoDispose<StaffMfaRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  final repository = StaffMfaRepository(clientProvider: () => client);
  ref.onDispose(repository.invalidate);
  return repository;
});

enum StaffStepUpStatus { checking, required, verified, unavailable }

class StaffStepUpState {
  const StaffStepUpState(this.status, {this.expiresAt});
  final StaffStepUpStatus status;
  final DateTime? expiresAt;
  bool get isFresh =>
      status == StaffStepUpStatus.verified &&
      expiresAt != null &&
      DateTime.now().isBefore(expiresAt!);
}

final staffStepUpProvider =
    NotifierProvider.autoDispose<StaffStepUpNotifier, StaffStepUpState>(
      StaffStepUpNotifier.new,
    );

class StaffStepUpNotifier extends AutoDisposeNotifier<StaffStepUpState>
    with WidgetsBindingObserver {
  Timer? _expiry;
  int _request = 0;
  bool _active = true;
  @override
  StaffStepUpState build() {
    _active = true;
    _request++;
    _expiry?.cancel();
    ref.watch(authStateProvider);
    ref.watch(staffMfaRepositoryProvider);
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _active = false;
      _request++;
      _expiry?.cancel();
      WidgetsBinding.instance.removeObserver(this);
    });
    final auth = ref.read(authStateProvider);
    if (!auth.isAuthenticated || !auth.adminAccess.hasAnyAdminAccess) {
      return const StaffStepUpState(StaffStepUpStatus.required);
    }
    unawaited(Future.microtask(refresh));
    return const StaffStepUpState(StaffStepUpStatus.checking);
  }

  Future<void> refresh() async {
    if (!_active) return;
    final request = ++_request;
    _expiry?.cancel();
    state = const StaffStepUpState(StaffStepUpStatus.checking);
    try {
      final repository = ref.read(staffMfaRepositoryProvider);
      final allowed = await repository.allowed();
      if (!_active || request != _request) return;
      final expiry = repository.expiry;
      if (!allowed || expiry == null || !DateTime.now().isBefore(expiry)) {
        state = const StaffStepUpState(StaffStepUpStatus.required);
        return;
      }
      state = StaffStepUpState(StaffStepUpStatus.verified, expiresAt: expiry);
      _expiry = Timer(expiry.difference(DateTime.now()), () {
        if (_active) {
          state = const StaffStepUpState(StaffStepUpStatus.required);
        }
      });
    } catch (_) {
      if (_active && request == _request) {
        state = const StaffStepUpState(StaffStepUpStatus.unavailable);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Synchronously remove the grant; authoritative RBAC/assurance refresh
      // will rebuild action scopes. Existing drafts never auto-submit.
      this.state = const StaffStepUpState(StaffStepUpStatus.required);
      unawaited(ref.read(authStateProvider.notifier).refreshAdminAccess());
      unawaited(refresh());
    }
  }
}
