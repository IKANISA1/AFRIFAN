import {normalizeObservation,observationConfiguration} from './contracts.mjs';
const NOW_SQL="CAST(unixepoch('subsec') * 1000 AS INTEGER)";
const exact=(v,keys)=>v!==null&&typeof v==='object'&&!Array.isArray(v)&&
 Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k));
const demand=value=>{if(!value)throw Error('web_observation_unavailable');};
/** Separate observational database: no auth lookup, identity, cookie, location or financial capability. */
export class PrivateWebObservationStore {
 constructor(env){this.env=env;}
 config(){const config=observationConfiguration(this.env,true);
  demand(config&&typeof this.env.WEB_OBSERVATIONS_DB?.prepare==='function');return config;}
 async record(input){try{
  const config=this.config();demand(exact(input,['observation','clubId','retentionMs','policyRef'])&&
   input.clubId===config.clubId&&input.retentionMs===config.retentionMs&&input.policyRef===config.policyRef);
  const observation=normalizeObservation(input.observation);demand(observation);
  demand(JSON.stringify(this.config())===JSON.stringify(config));
  // One atomic statement enforces a bounded per-club quota without recording any client/IP key.
  const result=await this.env.WEB_OBSERVATIONS_DB.prepare(`INSERT INTO private_web_observations
   (record_id,club_id,event,observation_json,recorded_at_ms,expires_at_ms)
   SELECT ?,?,?,?,${NOW_SQL},${NOW_SQL}+?
   WHERE (SELECT count(*) FROM private_web_observations
    WHERE club_id=? AND recorded_at_ms>${NOW_SQL}-60000)<300`)
   .bind(crypto.randomUUID(),config.clubId,observation.event,JSON.stringify(observation),
    config.retentionMs,config.clubId).run();
  demand(result.meta?.changes===1);return {schemaVersion:1,recorded:true};
 }catch{throw Error('web_observation_unavailable');}}
 async expire(input){try{
  const config=this.config();demand(exact(input,['limit'])&&Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=1000);
  const result=await this.env.WEB_OBSERVATIONS_DB.prepare(`DELETE FROM private_web_observations WHERE record_id IN
   (SELECT record_id FROM private_web_observations WHERE club_id=? AND expires_at_ms<=${NOW_SQL}
    ORDER BY expires_at_ms,record_id LIMIT ?)`).bind(config.clubId,input.limit).run();
  const removed=result?.meta?.changes;
  demand(Number.isInteger(removed)&&removed>=0&&removed<=input.limit);
  return {schemaVersion:1,removed};
 }catch{throw Error('web_observation_unavailable');}}
}

/** A disabled deployment has no database access. Enabled maintenance is scoped
 * to the same club/policy selection as writes and bounded to one batch per tick. */
export async function runWebObservationRetention(env){
 if(!observationConfiguration(env,true))return {schemaVersion:1,enabled:false,removed:0};
 const result=await new PrivateWebObservationStore(env).expire({limit:1000});
 return {...result,enabled:true};
}
