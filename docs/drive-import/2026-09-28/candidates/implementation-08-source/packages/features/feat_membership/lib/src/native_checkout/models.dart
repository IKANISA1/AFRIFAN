import 'dart:convert';

/// Public contract values only. None is evidence of current paid entitlement.
enum RequestOutcome { notSent, rejected, unknown }
/// Full-string matching rejects trailing newlines as well as unsafe characters.
bool matchesWire(String pattern, Object? value) => value is String && RegExp(pattern).stringMatch(value) == value;
final class NativeMembershipException implements Exception {
  const NativeMembershipException(this.code, [this.outcome = RequestOutcome.notSent]);
  final String code;
  final RequestOutcome outcome;
  @override
  String toString() => 'NativeMembershipException($code, ${outcome.name})';
}
void requireContract(bool ok, [String code = 'invalid_membership_contract']) {
  if (!ok) throw NativeMembershipException(code);
}
bool isUuid(Object? value) => matchesWire(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',value);
bool isTier(Object? value) => matchesWire(r'^[a-z0-9][a-z0-9_-]{0,31}$',value);
bool isTimestamp(Object? value) => value is int && value >= 0 && value <= 253402300799999;
bool isAmount(Object? value) => value is int && value > 0 && value <= 2147483647;
Map<String, Object?> exactObject(Object? value, List<String> keys) {
  requireContract(value is Map<String, dynamic>);
  final map = value as Map<String, dynamic>;
  requireContract(map.length == keys.length && keys.every(map.containsKey));
  return Map<String, Object?>.from(map);
}
Object? decodeWire(String text) {
  try { return jsonDecode(text); } catch (_) { throw const NativeMembershipException('invalid_membership_contract'); }
}
final class MembershipSession {
  const MembershipSession(this.userId, this.clubId, this.sessionId);
  final String userId;
  final int clubId;
  final String sessionId;
  factory MembershipSession.parse(Object? value, int club) {
    final v = exactObject(value, ['schemaVersion','userId','clubId','sessionId']);
    requireContract(v['schemaVersion'] == 1 && v['clubId'] == club && isUuid(v['userId']) && isUuid(v['sessionId']));
    return MembershipSession(v['userId']! as String, club, v['sessionId']! as String);
  }
  bool sameSession(MembershipSession other) => userId == other.userId && clubId == other.clubId && sessionId == other.sessionId;
}
final class PreparedCheckout {
  const PreparedCheckout(this.requestId, this.clubId, this.orderId, this.tier, this.reused);
  final String requestId, orderId, tier;
  final int clubId;
  final bool reused;
  bool get paymentVerified => false;
  bool get membershipActivated => false;
  factory PreparedCheckout.parse(Object? value, int club, String key, String tier) {
    final v = exactObject(value, ['schemaVersion','requestId','clubId','orderId','tier','reused','paymentVerified','membershipActivated']);
    requireContract(v['schemaVersion'] == 1 && v['clubId'] == club && v['requestId'] == key && v['tier'] == tier &&
      isUuid(v['orderId']) && v['reused'] is bool && v['paymentVerified'] == false && v['membershipActivated'] == false);
    return PreparedCheckout(key, club, v['orderId']! as String, tier, v['reused']! as bool);
  }
}
final class PaymentInstruction {
  const PaymentInstruction(this.amount, this.currency, this.country, this.provider, this.recipient, this.ussdCode);
  final int amount;
  final String currency, country, provider, recipient, ussdCode;
  factory PaymentInstruction.parse(Object? value) {
    final v = exactObject(value, ['amount','currency','country','provider','recipient','ussdCode']);
    bool matches(String key, String pattern) => matchesWire(pattern,v[key]);
    requireContract(isAmount(v['amount']) && matches('currency',r'^[A-Z]{3}$') && matches('country',r'^[A-Z]{2}$') &&
      matches('provider',r'^[a-z][a-z0-9_-]{0,63}$') && matches('recipient',r'^[0-9]{3,32}$') &&
      matches('ussdCode',r'^\*[0-9*]+#$') && (v['ussdCode']! as String).length <= 128);
    return PaymentInstruction(v['amount']! as int, v['currency']! as String, v['country']! as String,
      v['provider']! as String, v['recipient']! as String, v['ussdCode']! as String);
  }
  bool sameAs(PaymentInstruction other) => amount == other.amount && currency == other.currency && country == other.country &&
    provider == other.provider && recipient == other.recipient && ussdCode == other.ussdCode;
}
enum CheckoutStatus { pendingCurrent, expired, cancelled, allocated, configurationChanged }
final class CurrentCheckout {
  const CurrentCheckout(this.clubId,this.orderId,this.tier,this.status,this.observedAt,this.expiresAt,this.instruction);
  final int clubId, observedAt, expiresAt;
  final String orderId, tier;
  final CheckoutStatus status;
  final PaymentInstruction? instruction;
  bool get paymentEvidenceAllocated => status == CheckoutStatus.allocated;
  factory CurrentCheckout.parse(Object? value, int club, String order) {
    final v = exactObject(value, ['schemaVersion','clubId','orderId','tier','status','paymentEvidenceAllocated','observedAt','expiresAt','paymentInstruction']);
    const statuses = {'pending_current':CheckoutStatus.pendingCurrent,'expired':CheckoutStatus.expired,'cancelled':CheckoutStatus.cancelled,
      'allocated':CheckoutStatus.allocated,'configuration_changed':CheckoutStatus.configurationChanged};
    requireContract(v['schemaVersion'] == 1 && v['clubId'] == club && v['orderId'] == order && isTier(v['tier']) &&
      statuses.containsKey(v['status']) && isTimestamp(v['observedAt']) && isTimestamp(v['expiresAt']));
    final state = statuses[v['status']]!;
    requireContract(v['paymentEvidenceAllocated'] == (state == CheckoutStatus.allocated));
    PaymentInstruction? instruction;
    if (state == CheckoutStatus.pendingCurrent) {
      requireContract((v['observedAt']! as int) < (v['expiresAt']! as int));
      instruction = PaymentInstruction.parse(v['paymentInstruction']);
    } else { requireContract(v['paymentInstruction'] == null); }
    return CurrentCheckout(club,order,v['tier']! as String,state,v['observedAt']! as int,v['expiresAt']! as int,instruction);
  }
}
final class HistoricalMembershipReceipt {
  const HistoricalMembershipReceipt(this.clubId,this.orderId,this.allocationId,this.amount,this.currency,this.recordedAt,
    this.membershipId,this.tier,this.statusAtAllocation,this.expiresAtAllocation);
  final int clubId, amount, recordedAt, expiresAtAllocation;
  final String orderId, allocationId, currency, membershipId, tier, statusAtAllocation;
  bool get historical => true;
  factory HistoricalMembershipReceipt.parse(Object? value, int club, String order) {
    final v = exactObject(value,['schemaVersion','clubId','orderId','allocationId','amount','currency','recordedAt','allocationPersisted','businessTargetFulfilled','membershipAtAllocation','historical']);
    requireContract(v['schemaVersion'] == 1 && v['clubId'] == club && v['orderId'] == order && isUuid(v['allocationId']) &&
      isAmount(v['amount']) && matchesWire(r'^[A-Z]{3}$',v['currency']) &&
      isTimestamp(v['recordedAt']) && v['allocationPersisted'] == true && v['businessTargetFulfilled'] == true && v['historical'] == true);
    final m = exactObject(v['membershipAtAllocation'], ['id','tier','status','paymentStatus','expiresAt']);
    requireContract(isUuid(m['id']) && isTier(m['tier']) && ['active','suspended','expired'].contains(m['status']) &&
      m['paymentStatus'] == 'verified' && isTimestamp(m['expiresAt']) && (m['expiresAt']! as int) > (v['recordedAt']! as int));
    return HistoricalMembershipReceipt(club,order,v['allocationId']! as String,v['amount']! as int,v['currency']! as String,
      v['recordedAt']! as int,m['id']! as String,m['tier']! as String,m['status']! as String,m['expiresAt']! as int);
  }
}

/// Server-authoritative marker. Its existence does not prove the carrier opened.
final class ServerPaymentHandoff {
  const ServerPaymentHandoff(this.handoffId,this.orderId,this.clubId,this.phase,
    this.createdAt,this.claimedAt,this.orderExpiresAt,this.observedAt,this.paymentEvidenceAllocated);
  final String handoffId,orderId,phase;
  final int clubId,createdAt,orderExpiresAt,observedAt;
  final int? claimedAt;
  final bool paymentEvidenceAllocated;
}
final class ServerHandoffStatus {
  const ServerHandoffStatus(this.handoff,this.mayOpenDialer);
  final ServerPaymentHandoff? handoff;
  final bool mayOpenDialer;
  static ServerHandoffStatus parse(Object? value,int clubId,{bool claim=false}) {
    final v=exactObject(value,['schemaVersion','handoff','mayOpenDialer']);
    requireContract(v['schemaVersion']==1&&v['mayOpenDialer'] is bool);
    final allow=v['mayOpenDialer']! as bool;
    requireContract(claim||!allow);
    if(v['handoff']==null){requireContract(!allow);return const ServerHandoffStatus(null,false);}
    final h=exactObject(v['handoff'],['handoffId','orderId','clubId','phase','createdAt','claimedAt','orderExpiresAt','paymentEvidenceAllocated','observedAt']);
    requireContract(isUuid(h['handoffId'])&&isUuid(h['orderId'])&&h['clubId']==clubId&&
      ['reserved','claimed','allocated','released'].contains(h['phase'])&&h['paymentEvidenceAllocated'] is bool);
    for(final k in ['createdAt','orderExpiresAt','observedAt']) {
      requireContract(h[k] is int&&(h[k]! as int)>0&&(h[k]! as int)<=9007199254740991);
    }
    requireContract(h['claimedAt']==null||(h['claimedAt'] is int&&(h['claimedAt']! as int)>0&&(h['claimedAt']! as int)<=9007199254740991));
    final created=h['createdAt']! as int,observed=h['observedAt']! as int,expires=h['orderExpiresAt']! as int;
    final claimed=h['claimedAt'] as int?,phase=h['phase']! as String,paid=h['paymentEvidenceAllocated']! as bool;
    requireContract(created<=observed&&expires>created&&(claimed==null||(claimed>=created&&claimed<=observed))&&
      paid==(phase=='allocated')&&(!['reserved','released'].contains(phase)||claimed==null)&&(phase!='claimed'||claimed!=null));
    requireContract(!allow||(phase=='claimed'&&claimed!=null&&!paid&&expires>observed+15000));
    return ServerHandoffStatus(ServerPaymentHandoff(h['handoffId']! as String,h['orderId']! as String,clubId,phase,created,claimed,expires,observed,paid),allow);
  }
}
