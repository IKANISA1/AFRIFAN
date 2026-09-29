import {parseHistoryCursor,projectHistory,projectHistoryReceipt} from '../../shared/membership-history.mjs';
import {membershipStatus} from './membership-status.mjs';
import {handoffProjection} from './handoff-projection.mjs';
import {config,need,UUID,bounded,rateKey,errorCode,GatewayError,LIMITS} from './policy.mjs';
import {route,ingress,token,prepareBody,response} from './http.mjs';
import {identity,prepared,current,receipt} from './projection.mjs';
/** Direct native ingress. No cookie auth, DB, provider, payment allocation or caching. */
export function createGateway({clock=Date.now,rpcMs=LIMITS.rpcMs,bodyMs=LIMITS.bodyMs}={}){
  need(Number.isInteger(rpcMs)&&rpcMs>0&&rpcMs<=LIMITS.rpcMs && Number.isInteger(bodyMs)&&bodyMs>0&&bodyMs<=LIMITS.bodyMs);
  return {async fetch(request,env){
    let writeInvoked=false,requestId=null,journalWrite=false;
    try {
      const r=route(request),routes=config(env);
      need(routes.some(c=>c.clubId===r.clubId),'not_found',404);
      const ip=ingress(request,env,r.url),accessToken=token(request);
      const writing=['prepare','handoff_reserve','handoff_claim','handoff_release'].includes(r.operation);
      if(!writing)need(!request.body&&!request.headers.has('idempotency-key'),'invalid_request',400);
      if(r.operation.startsWith('handoff_'))need(env.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED==='true','handoff_disabled',503);
      const day=Math.floor(clock()/86400000);
      const ipKey=await rateKey(env.GATEWAY_RATE_KEY,'membership-ip',`${day}:${ip}`);
      const edge=await bounded(()=>env.EDGE_LIMIT.limit({key:ipKey}),rpcMs);
      need(edge?.success===true,'rate_limited',429);
      const authenticate=async()=>identity(await bounded(()=>env.IDENTITY.current({clubId:r.clubId,accessToken}),rpcMs),r.clubId,accessToken,clock());
      const actor=await authenticate();
      const historyCursor=request.headers.get('x-africlub-history-cursor');
      need(r.operation==='history'||historyCursor===null,'invalid_request',400);
      if(r.operation==='history'){try{parseHistoryCursor(historyCursor,actor);}catch{need(false,'invalid_request',400);}}
      if(r.operation==='session')need(!request.headers.has('x-africlub-session'),'invalid_request',400);
      else need(request.headers.get('x-africlub-session')===actor.sessionId,'session_changed',409);
      const subjectKey=await rateKey(env.GATEWAY_RATE_KEY,'membership-subject',`${day}:${r.clubId}:${actor.userId}`);
      const subject=await bounded(()=>env.SUBJECT_LIMIT.limit({key:subjectKey}),rpcMs);
      need(subject?.success===true,'rate_limited',429);
      let output,readState;
      if(r.operation==='session'){
        output={schemaVersion:1,userId:actor.userId,clubId:actor.clubId,sessionId:actor.sessionId};
      } else if(r.operation==='history'||r.operation==='history_receipt'){
        const method=r.operation==='history'?'history':'historicalReceipt';
        need(typeof env.CHECKOUT_READER[method]==='function','service_unavailable',503);
        const input={clubId:actor.clubId,userId:actor.userId,...(r.operation==='history'?{cursor:historyCursor,limit:20}:{orderId:r.orderId})};
        const raw=await bounded(()=>env.CHECKOUT_READER[method](input),rpcMs);
        try{output=r.operation==='history'?projectHistory(raw,actor,clock(),historyCursor):projectHistoryReceipt(raw,actor,r.orderId,clock());}
        catch{need(false,'upstream_contract_invalid',503);}
      } else if(r.operation==='membership_status'){
        need(typeof env.CHECKOUT_READER.membershipStatus==='function','service_unavailable',503);
        output=membershipStatus(await bounded(()=>env.CHECKOUT_READER.membershipStatus({clubId:actor.clubId,userId:actor.userId}),rpcMs),actor,clock());
      } else if(r.operation==='handoff_current'){
        const raw=await bounded(()=>env.CHECKOUT_READER.currentHandoff({clubId:actor.clubId,userId:actor.userId}),rpcMs);
        output=handoffProjection(raw,actor,r.operation,null,clock());
      } else if(['handoff_reserve','handoff_claim','handoff_release'].includes(r.operation)){
        if(r.operation==='handoff_release')need(env.MEMBERSHIP_HANDOFF_RELEASE_ENABLED==='true','handoff_disabled',503);
        requestId=request.headers.get('idempotency-key');need(typeof requestId==='string'&&UUID.test(requestId),'invalid_request',400);
        const field=r.operation==='handoff_reserve'?'orderId':'handoffId',body=await prepareBody(request,bodyMs,field);
        const before=await authenticate();need(sameActor(actor,before),'unauthenticated',401);config(env);
        need(env.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED==='true','handoff_disabled',503);
        if(r.operation==='handoff_release')need(env.MEMBERSHIP_HANDOFF_RELEASE_ENABLED==='true','handoff_disabled',503);
        writeInvoked=true;journalWrite=true;
        const method=r.operation==='handoff_reserve'?'reserveHandoff':r.operation==='handoff_release'?'releaseHandoff':'claimHandoff';
        const raw=await bounded(()=>env.CHECKOUT[method]({clubId:actor.clubId,userId:actor.userId,requestId,...body}),rpcMs);
        output=handoffProjection(raw,actor,r.operation,body[field],clock());
      } else if(r.operation==='prepare'){
        requestId=request.headers.get('idempotency-key');need(typeof requestId==='string'&&UUID.test(requestId),'invalid_request',400);
        const body=await prepareBody(request,bodyMs);
        // Recheck immediately before invoking a write, after body parsing/rate waits.
        const before=await authenticate();need(sameActor(actor,before),'unauthenticated',401);config(env);
        writeInvoked=true;
        const result=await bounded(()=>env.CHECKOUT.prepare({requestId,clubId:actor.clubId,userId:actor.userId,tier:body.tier}),rpcMs);
        output=prepared(result,actor,requestId,body.tier);
      } else {
        const state=await bounded(()=>env.CHECKOUT_READER.read({clubId:actor.clubId,userId:actor.userId,orderId:r.orderId}),rpcMs);
        if(r.operation==='read')readState=state;
        output=current(state,actor,r.orderId,clock()); // ownership and full contract before broader receipt service
        if(r.operation==='receipt'){
          need(state.status==='allocated','receipt_not_available',409);
          const mid=await authenticate();need(sameActor(actor,mid),'unauthenticated',401);config(env);
          const raw=await bounded(()=>env.PAYMENT_RECEIPTS.readReceipt({clubId:actor.clubId,orderId:r.orderId}),rpcMs);
          output=receipt(raw,actor,state.checkout);
        }
      }
      const after=await authenticate();need(sameActor(actor,after),'unauthenticated',401);config(env);
      // Final introspection can take long enough to make a once-current payment
      // instruction stale. Recheck freshness at the same disclosure boundary as
      // current membership and history; a delayed read never authorizes payment.
      if(r.operation==='read')output=current(readState,actor,r.orderId,clock());
      if(journalWrite){if(r.operation==='handoff_release')need(env.MEMBERSHIP_HANDOFF_RELEASE_ENABLED==='true','handoff_disabled',503);need(env.MEMBERSHIP_HANDOFF_JOURNAL_ENABLED==='true','handoff_disabled',503);
        if(output.mayOpenDialer&&output.handoff.orderExpiresAt<=clock()+15000)output={...output,mayOpenDialer:false};}
      if(r.operation==='history'||r.operation==='history_receipt'){try{output=r.operation==='history'?projectHistory(output,actor,clock(),historyCursor):projectHistoryReceipt(output,actor,r.orderId,clock());}catch{need(false,'upstream_contract_invalid',503);}}
      if(r.operation==='membership_status')output=membershipStatus(output,actor,clock());
      if(output.status==='pending_current'&&output.expiresAt<=clock()){
        output={...output,status:'expired',paymentInstruction:null};
      }
      return response(output);
    } catch(error){
      // Remote execution may commit even when RPC/HTTP times out or post-checks
      // deny disclosure. Preserve the ORIGINAL key; do not assert a failed write.
      if(writeInvoked)return response({schemaVersion:1,error:journalWrite?'handoff_outcome_unknown':'checkout_outcome_unknown',outcome:'unknown',requestId},503);
      if(error instanceof GatewayError)return response({schemaVersion:1,error:error.code},error.status);
      const code=errorCode(error);
      const status=code==='not_found'?404:['permission_denied','checkout_permission_denied'].includes(code)?403:code==='checkout_rate_limited'?429:503;
      return response({schemaVersion:1,error:status===403?'permission_denied':status===429?'rate_limited':code},status);
    }
  }};
}
function sameActor(a,b){return a.userId===b.userId&&a.clubId===b.clubId&&a.sessionId===b.sessionId&&a.authenticatedAt===b.authenticatedAt;}
export default createGateway();
