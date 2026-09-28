import {club,uuid,sha,exact,demand,hash,NOW_SQL,AllocationError} from '../../payment-allocation/src/policy.mjs';
export {club,uuid,sha,exact,demand,hash,NOW_SQL,AllocationError};
export function failure(error){
 if(error instanceof AllocationError)return error;
 const text=String(error?.message??'');
 for(const code of ['permission_denied','conflict','immutable'])if(text.includes(`delivery_${code}`))return new AllocationError(code);
 return new AllocationError('delivery_unavailable');
}
/** Minimal operational projection, NOT a receipt for money movement or current entitlement. */
export function envelope(value){
 exact(value,['schemaVersion','consumerId','eventId','clubId','orderId','userId','kind','allocationRecorded','businessTargetFulfilled','recordedAt']);
 demand(value.schemaVersion===1&&uuid(value.consumerId)&&uuid(value.eventId)&&club(value.clubId)&&uuid(value.orderId)&&uuid(value.userId),'invalid_event');
 demand(['membership','contribution'].includes(value.kind)&&value.allocationRecorded===true&&typeof value.businessTargetFulfilled==='boolean','invalid_event');
 demand(value.businessTargetFulfilled===(value.kind==='membership'),'invalid_event');
 demand(Number.isSafeInteger(value.recordedAt)&&value.recordedAt>=0,'invalid_event');
 return {...value};
}
export function accepted(result,value,digest){
 exact(result,['schemaVersion','consumerId','eventId','receiptId','envelopeSha256','stored','effect']);
 demand(result.schemaVersion===1&&result.consumerId===value.consumerId&&result.eventId===value.eventId&&result.receiptId===value.eventId
  &&result.envelopeSha256===digest&&result.stored===true&&result.effect==='operations_inbox_record','invalid_receipt');
 return result;
}
