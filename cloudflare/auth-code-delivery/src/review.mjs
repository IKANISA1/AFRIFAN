import {queueMetric,emitMetricDetached,traceOperation} from '../../shared-telemetry/telemetry.mjs';
import {demand,exact} from './policy.mjs';
const STATES=['reserved','accepted','rejected','unknown'];
const UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
/** Read-only private binding. No provider credential, challenge creation, claim reset or message dispatch. */
export class AuthenticationDispatchReview {
 constructor(env,{clock=Date.now,ctx}={}){this.env=env;this.clock=clock;this.context=ctx;}
 clubs(){
  demand(this.env.AUTH_DISPATCH_REVIEW_ENABLED==='true'&&this.env.AUTH_DISPATCH_REVIEW_ENVIRONMENT==='isolated-staging','delivery_unavailable');
  let clubs;try{clubs=JSON.parse(this.env.AUTH_DISPATCH_REVIEW_CLUB_IDS);}catch{demand(false,'delivery_unavailable');}
  demand(Array.isArray(clubs)&&clubs.length>0&&clubs.length<=5&&clubs.every(x=>Number.isSafeInteger(x)&&x>0)&&new Set(clubs).size===clubs.length&&
   this.env.DELIVERY_DB?.prepare&&this.env.DELIVERY_DB?.withSession,'delivery_unavailable');return clubs;
 }
 primary(){return this.env.DELIVERY_DB.withSession('first-primary');}
 async health(input){
  return traceOperation(this.env,{service:'auth_code_delivery',operation:'queue_health',clubId:input?.clubId},async()=>{
   exact(input,['clubId']);demand(this.clubs().includes(input.clubId));const observedAt=this.clock();demand(Number.isSafeInteger(observedAt)&&observedAt>=0,'delivery_unavailable');
   const counts={},ages={};let capped=false;
   for(const state of STATES){
    const row=await this.primary().prepare(`SELECT count(*) n,min(created_at) oldest_at FROM
      (SELECT created_at FROM delivery_dispatches WHERE club_id=? AND state=? ORDER BY created_at,challenge_id LIMIT 1001)`).bind(input.clubId,state).first();
    counts[state]=Math.min(row.n,1000);capped||=row.n>1000;ages[state]=row.oldest_at===null?null:Math.max(0,observedAt-row.oldest_at);
   }
   demand(this.clubs().includes(input.clubId),'delivery_unavailable');
   for(const state of STATES)emitMetricDetached(this.env,queueMetric({service:'auth_code_delivery',clubId:input.clubId,observedAt,state,count:counts[state],
    oldestAt:ages[state]===null?null:observedAt-ages[state],capped:counts[state]===1000}),this.context);
   return {schemaVersion:1,clubId:input.clubId,observedAt,counts,oldestAgeMs:ages,capped,snapshot:false,
    meaning:'provider dispatch claims; accepted is not handset delivery; reserved and unknown must never be resent'};
  },{clock:this.clock,ctx:this.context});
 }
 async inspect(input){
  return traceOperation(this.env,{service:'auth_code_delivery',operation:'delivery_inspection',clubId:input?.clubId},async()=>{
   exact(input,['clubId','state','afterChallengeId','limit']);demand(this.clubs().includes(input.clubId)&&typeof input.state==='string'&&STATES.includes(input.state)&&
    (input.afterChallengeId===null||(typeof input.afterChallengeId==='string'&&UUID.test(input.afterChallengeId)))&&Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=50);
   const rows=await this.primary().prepare(`SELECT challenge_id,state,reason,created_at,expires_at,completed_at FROM delivery_dispatches
    WHERE club_id=? AND state=? AND challenge_id>? ORDER BY challenge_id LIMIT ?`).bind(input.clubId,input.state,input.afterChallengeId??'',input.limit+1).all();
   demand(this.clubs().includes(input.clubId),'delivery_unavailable');const more=rows.results.length>input.limit;
   const items=rows.results.slice(0,input.limit).map(row=>({challengeId:row.challenge_id,state:row.state,reason:row.reason,createdAt:row.created_at,
    expiresAt:row.expires_at,completedAt:row.completed_at,replayAllowed:false}));
   return {schemaVersion:1,clubId:input.clubId,items,nextAfterChallengeId:more?items.at(-1).challengeId:null,snapshot:false,replayAllowed:false};
  },{clock:this.clock,ctx:this.context});
 }
}
