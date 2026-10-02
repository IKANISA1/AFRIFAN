import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:core_network/core_network.dart';
import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

final _operationPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
const _argumentKeys = <String>[
  'audience',
  'body',
  'delivery_mode',
  'group_id',
  'group_name',
  'image_url',
  'scheduled_at',
  'tier',
  'title',
];

/// Fixed, bounded, flat JSON shared with Edge and SQL. This is a continuity
/// binding, never evidence of current role, session or delivery authority.
Map<String, dynamic> normalizeNotificationArguments(Map<String, dynamic> raw) {
  if (raw.keys.any((key) => !_argumentKeys.contains(key))) {
    throw const FormatException('Unexpected notification fields.');
  }
  String? text(String key, int max, {bool required = false}) {
    final value = raw[key];
    if (value == null || value == '') {
      if (!required) return null;
      throw FormatException('Invalid notification $key.');
    }
    if (value is! String || value.trim().isEmpty || value.trim().length > max) {
      throw FormatException('Invalid notification $key.');
    }
    return value.trim();
  }

  final audience = text('audience', 32, required: true)!.toLowerCase();
  final mode = text('delivery_mode', 32, required: true)!.toLowerCase();
  if (!{'all_fans', 'by_tier', 'by_group'}.contains(audience) ||
      !{'send_now', 'schedule'}.contains(mode)) {
    throw const FormatException('Invalid notification audience or mode.');
  }
  final tier = audience == 'by_tier'
      ? text('tier', 80, required: true)!.toLowerCase()
      : null;
  if (tier != null && !{'fan', 'bronze', 'gold', 'platinum'}.contains(tier)) {
    throw const FormatException('Invalid notification tier.');
  }
  final groupId = audience == 'by_group'
      ? text('group_id', 128, required: true)!.toLowerCase()
      : null;
  if (groupId != null && !_uuidPattern.hasMatch(groupId)) {
    throw const FormatException('Invalid notification group.');
  }
  final groupName = audience == 'by_group' ? text('group_name', 160) : null;
  var image = text('image_url', 2048);
  if (image != null) {
    final uri = Uri.tryParse(image);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        !{'http', 'https'}.contains(uri.scheme)) {
      throw const FormatException('Invalid notification image.');
    }
    final normalized = uri.normalizePath();
    image = normalized
        .replace(path: normalized.path.isEmpty ? '/' : normalized.path)
        .toString();
  }
  String? scheduled;
  if (mode == 'schedule') {
    final date = DateTime.tryParse(text('scheduled_at', 64, required: true)!);
    if (date == null) {
      throw const FormatException('Invalid notification schedule.');
    }
    // JavaScript Date/SQL command JSON have millisecond precision.
    scheduled = DateTime.fromMillisecondsSinceEpoch(
      date.millisecondsSinceEpoch,
      isUtc: true,
    ).toIso8601String();
  }
  final result = <String, dynamic>{
    'audience': audience,
    'body': text('body', 500, required: true),
    'delivery_mode': mode,
    'group_id': groupId,
    'group_name': groupName,
    'image_url': image,
    'scheduled_at': scheduled,
    'tier': tier,
    'title': text('title', 120, required: true),
  };
  if (utf8.encode(jsonEncode(result)).length > 4096) {
    throw const FormatException('Notification command is too large.');
  }
  return Map.unmodifiable(result);
}

String notificationArgumentsHash(Map<String, dynamic> arguments) => sha256
    .convert(
      utf8.encode(
        jsonEncode({for (final key in _argumentKeys) key: arguments[key]}),
      ),
    )
    .toString();

String newNotificationOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class AdminNotificationAttempt {
  AdminNotificationAttempt({
    required this.userId,
    required this.clubId,
    required this.operationId,
    required Map<String, dynamic> arguments,
  }) : arguments = normalizeNotificationArguments(arguments) {
    if (!_uuidPattern.hasMatch(userId) ||
        !_operationPattern.hasMatch(operationId) ||
        clubId < 1 ||
        clubId > 2147483647) {
      throw const FormatException('Invalid notification operation owner.');
    }
  }
  final String userId, operationId;
  final int clubId;
  final Map<String, dynamic> arguments;
  String get scope => 'africlub-notification-v1:$clubId:$userId';
  String get argumentsSha256 => notificationArgumentsHash(arguments);
  String encode() => jsonEncode({
    'version': 1,
    'user_id': userId,
    'club_id': clubId,
    'operation_id': operationId,
    'arguments': arguments,
  });
  static AdminNotificationAttempt? decode(
    String? value,
    String userId,
    int clubId,
  ) {
    if (value == null) return null;
    try {
      if (value.length > 8192) throw const FormatException();
      final map = jsonDecode(value) as Map<String, dynamic>;
      if (map['version'] != 1 ||
          map['user_id'] != userId ||
          map['club_id'] != clubId) {
        throw const FormatException();
      }
      return AdminNotificationAttempt(
        userId: userId,
        clubId: clubId,
        operationId: map['operation_id'] as String,
        arguments: Map<String, dynamic>.from(map['arguments'] as Map),
      );
    } catch (_) {
      throw StateError('NOTIFICATION_JOURNAL_INVALID');
    }
  }
}

