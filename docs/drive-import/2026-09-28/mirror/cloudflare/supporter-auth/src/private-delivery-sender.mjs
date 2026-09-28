/** Optional private transport for the existing queued authentication service.
 * It does not change code lifetimes, identity, erasure or the legacy default. */
export function requirePrivateDelivery(env) {
  if(!env.OTP_DELIVERY||typeof env.OTP_DELIVERY.deliverWithReceipt!=='function') {
    throw new Error('private_delivery_unavailable');
  }
}
export async function sendPrivateWhatsAppOtp(env,input) {
  if(env.AUTH_DELIVERY_MODE!=='private-deduplicated'||env.AUTH_DELIVERY_ENABLED!=='true'||env.AUTH_SERVICE_ENABLED!=='true') {
    throw new Error('private_delivery_disabled');
  }
  requirePrivateDelivery(env);
  const {challengeId,clubId,phone,code,expiresAt,template}=input;
  // Caller lineage is server-supplied by dispatchOtp, not read from a user request.
  const request={challengeId,clubId,phone,code,expiresAt,template,channel:'whatsapp'};
  let result;
  try { result=await env.OTP_DELIVERY.deliverWithReceipt(request); }
  catch { throw new Error('private_delivery_unconfirmed'); }
  if(result?.accepted!==true||result.challengeId!==challengeId||
      typeof result.messageId!=='string'||result.messageId.length>256||
      !/^wamid\.[A-Za-z0-9+/_=:.-]+$/.test(result.messageId)) {
    throw new Error('private_delivery_unconfirmed');
  }
  return {accepted:true,messageId:result.messageId};
}
