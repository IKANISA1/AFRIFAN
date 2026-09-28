import {parseHistoryCursor,projectHistory,projectHistoryReceipt} from '../../shared/membership-history.mjs';
import {projectOffers} from './offers.mjs';
import {config,need,UUID,exactKeys,bounded,unwrap,session,rateKey,publicError,BrowserError,upstreamFields} from './policy.mjs';
import {ingress,cookies,body,response,cookieHeader,SESSION_COOKIE,BOOTSTRAP_COOKIE} from './http.mjs';
import {membershipStatus} from '../../supporter-membership-api/src/membership-status.mjs';
import {prepared,current,receipt} from '../../supporter-membership-api/src/projection.mjs';
const paths=new Map([
 ['/v1/browser/session/start',['POST','start']],
 ['/v1/browser/session/bootstrap',['GET','bootstrap']],
 ['/v1/browser/session/challenge',['POST','challenge']],
 ['/v1/browser/session/verify',['POST','verify']],
 ['/v1/browser/session',['GET','session']],
 ['/v1/browser/session/rotate',['POST','rotate']],
 ['/v1/browser/session/logout',['POST','logout']],
 ['/v1/browser/membership/offers',['GET','offers']],
 ['/v1/browser/membership/status',['GET','membership_status']],
 ['/v1/browser/membership/history',['GET','history']],
 ['/v1/browser/membership/checkouts',['POST','prepare']]
]);
function route(request,url){
 let p=paths.get(url.pathname);let orderId=null;
 if(!p){const h=url.pathname.match(/^\/v1\/browser\/membership\/history\/([0-9a-f-]{36})$/);if(h&&UUID.test(h[1])){orderId=h[1];p=['GET','history_receipt'];}}
 if(!p){const op=url.pathname.match(/^\/v1\/browser\/membership\/operations\/([0-9a-f-]{36})$/);
  if(op&&UUID.test(op[1])){orderId=op[1];p=['GET','lookup'];}}
 if(!p){const m=url.pathname.match(/^\/v1\/browser\/membership\/checkouts\/([0-9a-f-]{36})(\/receipt)?$/);
  if(m&&UUID.test(m[1])){orderId=m[1];p=['GET',m[2]?'receipt':'checkout'];}}
 need(p&&request.method===p[0],'not_found',404);return {operation:p[1],orderId};
}
function same(a,b){return a.userId===b.userId&&a.clubId===b.clubId&&a.sessionId===b.sessionId&&a.authenticatedAt===b.authenticatedAt;}
function bootstrapView(v,id,now){
 upstreamFields(v,['schemaVersion','clubId','csrfToken','expiresAt']);
 need(v.schemaVersion===1&&v.clubId===id&&typeof v.csrfToken==='string'&&/^[0-9a-f]{64}$/.test(v.csrfToken)&&
  Number.isSafeInteger(v.expiresAt)&&v.expiresAt>now&&v.expiresAt<=now+600000,'identity_unavailable',503);
 return {...v};
}
/** Dedicated browser ingress. No native-header translation, public DB or provider capability. */
export function createBrowserGateway({clock=Date.now,rpcMs=8000,bodyMs=3000}={}){
 need(Number.isInteger(rpcMs)&&rpcMs>0&&rpcMs<=8000&&Number.isInteger(bodyMs)&&bodyMs>0&&bodyMs<=3000);
 return {async fetch(request,env){
  let invoked=false,kind=null,requestId=null;
  try{
   const cfg=config(env),{url,ip}=ingress(request,cfg),r=route(request,url),c=cookies(request);
   const historyCursor=request.headers.get('x-africlub-history-cursor');
   need(r.operation==='history'||historyCursor===null);
   kind=r.operation;const writing=request.method==='POST';
   if(!writing)need(!request.body&&!request.headers.has('idempotency-key'));
   const ipHash=await rateKey(env.BROWSER_RATE_KEY,'browser-ip',`${Math.floor(clock()/86400000)}:${ip}`);
   need((await bounded(()=>env.EDGE_LIMIT.limit({key:ipHash}),rpcMs))?.success===true,'rate_limited',429);
   const rpc=async(method,input)=>unwrap(await bounded(()=>env.BROWSER_IDENTITY[method](input),rpcMs));
   const authenticate=async()=>session(await rpc('current',c.sessionCookie),cfg.clubId,clock());
   let data={},output,setCookies=[];
   if(writing){
    data=await body(request,{timeout:bodyMs});
    if(kind!=='start'){requestId=request.headers.get('idempotency-key');need(typeof requestId==='string'&&UUID.test(requestId));}
    else need(!request.headers.has('idempotency-key'));
   }
   const csrfToken=request.headers.get('x-africlub-csrf');
   if(writing&&kind!=='start')need(typeof csrfToken==='string'&&/^[0-9a-f]{64}$/.test(csrfToken),'csrf_rejected',403);
   if(kind==='start'){
    exactKeys(data,[]);const raw=await rpc('start',{sessionCookie:c.sessionCookie});
    upstreamFields(raw,['bootstrapCookie','view']);
    output=bootstrapView(raw.view,cfg.clubId,clock());
    setCookies=[cookieHeader(BOOTSTRAP_COOKIE,raw.bootstrapCookie,Math.max(1,Math.floor((output.expiresAt-clock())/1000)))];
   }else if(kind==='bootstrap')output=bootstrapView(await rpc('bootstrap',c.bootstrapCookie),cfg.clubId,clock());
   else if(kind==='challenge'){
    exactKeys(data,['phone']);need(c.bootstrapCookie,'bootstrap_required',401);
    invoked=true;
    const raw=await rpc('challenge',{...c,csrfToken,requestId,ipKey:ipHash,input:data});
    upstreamFields(raw,['schemaVersion','clubId','challengeId','expiresAt','delivery']);
    need(raw.schemaVersion===1&&raw.clubId===cfg.clubId&&UUID.test(raw.challengeId)&&raw.delivery==='queued_or_pending'&&
     Number.isSafeInteger(raw.expiresAt)&&raw.expiresAt>clock()&&raw.expiresAt<=clock()+600000,'identity_unavailable',503);
    output={...raw};
   }else if(kind==='verify'||kind==='rotate'){
    exactKeys(data,kind==='verify'?['challengeId','code']:[]);
    if(kind==='verify')need(c.bootstrapCookie,'bootstrap_required',401);
    else need(c.sessionCookie,'unauthenticated',401);
    invoked=true;
    const raw=await rpc(kind,{...c,csrfToken,requestId,...(kind==='verify'?{input:data}:{})});
    upstreamFields(raw,['sessionCookie','view']);output=session(raw.view,cfg.clubId,clock());
    need(typeof raw.sessionCookie==='string'&&raw.sessionCookie.length===80&&raw.sessionCookie.startsWith(`${output.sessionId}.`),'identity_unavailable',503);
    const after=session(await rpc('current',raw.sessionCookie),cfg.clubId,clock());
    need(same(output,after),'session_changed',409);config(env);
    output=after;
    setCookies=[cookieHeader(SESSION_COOKIE,raw.sessionCookie,Math.max(1,Math.floor((output.expiresAt-clock())/1000)))];
   }else if(kind==='logout'){
    exactKeys(data,[]);need(c.sessionCookie,'unauthenticated',401);invoked=true;
    const raw=await rpc('logout',{sessionCookie:c.sessionCookie,csrfToken,requestId});
    upstreamFields(raw,['schemaVersion','loggedOut','scope']);need(raw.schemaVersion===1&&raw.loggedOut===true&&raw.scope==='current','identity_unavailable',503);
    output={...raw};setCookies=[cookieHeader(SESSION_COOKIE,'',0),cookieHeader(BOOTSTRAP_COOKIE,'',0)];
   }else{
    const actor=await authenticate();
    if(kind==='history'){try{parseHistoryCursor(historyCursor,actor);}catch{need(false,'invalid_request',400);}}
    if(kind==='session')output=actor;
    else{
     need(env.BROWSER_MEMBERSHIP_ENABLED==='true','browser_disabled',503);
     need(request.headers.get('x-africlub-browser-session')===actor.sessionId,'session_changed',409);
     const subject=await rateKey(env.BROWSER_RATE_KEY,'browser-subject',`${cfg.clubId}:${actor.userId}:${Math.floor(clock()/86400000)}`);
     need((await bounded(()=>env.SUBJECT_LIMIT.limit({key:subject}),rpcMs))?.success===true,'rate_limited',429);
     if(kind==='history'||kind==='history_receipt'){
      const method=kind==='history'?'history':'historicalReceipt';
      need(typeof env.CHECKOUT_READER?.[method]==='function','service_unavailable',503);
      const input={clubId:actor.clubId,userId:actor.userId,...(kind==='history'?{cursor:historyCursor,limit:20}:{orderId:r.orderId})};
      let raw;try{raw=await bounded(()=>env.CHECKOUT_READER[method](input),rpcMs);}
      catch(e){if(e?.code==='not_found')need(false,'not_found',404);if(['checkout_permission_denied','permission_denied'].includes(e?.code))need(false,'permission_denied',403);throw e;}
      try{output=kind==='history'?projectHistory(raw,actor,clock(),historyCursor):projectHistoryReceipt(raw,actor,r.orderId,clock());}
      catch{need(false,'service_unavailable',503);}
     }else if(kind==='membership_status'){
      need(typeof env.CHECKOUT_READER?.membershipStatus==='function','service_unavailable',503);
      output=membershipStatus(await bounded(()=>env.CHECKOUT_READER.membershipStatus({clubId:actor.clubId,userId:actor.userId}),rpcMs),actor,clock());
     }else{
      need(env.BROWSER_CHECKOUT_ENABLED==='true','browser_disabled',503);
      if(kind==='offers'){
       need(typeof env.CHECKOUT_READER?.offers==='function','service_unavailable',503);
       output=projectOffers(await bounded(()=>env.CHECKOUT_READER.offers({clubId:actor.clubId,userId:actor.userId}),rpcMs),actor,clock());
      }else if(kind==='lookup'){
       need(typeof env.CHECKOUT?.lookupPreparedOperation==='function','service_unavailable',503);
       const found=await bounded(()=>env.CHECKOUT.lookupPreparedOperation({clubId:actor.clubId,userId:actor.userId,requestId:r.orderId}),rpcMs);
       upstreamFields(found,['schemaVersion','clubId','userId','requestId','observedAt','found','mayRetryWithNewKey','result']);
       need(found.schemaVersion===1&&found.clubId===actor.clubId&&found.userId===actor.userId&&found.requestId===r.orderId&&
        typeof found.found==='boolean'&&found.mayRetryWithNewKey===false&&Number.isSafeInteger(found.observedAt)&&
        found.observedAt<=clock()+1000&&found.observedAt>=clock()-10000,'service_unavailable',503);
       need(found.found?found.result!==null:found.result===null,'service_unavailable',503);
       const result=found.found?prepared(found.result,actor,r.orderId,found.result.checkout?.tier):null;
       output={schemaVersion:1,clubId:actor.clubId,requestId:r.orderId,observedAt:found.observedAt,found:found.found,mayRetryWithNewKey:false,result};
      }else if(kind==='prepare'){
       exactKeys(data,['tier']);need(typeof data.tier==='string'&&/^[a-z0-9][a-z0-9_-]{0,31}$/.test(data.tier));
       need(csrfToken===actor.csrfToken,'csrf_rejected',403);
       need(typeof env.CHECKOUT?.prepare==='function','service_unavailable',503);
       need(same(actor,await authenticate()),'session_changed',409);config(env);
       need(env.BROWSER_CHECKOUT_ENABLED==='true','browser_disabled',503);
       invoked=true;
       output=prepared(await bounded(()=>env.CHECKOUT.prepare({clubId:actor.clubId,userId:actor.userId,requestId,tier:data.tier}),rpcMs),actor,requestId,data.tier);
      }else{
       need(typeof env.CHECKOUT_READER?.read==='function','service_unavailable',503);
       const state=await bounded(()=>env.CHECKOUT_READER.read({clubId:actor.clubId,userId:actor.userId,orderId:r.orderId}),rpcMs);
       output=current(state,actor,r.orderId,clock());
       if(kind==='receipt'){
        need(state.status==='allocated','not_found',404);
        need(typeof env.PAYMENT_RECEIPTS?.readReceipt==='function','service_unavailable',503);
        need(same(actor,await authenticate()),'session_changed',409);
        output=receipt(await bounded(()=>env.PAYMENT_RECEIPTS.readReceipt({clubId:actor.clubId,orderId:r.orderId}),rpcMs),actor,state.checkout);
       }
      }
     }
    }
    need(same(actor,await authenticate()),'session_changed',409);config(env);
    if(kind!=='session')need(env.BROWSER_MEMBERSHIP_ENABLED==='true','browser_disabled',503);
    if(['prepare','checkout','receipt','lookup','offers'].includes(kind))need(env.BROWSER_CHECKOUT_ENABLED==='true','browser_disabled',503);
    if(kind==='history'||kind==='history_receipt'){try{output=kind==='history'?projectHistory(output,actor,clock(),historyCursor):projectHistoryReceipt(output,actor,r.orderId,clock());}catch{need(false,'service_unavailable',503);}}
    if(kind==='membership_status')output=membershipStatus(output,actor,clock());
    if(kind==='offers')output=projectOffers({...output,userId:actor.userId},actor,clock());
    if(output.status==='pending_current'&&output.expiresAt<=clock())output={...output,status:'expired',paymentInstruction:null};
   }
   return response(output,200,setCookies);
  }catch(e){
   const error=publicError(e);
   // Timeouts do not cancel remote work. Retain the original key, never infer failed payment.
   if(invoked&&(kind==='prepare'||error.status>=500||error.code==='session_changed'))
    return response({schemaVersion:1,error:kind==='prepare'?'checkout_outcome_unknown':'identity_outcome_unknown',outcome:'unknown',requestId},503);
   return response({schemaVersion:1,error:error.code},error.status);
  }
 }};
}
export default createBrowserGateway();