class AdminNotificationCommandReceipt {
  AdminNotificationCommandReceipt._(
    this.state,
    this.delivery,
    this.notificationId,
  );
  final String state;
  final Map<String, dynamic>? delivery;
  final String? notificationId;
  bool get confirmed =>
      state == 'scheduled' ||
      (state == 'completed' && delivery?['unknown_count'] == 0);
  bool get canResume => state == 'not_admitted';
  factory AdminNotificationCommandReceipt.fromRaw(
    Object? raw,
    AdminNotificationAttempt attempt,
  ) {
    const invalid = FormatException(
      'Notification receipt does not match the original request.',
    );
    if (raw is! Map || raw['command'] is! Map) throw invalid;
    final c = raw['command'] as Map;
    final state = c['state'];
    if (c['version'] != 1 ||
        c['operation_id'] != attempt.operationId ||
        c['actor_id'] != attempt.userId ||
        c['club_id'] != attempt.clubId ||
        !{
          'not_admitted',
          'admitted',
          'scheduled',
          'processing',
          'completed',
          'unknown',
          'blocked',
        }.contains(state)) {
      throw invalid;
    }
    if (state == 'not_admitted') {
      if (c['notification_id'] != null ||
          c['arguments_sha256'] != null ||
          c['delivery_mode'] != null ||
          raw['notification'] != null ||
          raw['delivery'] != null) {
        throw invalid;
      }
      return AdminNotificationCommandReceipt._(state as String, null, null);
    }
    final id = c['notification_id'];
    if (id is! String ||
        !_uuidPattern.hasMatch(id) ||
        c['arguments_sha256'] != attempt.argumentsSha256 ||
        c['delivery_mode'] != attempt.arguments['delivery_mode'] ||
        raw['notification'] is! Map ||
        raw['delivery'] is! Map) {
      throw invalid;
    }
    final n = raw['notification'] as Map;
    final d = Map<String, dynamic>.from(raw['delivery'] as Map);
    if (n['id'] != id ||
        n['club_id'] != attempt.clubId ||
        (n['created_by'] != attempt.userId && n['created_by'] != null) ||
        !{
          'scheduled',
          'processing',
          'sent',
          'partial',
          'failed',
          'unknown',
        }.contains(d['status'])) {
      throw invalid;
    }
    for (final key in [
      'requested_recipient_count',
      'successful_user_count',
      'failed_user_count',
      'sent_count',
      'failed_count',
      'cleaned_tokens',
      'unknown_count',
      'pending_count',
    ]) {
      final count = d[key];
      if (count is! int || count < 0 || count > 500) throw invalid;
    }
    if (d['scheduled_at'] != null &&
        (d['scheduled_at'] is! String ||
            DateTime.tryParse(d['scheduled_at'] as String) == null)) {
      throw invalid;
    }
    if ((state == 'unknown' && d['unknown_count'] == 0) ||
        (state == 'completed' &&
            (d['unknown_count'] != 0 || d['pending_count'] != 0)) ||
        (state == 'scheduled' && d['status'] != 'scheduled')) {
      throw invalid;
    }
    return AdminNotificationCommandReceipt._(
      state as String,
      Map.unmodifiable(d),
      id,
    );
  }
}

abstract interface class AdminNotificationJournal {
  Future<T> runExclusive<T>(String scope, Future<T> Function() work);
  Future<String?> read(String scope);
  Future<void> save(String scope, String? expected, String value);
  Future<void> remove(String scope, String expected);
}

/// Dedicated non-evicting encrypted journal, independent of cache migrations.
/// A failed write or missing cipher prevents the network mutation.
class HiveAdminNotificationJournal implements AdminNotificationJournal {
  static Future<Box<String>>? _opening;
  static final Map<String, Future<void>> _locks = {};
  Future<Box<String>> _box() async {
    if (HiveEncryptionService.cipher == null) {
      throw StateError('NOTIFICATION_JOURNAL_UNAVAILABLE');
    }
    final pending = _opening;
    if (pending != null) {
      final opened = await pending;
      if (opened.isOpen) return opened;
      if (identical(_opening, pending)) _opening = null;
    }
    return _opening ??=
        Hive.openBox<String>(
          'africlub_admin_notification_v1',
          encryptionCipher: HiveEncryptionService.cipher,
        ).catchError((Object error) {
          _opening = null;
          throw error;
        });
  }

