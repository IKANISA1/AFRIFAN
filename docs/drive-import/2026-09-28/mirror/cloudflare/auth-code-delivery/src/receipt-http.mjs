import { ReceiptStore } from './receipt-store.mjs';
import { ReceiptError, RECEIPT_LIMITS as L, RECEIPT_PATH, object, statusNames, numericId, recipientId, messageId,
  requireReceipt, webhookConfiguration, recipientCommitment, sha } from './receipts-policy.mjs';
const encoder = new TextEncoder();
export function response(body, status = 200, text = false) {
  return new Response(text?body:JSON.stringify(body), {status,headers:{'content-type':text?'text/plain; charset=utf-8':'application/json',
    'cache-control':'no-store','x-content-type-options':'nosniff','referrer-policy':'no-referrer'}});
}
export async function signatureValid(bytes, header, secret) {
  if (typeof header !== 'string' || !/^sha256=[0-9a-fA-F]{64}$/.test(header)) return false;
  const signature=Uint8Array.from(header.slice(7).match(/../g),h=>parseInt(h,16));
  const key=await crypto.subtle.importKey('raw',encoder.encode(secret),{name:'HMAC',hash:'SHA-256'},false,['verify']);
  return crypto.subtle.verify('HMAC',key,signature,bytes);
}
async function equalSecret(actual, expected) {
  const key=await crypto.subtle.importKey('raw',encoder.encode(expected),{name:'HMAC',hash:'SHA-256'},false,['sign','verify']);
  const signed=await crypto.subtle.sign('HMAC',key,encoder.encode(expected));
  return crypto.subtle.verify('HMAC',key,signed,encoder.encode(actual));
}
export async function readRaw(request, deadlineMs = L.bodyDeadlineMs) {
  const type=(request.headers.get('content-type')??'').split(';')[0].trim().toLowerCase();
  requireReceipt(type==='application/json','unsupported_media_type',415);
  requireReceipt(!request.headers.has('content-encoding')||request.headers.get('content-encoding')==='identity','unsupported_encoding',415);
  const length=request.headers.get('content-length');
  requireReceipt(length===null||(/^\d+$/.test(length)&&Number(length)<=L.bodyBytes),'payload_too_large',413);
  requireReceipt(request.body,'invalid_receipt',400);
  const reader=request.body.getReader(),chunks=[];let size=0,timer;
  try {
    await Promise.race([(async()=>{while(true){const {done,value}=await reader.read();if(done)break;
      size+=value.byteLength;requireReceipt(size<=L.bodyBytes,'payload_too_large',413);chunks.push(value);}})(),
      new Promise((_,reject)=>{timer=setTimeout(()=>{void reader.cancel().catch(()=>{});reject(new ReceiptError('body_timeout',408));},deadlineMs);})]);
    const bytes=new Uint8Array(size);let offset=0;for(const chunk of chunks){bytes.set(chunk,offset);offset+=chunk.length;}return bytes;
  } finally { clearTimeout(timer);void reader.cancel().catch(()=>{});try{reader.releaseLock();}catch{} }
}
export async function normalize(bytes, env, routes, now) {
  let body;try{body=JSON.parse(new TextDecoder('utf-8',{fatal:true}).decode(bytes));}catch{throw new ReceiptError('invalid_json',400);}
  requireReceipt(object(body)&&body.object==='whatsapp_business_account'&&Array.isArray(body.entry)&&body.entry.length<=L.maxEntries);
  const events=[];let changeCount=0,eventCount=0;
  for(const entry of body.entry){
    requireReceipt(object(entry)&&numericId(entry.id)&&Array.isArray(entry.changes));
    changeCount+=entry.changes.length;requireReceipt(changeCount<=L.maxChanges,'payload_too_large',413);
    for(const change of entry.changes){
      requireReceipt(object(change));if(change.field!=='messages')continue;
      const v=change.value;requireReceipt(object(v)&&v.messaging_product==='whatsapp'&&object(v.metadata)&&numericId(v.metadata.phone_number_id));
      if(!routes.some(r=>r.businessAccountId===entry.id&&r.phoneNumberId===v.metadata.phone_number_id))continue;
      if(v.statuses===undefined)continue; // Inbound user messages are never stored or acted upon.
      requireReceipt(Array.isArray(v.statuses));eventCount+=v.statuses.length;requireReceipt(eventCount<=L.maxEvents,'payload_too_large',413);
      for(const s of v.statuses){
        requireReceipt(object(s));if(!statusNames.includes(s.status))continue;
        requireReceipt(messageId(s.id)&&recipientId(s.recipient_id)&&typeof s.timestamp==='string'&&/^\d{1,12}$/.test(s.timestamp));
        const at=Number(s.timestamp)*1000;requireReceipt(Number.isSafeInteger(at));
        if(at>now+L.futureSkewMs||at<now-L.maxAgeMs)continue; // Policy horizon, not authentication freshness.
        const errors=s.errors??[];requireReceipt(Array.isArray(errors)&&errors.length<=10);
        const codes=[];for(const e of errors){requireReceipt(object(e)&&Number.isSafeInteger(e.code)&&e.code>=0);codes.push(e.code);}
        const errorCodes=[...new Set(codes)].sort((a,b)=>a-b);
        const recipient=await recipientCommitment(env,entry.id,v.metadata.phone_number_id,s.recipient_id);
        const e={businessAccountId:entry.id,phoneNumberId:v.metadata.phone_number_id,messageId:s.id,
          recipientCommitment:recipient,status:s.status,providerAt:at,errorCodes};
        e.eventId=await sha(['wa-status-v1',e.businessAccountId,e.phoneNumberId,e.messageId,recipient,e.status,at,errorCodes]);events.push(e);
      }
    }
  }
  return events;
}
export async function handleReceipt(request, env, {clock=Date.now,bodyDeadlineMs=L.bodyDeadlineMs}={}) {
  try {
    const u=new URL(request.url);if(u.pathname!==RECEIPT_PATH)return response({error:'not_found'},404);
    requireReceipt(['GET','POST'].includes(request.method),'method_not_allowed',405);
    const config=webhookConfiguration(env);
    requireReceipt(u.origin===config.origin&&!u.username&&!u.password&&!u.hash,'invalid_origin',403);
    requireReceipt(!request.headers.has('cookie')&&!request.headers.has('origin'),'invalid_ingress',403);
    requireReceipt(env.RECEIPT_EDGE_LIMIT&&typeof env.RECEIPT_EDGE_LIMIT.limit==='function','abuse_control_unavailable',503);
    const allowed=await env.RECEIPT_EDGE_LIMIT.limit({key:'whatsapp-delivery-receipts-v1'});
    requireReceipt(allowed?.success===true,'rate_limited',429);
    if(request.method==='GET'){
      const keys=['hub.mode','hub.verify_token','hub.challenge'];
      requireReceipt([...u.searchParams.keys()].length===3&&keys.every(k=>u.searchParams.getAll(k).length===1),'invalid_verification',403);
      const token=u.searchParams.get('hub.verify_token'),challenge=u.searchParams.get('hub.challenge');
      requireReceipt(u.searchParams.get('hub.mode')==='subscribe'&&token.length<=128&&/^\d{1,256}$/.test(challenge),'invalid_verification',403);
      requireReceipt(await equalSecret(token,config.verify),'invalid_verification',403);
      return response(challenge,200,true);
    }
    requireReceipt(!u.search,'invalid_query',400);
    const sig=request.headers.get('x-hub-signature-256');
    requireReceipt(typeof sig==='string'&&/^sha256=[0-9a-fA-F]{64}$/.test(sig),'invalid_signature',403);
    const bytes=await readRaw(request,bodyDeadlineMs);
    requireReceipt(await signatureValid(bytes,sig,config.secret),'invalid_signature',403);
    const events=await normalize(bytes,env,config.routes,clock());
    await new ReceiptStore(env,{clock}).persist(events);
    return response({received:true});
  } catch(error) {
    if(error instanceof ReceiptError)return response({error:error.code},error.status);
    return response({error:'receipt_unavailable'},503); // Never leak provider bodies, SQL, identities or tokens.
  }
}
