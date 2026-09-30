import {normalizeMetric} from './telemetry.mjs';
const NOW_SQL="CAST(unixepoch('subsec') * 1000 AS INTEGER)",UUID=/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
function demand(value){if(!value)throw Error('metrics_unavailable');}
function exact(value,keys){demand(value!==null&&typeof value==='object'&&!Array.isArray(value)&&Object.keys(value).length===keys.length&&keys.every(key=>Object.hasOwn(value,key)));}
/** Private binding receiver. Retention is fixed by server configuration, never selected by a request. */
export class PrivateMetricsStore {
 constructor(env){this.env=env;}
 config(){
  demand(this.env.PRIVATE_METRICS_STORE_ENABLED==='true'&&this.env.PRIVATE_METRICS_ENVIRONMENT==='isolated-staging'&&this.env.METRICS_DB?.prepare&&this.env.METRICS_DB?.withSession);
  const text=this.env.PRIVATE_METRICS_RETENTION_MS,retention=typeof text==='string'&&/^[1-9][0-9]{0,10}$/.test(text)?Number(text):NaN;
  demand(Number.isSafeInteger(retention)&&retention>=3600000&&retention<=31622400000&&typeof this.env.PRIVATE_METRICS_POLICY_REF==='string'&&/^[A-Z][A-Z0-9_-]{3,63}$/.test(this.env.PRIVATE_METRICS_POLICY_REF));
  return {retentionMs:retention,policyRef:this.env.PRIVATE_METRICS_POLICY_REF};
 }
 primary(){return this.env.METRICS_DB.withSession('first-primary');}
 async record(input){try{
  exact(input,['metric','retentionMs','policyRef']);const config=this.config();demand(input.retentionMs===config.retentionMs&&input.policyRef===config.policyRef);
  const metric=normalizeMetric(input.metric);demand(metric);const serialized=JSON.stringify(metric);demand(new TextEncoder().encode(serialized).byteLength<=2048);
  const now=await this.primary().prepare(`SELECT ${NOW_SQL} now_ms`).first();demand(metric.observedAt<=now.now_ms+5000&&metric.observedAt>=now.now_ms-86400000);
  // Recheck configuration immediately before the isolated observational write. This write grants no domain effect.
  demand(JSON.stringify(this.config())===JSON.stringify(config));
  await this.env.METRICS_DB.prepare(`INSERT INTO private_metrics(record_id,metric_json,event,service,trace_id,recorded_at_ms,expires_at_ms)
   VALUES(?,?,?,?,?,${NOW_SQL},${NOW_SQL}+?)`).bind(crypto.randomUUID(),serialized,metric.event,metric.service,metric.traceId??null,config.retentionMs).run();
  return {schemaVersion:1,recorded:true};
 }catch{throw Error('metrics_unavailable');}}
 async readTrace(input){try{
  exact(input,['traceId','limit']);this.config();demand(typeof input.traceId==='string'&&UUID.test(input.traceId)&&Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=50);
  const rows=await this.primary().prepare(`SELECT metric_json FROM private_metrics WHERE trace_id=? AND expires_at_ms>${NOW_SQL} ORDER BY recorded_at_ms,record_id LIMIT ?`).bind(input.traceId,input.limit+1).all();
  this.config();const items=rows.results.slice(0,input.limit).map(row=>normalizeMetric(JSON.parse(row.metric_json)));demand(items.every(Boolean));
  return {schemaVersion:1,items,capped:rows.results.length>input.limit,snapshot:false};
 }catch{throw Error('metrics_unavailable');}}
 async expire(input){try{
  exact(input,['limit']);this.config();demand(Number.isInteger(input.limit)&&input.limit>=1&&input.limit<=1000);
  const result=await this.env.METRICS_DB.prepare(`DELETE FROM private_metrics WHERE record_id IN
   (SELECT record_id FROM private_metrics WHERE expires_at_ms<=${NOW_SQL} ORDER BY expires_at_ms,record_id LIMIT ?)`).bind(input.limit).run();
  return {schemaVersion:1,removed:Number(result.meta.changes)};
 }catch{throw Error('metrics_unavailable');}}
}