  @override
  Future<T> runExclusive<T>(String scope, Future<T> Function() work) async {
    final previous = _locks[scope] ?? Future<void>.value();
    final release = Completer<void>();
    final next = previous.then<void>((_) => release.future);
    unawaited(_locks[scope] = next);
    await previous;
    try {
      return await work();
    } finally {
      release.complete();
      if (identical(_locks[scope], next)) unawaited(_locks.remove(scope));
    }
  }

  @override
  Future<String?> read(String scope) async => (await _box()).get(scope);
  @override
  Future<void> save(String scope, String? expected, String value) async {
    final box = await _box();
    if (box.get(scope) != expected || value.length > 8192) {
      throw StateError('NOTIFICATION_JOURNAL_CONFLICT');
    }
    await box.put(scope, value);
    await box.flush();
    if (box.get(scope) != value) {
      throw StateError('NOTIFICATION_JOURNAL_UNAVAILABLE');
    }
  }

  @override
  Future<void> remove(String scope, String expected) async {
    final box = await _box();
    if (box.get(scope) != expected) {
      throw StateError('NOTIFICATION_JOURNAL_CONFLICT');
    }
    await box.delete(scope);
    await box.flush();
    if (box.containsKey(scope)) {
      throw StateError('NOTIFICATION_JOURNAL_UNAVAILABLE');
    }
  }
}

class AdminNotificationOwner {
  AdminNotificationOwner({
    required this.userId,
    required this.clubId,
    required this.isCurrent,
    required this.dispose,
  });
  final String userId;
  final int clubId;
  final bool Function() isCurrent;
  final Future<void> Function() dispose;
  void requireCurrent() {
    if (!isCurrent()) throw const SupabaseSessionChangedException();
  }
}

typedef NotificationCommandTransport =
    Future<Map<String, dynamic>> Function(
      AdminNotificationAttempt attempt,
      bool submit,
    );

class AdminNotificationCommandFlow {
  AdminNotificationCommandFlow({
    required this.owner,
    required this.journal,
    required this.transport,
    this.timeout = const Duration(seconds: 12),
    this.operationFactory = newNotificationOperationId,
  });
  final AdminNotificationOwner owner;
  final AdminNotificationJournal journal;
  final NotificationCommandTransport transport;
  final Duration timeout;
  final String Function() operationFactory;
  AdminNotificationAttempt? attempt;
  AdminNotificationCommandReceipt? receipt;
  String get scope =>
      'africlub-notification-v1:${owner.clubId}:${owner.userId}';
  Future<void> restore() => journal.runExclusive(scope, () async {
    owner.requireCurrent();
    final value = await journal.read(scope);
    owner.requireCurrent();
    attempt = AdminNotificationAttempt.decode(
      value,
      owner.userId,
      owner.clubId,
    );
  });
  Future<AdminNotificationCommandReceipt> submit(Map<String, dynamic> raw) =>
      journal.runExclusive(scope, () async {
        owner.requireCurrent();
        final saved = await journal.read(scope);
        owner.requireCurrent();
        if (saved != null) {
          throw StateError('NOTIFICATION_ORIGINAL_REQUEST_PENDING');
        }
        final original = AdminNotificationAttempt(
          userId: owner.userId,
          clubId: owner.clubId,
          operationId: operationFactory(),
          arguments: raw,
        );
        await journal.save(scope, null, original.encode());
        owner.requireCurrent();
        attempt = original;
        return _request(original, true);
      });
  Future<AdminNotificationCommandReceipt?> recover() =>
      journal.runExclusive(scope, () async {
        owner.requireCurrent();
        final saved = await journal.read(scope);
        owner.requireCurrent();
        attempt = AdminNotificationAttempt.decode(
          saved,
          owner.userId,
          owner.clubId,
        );
        if (attempt == null) return null;
        return _request(attempt!, false);
      });

  /// Explicitly reviewed retry of the stored payload. Checking status alone
  /// never sends. Unknown attempts cannot be resent under a fresh session.
  Future<AdminNotificationCommandReceipt?> resumeOriginal() =>
      journal.runExclusive(scope, () async {
        owner.requireCurrent();
        final saved = await journal.read(scope);
        owner.requireCurrent();
        attempt = AdminNotificationAttempt.decode(
          saved,
          owner.userId,
          owner.clubId,
        );
        if (attempt == null) return null;
        final original = attempt!;
        final status = await _request(original, false);
        if (!status.canResume || attempt == null) return status;
        return _request(original, true);
      });
  Future<AdminNotificationCommandReceipt> _request(
    AdminNotificationAttempt original,
    bool submit,
  ) async {
    owner.requireCurrent();
    final raw = await transport(original, submit).timeout(timeout);
    owner.requireCurrent();
    final result = AdminNotificationCommandReceipt.fromRaw(raw, original);
    if (result.confirmed) {
      await journal.remove(scope, original.encode());
      owner.requireCurrent();
      attempt = null;
    }
    receipt = result;
    return result;
  }
}
