import 'dart:convert';
import 'models.dart';
import 'ports.dart';
import 'recovery.dart';

final class PaymentReview {
  const PaymentReview(this.reviewId,this.actor,this.checkout);
  final String reviewId;
  final MembershipSession actor;
  final CurrentCheckout checkout;
  PaymentInstruction get instruction=>checkout.instruction!;
}
final class HandoffAttempt {
  const HandoffAttempt(this.userId,this.clubId,this.orderId,this.attemptId,this.phase);
  final String userId,orderId,attemptId,phase;
  final int clubId;
  String encode()=>jsonEncode({'version':1,'userId':userId,'clubId':clubId,'orderId':orderId,'attemptId':attemptId,'phase':phase});
  static HandoffAttempt? decode(String? saved,MembershipSession actor){
    if(saved==null)return null;
    try{
      requireContract(saved.length<=1024);
      final v=exactObject(decodeWire(saved),['version','userId','clubId','orderId','attemptId','phase']);
      requireContract(v['version']==1&&v['userId']==actor.userId&&v['clubId']==actor.clubId&&isUuid(v['orderId'])&&isUuid(v['attemptId'])&&
        ['reserved','opened','not_opened','unknown'].contains(v['phase']));
      return HandoffAttempt(actor.userId,actor.clubId,v['orderId']! as String,v['attemptId']! as String,v['phase']! as String);
    }catch(_){throw const NativeMembershipException('handoff_storage_invalid');}
  }
}
final class HandoffResult {
  const HandoffResult(this.attemptId,this.platformOpened);
  final String attemptId;
  final bool? platformOpened;
  bool get paymentVerified=>false;
}
final class HandoffRecovery {
  const HandoffRecovery(this.attempt,this.checkout);
  final HandoffAttempt attempt;
  final CurrentCheckout checkout;
}
/// No payment or dialer invocation on constructor, restore, timer, or app resume.
/// The UI must display review fields and call confirm only from an explicit action.
final class NativePaymentHandoff {
  NativePaymentHandoff(this.api,this.store,this.dialer,{this.enabled=false,int Function()? monotonicNow,
    this.timeout=const Duration(seconds:10)}) {
    _now=monotonicNow??()=>_clock.elapsedMilliseconds;
    requireContract(timeout.inMilliseconds>0&&timeout.inMilliseconds<=15000,'handoff_not_configured');
  }
  final NativeMembershipApi api;
  final NativeRecoveryStore store;
  final MembershipDialer dialer;
  final bool enabled;
  final Duration timeout;
  final Stopwatch _clock=Stopwatch()..start();
  late final int Function() _now;
  PaymentReview? _review;
  int _reviewAt=0,_generation=0;
  void _gate()=>requireContract(enabled,'handoff_disabled');
  String _scope(MembershipSession a)=>'africlub-payment-handoff-v1:${a.clubId}:${a.userId}';
  void _fresh(int at){final elapsed=_now()-at;requireContract(elapsed>=0&&elapsed<=30000,'payment_review_expired');}
  void _sameGeneration(int value)=>requireContract(_generation==value,'payment_review_invalidated');
  void _payable(CurrentCheckout s,MembershipSession a,String order){
    requireContract(s.clubId==a.clubId&&s.orderId==order&&isUuid(order),'invalid_status');
    requireContract(s.status==CheckoutStatus.pendingCurrent&&!s.paymentEvidenceAllocated&&s.instruction!=null,'checkout_not_payable');
    requireContract(s.expiresAt-s.observedAt>=15000,'checkout_expiring');
  }
  void _timely(CurrentCheckout s,int at){_fresh(at);requireContract(s.expiresAt-s.observedAt>=15000+_now()-at,'checkout_expiring');}
  Future<void> _priorResolved(MembershipSession a,HandoffAttempt? previous) async {
    if(previous==null||previous.phase=='not_opened')return;
    final current=await api.read(a,previous.orderId);
    requireContract(current.clubId==a.clubId&&current.orderId==previous.orderId&&current.paymentEvidenceAllocated,'unresolved_payment_handoff');
  }
  Future<String> _save(String scope,String? old,HandoffAttempt next) async {
    final encoded=next.encode();requireContract(await store.compareAndSet(scope,old,encoded),'handoff_storage_conflict');
    requireContract(await store.load(scope)==encoded,'handoff_storage_unavailable');return encoded;
  }
  Future<PaymentReview> review(String orderId) async {
    _gate();_review=null;final generation=++_generation;requireContract(isUuid(orderId),'invalid_order');
    final a=await api.session(),scope=_scope(a);
    return store.runExclusive(scope,() async {
      await _priorResolved(a,HandoffAttempt.decode(await store.load(scope),a));
      final at=_now(),s=await api.read(a,orderId);_payable(s,a,orderId);
      requireContract(a.sameSession(await api.session()),'session_changed');_sameGeneration(generation);_timely(s,at);
      final value=PaymentReview(newOperationId(),a,s);_review=value;_reviewAt=at;return value;
    });
  }
  Future<HandoffResult> confirm(String reviewId,{required bool acknowledgement}) async {
    _gate();final q=_review,at=_reviewAt,generation=_generation;
    requireContract(acknowledgement&&q!=null&&q.reviewId==reviewId,'explicit_confirmation_required');
    _review=null;_fresh(at);final reviewed=q!,a=reviewed.actor,scope=_scope(a);
    return store.runExclusive(scope,() async {
      requireContract(a.sameSession(await api.session()),'session_changed');
      final old=await store.load(scope);await _priorResolved(a,HandoffAttempt.decode(old,a));
      final startedAt=_now(),s=await api.read(a,reviewed.checkout.orderId);_payable(s,a,reviewed.checkout.orderId);
      requireContract(s.tier==reviewed.checkout.tier&&s.expiresAt==reviewed.checkout.expiresAt&&s.instruction!.sameAs(reviewed.instruction),'payment_instruction_changed');
      requireContract(a.sameSession(await api.session()),'session_changed');_sameGeneration(generation);_fresh(at);_timely(s,startedAt);
      final reservation=HandoffAttempt(a.userId,a.clubId,s.orderId,newOperationId(),'reserved');
      final saved=await _save(scope,old,reservation);_sameGeneration(generation);_fresh(at);_timely(s,startedAt);
      bool? opened;
      try {opened=await dialer.open(reviewed.instruction.ussdCode).timeout(timeout);}catch(_){opened=null;}
      final phase=opened==true?'opened':opened==false?'not_opened':'unknown';
      try {await _save(scope,saved,HandoffAttempt(a.userId,a.clubId,s.orderId,reservation.attemptId,phase));}
      catch(_){throw const NativeMembershipException('handoff_outcome_unknown',RequestOutcome.unknown);}
      return HandoffResult(reservation.attemptId,opened);
    });
  }
  /// Reads stored handoff and server status only. Never assumes an expired order was unpaid.
  Future<HandoffRecovery?> recover() async {
    _gate();invalidateReview();final a=await api.session(),scope=_scope(a);
    return store.runExclusive(scope,() async {
      final previous=HandoffAttempt.decode(await store.load(scope),a);if(previous==null)return null;
      final s=await api.read(a,previous.orderId);requireContract(a.sameSession(await api.session()),'session_changed');
      return HandoffRecovery(previous,s);
    });
  }
  /// Call on app background, route exit, logout and account changes.
  void invalidateReview(){++_generation;_review=null;}
}
