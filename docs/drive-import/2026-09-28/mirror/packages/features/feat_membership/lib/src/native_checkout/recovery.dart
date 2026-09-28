import 'dart:convert';
import 'dart:math';
import 'models.dart';
import 'ports.dart';

String newOperationId() {
  final random=Random.secure();
  final bytes=List<int>.generate(16,(_)=>random.nextInt(256));
  bytes[6]=(bytes[6]&15)|64;bytes[8]=(bytes[8]&63)|128;
  final text=bytes.map((n)=>n.toRadixString(16).padLeft(2,'0')).join();
  return '${text.substring(0,8)}-${text.substring(8,12)}-${text.substring(12,16)}-${text.substring(16,20)}-${text.substring(20)}';
}
final class PendingNativeCheckout {
  const PendingNativeCheckout(this.userId,this.clubId,this.requestId,this.tier,this.orderId);
  final String userId,requestId,tier;
  final int clubId;
  final String? orderId;
  bool get pending => orderId==null;
  String encode()=>jsonEncode({'version':1,'userId':userId,'clubId':clubId,'requestId':requestId,'tier':tier,
    'phase':pending?'pending':'prepared','orderId':orderId});
  static PendingNativeCheckout? decode(String? text,MembershipSession actor){
    if(text==null)return null;
    try{
      requireContract(text.length<=1024);
      final v=exactObject(decodeWire(text),['version','userId','clubId','requestId','tier','phase','orderId']);
      requireContract(v['version']==1&&v['userId']==actor.userId&&v['clubId']==actor.clubId&&isUuid(v['requestId'])&&isTier(v['tier'])&&
        ((v['phase']=='pending'&&v['orderId']==null)||(v['phase']=='prepared'&&isUuid(v['orderId']))));
      return PendingNativeCheckout(actor.userId,actor.clubId,v['requestId']! as String,v['tier']! as String,v['orderId'] as String?);
    }catch(_){throw const NativeMembershipException('recovery_store_invalid');}
  }
}
/// Native store implementations are mandatory injected ports. No in-memory or plain
/// preferences implementation is silently substituted. restore() is read-only.
final class NativeCheckoutCoordinator {
  NativeCheckoutCoordinator(this.api,this.store,{this.enabled=false});
  final NativeMembershipApi api;
  final NativeRecoveryStore store;
  final bool enabled;
  String _scope(MembershipSession a)=>'africlub-membership-v1:${a.clubId}:${a.userId}';
  void _gate()=>requireContract(enabled,'membership_client_disabled');
  Future<String> _save(String scope,String? old,PendingNativeCheckout next) async {
    final text=next.encode();
    requireContract(await store.compareAndSet(scope,old,text),'recovery_store_conflict');
    requireContract(await store.load(scope)==text,'recovery_store_unavailable');return text;
  }
  Future<PendingNativeCheckout?> restore() async {
    _gate();final a=await api.session(),scope=_scope(a);
    return store.runExclusive(scope,() async=>PendingNativeCheckout.decode(await store.load(scope),a));
  }
  /// Explicit tier-selection action. An unresolved request cannot be replaced.
  Future<PreparedCheckout> begin(String tier) async {
    _gate();requireContract(isTier(tier),'invalid_request');final a=await api.session(),scope=_scope(a);
    return store.runExclusive(scope,() async {
      final saved=await store.load(scope),prior=PendingNativeCheckout.decode(saved,a);
      requireContract(prior==null||!prior.pending,'unresolved_checkout');
      final next=PendingNativeCheckout(a.userId,a.clubId,newOperationId(),tier,null);
      final persisted=await _save(scope,saved,next);return _send(a,scope,next,persisted);
    });
  }
  /// Explicit same-operation retry only. Never use on a lifecycle or timer event.
  Future<PreparedCheckout> resume() async {
    _gate();final a=await api.session(),scope=_scope(a);
    return store.runExclusive(scope,() async {
      final saved=await store.load(scope),prior=PendingNativeCheckout.decode(saved,a);
      requireContract(prior!=null&&prior.pending,'no_pending_checkout');
      return _send(a,scope,prior!,saved!);
    });
  }
  Future<PreparedCheckout> _send(MembershipSession a,String scope,PendingNativeCheckout p,String saved) async {
    final result=await api.prepare(a,p.requestId,p.tier);
    requireContract(result.requestId==p.requestId&&result.clubId==p.clubId&&result.tier==p.tier&&isUuid(result.orderId),'invalid_membership_contract');
    await _save(scope,saved,PendingNativeCheckout(p.userId,p.clubId,p.requestId,p.tier,result.orderId));return result;
  }
}
