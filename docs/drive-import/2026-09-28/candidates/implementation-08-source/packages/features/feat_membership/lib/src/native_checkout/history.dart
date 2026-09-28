import 'models.dart';

/// Private read cursor, not an authorization token. Never persist or log it.
final class MembershipHistoryCursor {
  const MembershipHistoryCursor(this.recordedAt, this.allocationId);
  final int recordedAt;
  final String allocationId;
  static MembershipHistoryCursor? parse(String? value, MembershipSession actor) {
    if (value == null) return null;
    requireContract(value.length <= 160, 'invalid_request');
    final p = value.split(':');
    requireContract(p.length == 5 && p[0] == 'mh1' && p[1] == '${actor.clubId}' &&
      p[2] == actor.userId && matchesWire(r'^(0|[1-9][0-9]{0,14})$',p[3]) && isUuid(p[4]), 'invalid_request');
    final at = int.tryParse(p[3]);
    requireContract(isTimestamp(at) && at! <= 253370764799999, 'invalid_request');
    return MembershipHistoryCursor(at!, p[4]);
  }
}
final class MembershipHistoryItem {
  const MembershipHistoryItem(this.orderId,this.allocationId,this.recordedAt,this.amount,this.currency);
  final String orderId, allocationId, currency;
  final int recordedAt, amount;
}
final class MembershipHistoryPage {
  MembershipHistoryPage(this.observedAt,List<MembershipHistoryItem> rows,this.nextCursor):items=List.unmodifiable(rows);
  final int observedAt;
  final List<MembershipHistoryItem> items;
  final String? nextCursor;
  bool get historical => true;
  bool get snapshot => false;
  factory MembershipHistoryPage.parse(Object? value,MembershipSession actor,{String? cursor}) {
    final v=exactObject(value,['schemaVersion','clubId','userId','observedAt','scope','historical','snapshot','items','nextCursor']);
    requireContract(v['schemaVersion']==1&&v['clubId']==actor.clubId&&v['userId']==actor.userId&&
      v['scope']=='membership_allocations'&&v['historical']==true&&v['snapshot']==false&&isTimestamp(v['observedAt'])&&
      v['items'] is List&&(v['items']! as List).length<=20);
    final observed=v['observedAt']! as int;
    var before=MembershipHistoryCursor.parse(cursor,actor);
    final orders=<String>{},allocations=<String>{},items=<MembershipHistoryItem>[];
    for(final row in v['items']! as List){
      final r=exactObject(row,['orderId','allocationId','recordedAt','amount','currency']);
      requireContract(isUuid(r['orderId'])&&isUuid(r['allocationId'])&&isTimestamp(r['recordedAt'])&&
        (r['recordedAt']! as int)<=observed&&isAmount(r['amount'])&&matchesWire(r'^[A-Z]{3}$',r['currency']));
      final item=MembershipHistoryItem(r['orderId']! as String,r['allocationId']! as String,r['recordedAt']! as int,r['amount']! as int,r['currency']! as String);
      requireContract(orders.add(item.orderId)&&allocations.add(item.allocationId)&&
        (before==null||item.recordedAt<before.recordedAt||(item.recordedAt==before.recordedAt&&item.allocationId.compareTo(before.allocationId)<0)));
      items.add(item);before=MembershipHistoryCursor(item.recordedAt,item.allocationId);
    }
    requireContract(v['nextCursor']==null||(items.length==20&&v['nextCursor']=='mh1:${actor.clubId}:${actor.userId}:${items.last.recordedAt}:${items.last.allocationId}'));
    return MembershipHistoryPage(observed,items,v['nextCursor'] as String?);
  }
}
/// Additive optional interface: existing fake/native API implementations are not broken.
abstract interface class NativeMembershipHistoryApi {
  Future<MembershipHistoryPage> history(MembershipSession actor,{String? cursor});
  Future<HistoricalMembershipReceipt> historicalReceipt(MembershipSession actor,String orderId);
}
