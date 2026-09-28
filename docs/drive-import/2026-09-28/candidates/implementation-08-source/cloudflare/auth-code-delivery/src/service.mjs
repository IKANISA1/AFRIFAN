import {configuration,inputRequest,demand,exact,DeliveryError,LIMITS} from './policy.mjs';
import {inspectTemplate,graphJson,payload,acceptedMessage,withDeadline} from './graph.mjs';
const encode=new TextEncoder();
async function commitment(key,value) {
  const bytes=Uint8Array.from(key.match(/../g),h=>parseInt(h,16));
  const k=await crypto.subtle.importKey('raw',bytes,{name:'HMAC',hash:'SHA-256'},false,['sign']);
  return Array.from(new Uint8Array(await crypto.subtle.sign('HMAC',k,encode.encode(JSON.stringify(value)))),n=>n.toString(16).padStart(2,'0')).join('');
}
export class AuthenticationCodeDeliveryService {
  constructor(env,{clock=()=>Date.now(),fetcher=(...a)=>fetch(...a),deadlineMs=LIMITS.deadlineMs}={}) {
    this.env=env;this.clock=clock;this.fetcher=fetcher;
    demand(Number.isInteger(deadlineMs)&&deadlineMs>0&&deadlineMs<=LIMITS.deadlineMs,'invalid_delivery_config');this.deadlineMs=deadlineMs;
  }
  first(sql,...args){return this.env.DELIVERY_DB.withSession('first-primary').prepare(sql).bind(...args).first();}
  write(sql,...args){return this.env.DELIVERY_DB.prepare(sql).bind(...args).run();}
  result(row,input,hash,routeHash){
    demand(row&&row.request_commitment===hash&&row.club_id===input.clubId&&row.route_commitment===routeHash,'dispatch_conflict');
    return {accepted:row.state==='accepted'&&row.expires_at>this.clock(),challengeId:input.challengeId};
  }
  /** Current queued-auth adapter: enforce its server-selected template and return
   * the durable provider acceptance receipt. No delivery-to-handset claim. */
  async deliverWithReceipt(raw) {
    exact(raw,['challengeId','clubId','phone','code','expiresAt','channel','template']);
    const {template,...request}=raw;
    demand(typeof template==='string'&&/^[a-z][a-z0-9_]{0,511}$/.test(template));
    const route=configuration(this.env,this.clock()).routes.find(r=>r.clubId===request.clubId);
    demand(route&&route.templateName===template,'template_not_approved');
    const result=await this.deliver(request);
    if(!result.accepted)return result;
    const row=await this.first('SELECT * FROM delivery_dispatches WHERE challenge_id=?',request.challengeId);
    demand(row?.state==='accepted'&&row.club_id===request.clubId&&typeof row.provider_message_id==='string','delivery_unavailable');
    return {...result,messageId:row.provider_message_id};
  }
  async deliver(raw) {
    const now=this.clock(),input=inputRequest(raw,now),config=configuration(this.env,now);
    const route=config.routes.find(r=>r.clubId===input.clubId);demand(route,'unmapped_club');
    const key=this.env.DISPATCH_HMAC_KEY;
    const hash=await commitment(key,['dispatch-v1',input.challengeId,input.clubId,input.phone,input.code,input.expiresAt,input.channel]);
    const routeHash=await commitment(key,['route-v1',config.version,route]);
    // A durable claim precedes ANY provider call. After a crash, reserved means unknown:
    // it can never authorize a second POST, even if the first process sent nothing.
    const claim=await this.first(`INSERT INTO delivery_dispatches(challenge_id,club_id,request_commitment,route_commitment,state,created_at,expires_at)
      VALUES (?,?,?,?,'reserved',?,?) ON CONFLICT(challenge_id) DO NOTHING RETURNING challenge_id`,
      input.challengeId,input.clubId,hash,routeHash,now,input.expiresAt);
    if(!claim)return this.result(await this.first('SELECT * FROM delivery_dispatches WHERE challenge_id=?',input.challengeId),input,hash,routeHash);
    let messageId,reason;
    try{
      messageId=await withDeadline(async signal=>{
        await inspectTemplate(this.fetcher,config,route,this.env.WA_ACCESS_TOKEN,signal);
        demand(!signal.aborted,'provider_timeout');
        demand(input.expiresAt-this.clock()>=LIMITS.minimumRemainingMs,'too_late');
        // Recheck the kill switch and reviewed route immediately before external dispatch.
        const current=configuration(this.env,this.clock());
        demand(JSON.stringify(current)===JSON.stringify(config),'template_not_approved');
        const response=await graphJson(this.fetcher,config,`${route.phoneNumberId}/messages`,this.env.WA_ACCESS_TOKEN,
          {body:payload(input,route),signal});
        return acceptedMessage(response,input);
      },this.deadlineMs);
    }catch(error){
      const allowed=['provider_rejected','provider_unknown','provider_unreachable','provider_timeout','invalid_provider_response',
        'template_not_approved','provider_not_accepted','too_late'];
      reason=allowed.includes(error?.code)?error.code:'provider_unknown';
    }
    const state=messageId?'accepted':['provider_rejected','template_not_approved','too_late'].includes(reason)?'rejected':'unknown';
    // A provider acceptance is not durable until this write succeeds. Never infer it after a failed write.
    const done=await this.write(`UPDATE delivery_dispatches SET state=?,provider_message_id=?,reason=?,completed_at=?
      WHERE challenge_id=? AND state='reserved' AND request_commitment=?`,state,messageId??null,reason??null,this.clock(),input.challengeId,hash);
    demand(done.meta?.changes===1,'delivery_unavailable');
    return {accepted:state==='accepted'&&input.expiresAt>this.clock(),challengeId:input.challengeId};
  }
}
