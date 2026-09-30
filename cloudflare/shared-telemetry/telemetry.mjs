/** Private aggregate telemetry. No transport objects or caller identifiers enter the schema. */
const SERVICES = new Set(['supporter_auth','supporter_browser','supporter_membership','auth_code_delivery','allocation_delivery',
  'payment_allocation','payment_exceptions','operator_api','rayon_public','frontend_router','receipt_delivery']);
const OPERATIONS = new Set(['otp_challenge','otp_verify','session_read','session_refresh','session_revoke','credential_delivery',
  'delivery_receipt','delivery_drain','delivery_inspection','delivery_prepare','delivery_confirm','membership_read',
  'membership_history','checkout_create','checkout_confirm','payment_allocate','case_read','case_command','publication_read',
  'publication_command','route','queue_health','session_start','session_bootstrap','account_deletion','identity_maintenance','browser_secret_expiry',
  'payment_ingest','payment_receipt','delivery_claim','delivery_acknowledge','delivery_read','delivery_accept','delivery_redrive','checkout_read','checkout_offers','handoff_reserve','handoff_release','handoff_claim','handoff_read']);
const MUTATIONS=new Set(['otp_challenge','otp_verify','session_refresh','session_revoke','credential_delivery','delivery_receipt','delivery_drain',
 'delivery_prepare','delivery_confirm','checkout_create','checkout_confirm','payment_allocate','payment_ingest','case_command','publication_command',
 'session_start','session_bootstrap','account_deletion','identity_maintenance','browser_secret_expiry','delivery_claim','delivery_acknowledge','delivery_accept','delivery_redrive','handoff_reserve','handoff_release','handoff_claim']);
const OUTCOMES = new Set(['completed','rejected','unknown','unavailable','denied','no_work']);
const STATES = new Set(['pending','queued','leased','retry','dead','failed','accepted','delivered','reserved','unknown','rejected']);
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const MAX_TIME = 4102444800000; // Mechanical 2100 range bound, not a retention policy.
const object = x => x !== null && typeof x === 'object' && !Array.isArray(x) &&
  [Object.prototype, null].includes(Object.getPrototypeOf(x));
const int = (x, maximum) => Number.isSafeInteger(x) && x >= 0 && x <= maximum;
const exact = (x, keys) => object(x) && Object.keys(x).length === keys.length && keys.every(k => Object.hasOwn(x, k));
const boundedDuration = x => typeof x === 'number' && Number.isFinite(x) ? Math.min(3600000, Math.max(0, Math.round(x))) : null;

export function operationMetric(input) {
  if (!exact(input, ['service','operation','traceId','clubId','observedAt','durationMs','outcome']) ||
    !SERVICES.has(input.service) || !OPERATIONS.has(input.operation) || !OUTCOMES.has(input.outcome) ||
    typeof input.traceId !== 'string' || !UUID.test(input.traceId) || !int(input.observedAt, MAX_TIME) ||
    !(input.clubId === null || (int(input.clubId, 2147483647) && input.clubId > 0))) return null;
  return Object.freeze({schemaVersion:1,event:'service_operation',service:input.service,operation:input.operation,
    traceId:input.traceId,clubId:input.clubId,observedAt:input.observedAt,durationMs:boundedDuration(input.durationMs),outcome:input.outcome});
}

export function queueMetric(input) {
  if (!exact(input, ['service','clubId','observedAt','state','count','oldestAt','capped']) || !SERVICES.has(input.service) ||
    !int(input.clubId,2147483647) || input.clubId === 0 || !int(input.observedAt,MAX_TIME) || !STATES.has(input.state) ||
    !int(input.count,1000) || typeof input.capped !== 'boolean' ||
    !(input.oldestAt === null || (int(input.oldestAt,input.observedAt)))) return null;
  return Object.freeze({schemaVersion:1,event:'service_queue',service:input.service,clubId:input.clubId,
    observedAt:input.observedAt,state:input.state,count:input.count,capped:input.capped,
    oldestAgeMs:input.oldestAt === null ? null : Math.min(31536000000,input.observedAt-input.oldestAt)});
}

/** Retention is deliberately unset in distributed configuration. It must be selected by an accountable operator. */
export function telemetryConfiguration(env) {
  try {
  if (env?.PRIVATE_METRICS_ENABLED !== 'true') return null;
  const retentionMs = typeof env.PRIVATE_METRICS_RETENTION_MS === 'string' && /^[1-9][0-9]{0,10}$/.test(env.PRIVATE_METRICS_RETENTION_MS)
    ? Number(env.PRIVATE_METRICS_RETENTION_MS) : NaN;
  if (!int(retentionMs,31622400000) || retentionMs < 3600000 ||
    typeof env.PRIVATE_METRICS_POLICY_REF !== 'string' || !/^[A-Z][A-Z0-9_-]{3,63}$/.test(env.PRIVATE_METRICS_POLICY_REF) ||
    !env.PRIVATE_METRICS?.record || typeof env.PRIVATE_METRICS.record !== 'function') return null;
  return Object.freeze({retentionMs,policyRef:env.PRIVATE_METRICS_POLICY_REF});
  } catch {return null;}
}

export function normalizeMetric(metric) {
  if(!object(metric))return null;
  const copy=Object.fromEntries(Object.entries(metric));
  if(exact(copy,['schemaVersion','event','service','operation','traceId','clubId','observedAt','durationMs','outcome']) &&
    copy.schemaVersion===1 && copy.event==='service_operation') {
    const {schemaVersion,event,...input}=copy;return operationMetric(input);
  }
  if(exact(copy,['schemaVersion','event','service','clubId','observedAt','state','count','capped','oldestAgeMs']) &&
    copy.schemaVersion===1 && copy.event==='service_queue' && SERVICES.has(copy.service) && int(copy.clubId,2147483647) &&
    copy.clubId>0 && int(copy.observedAt,MAX_TIME) && STATES.has(copy.state) && int(copy.count,1000) &&
    typeof copy.capped==='boolean' && (copy.oldestAgeMs===null || int(copy.oldestAgeMs,31536000000)))return Object.freeze(copy);
  return null;
}

/** One bounded attempt; sink rejection or a sink ignoring cancellation never delays the operation or triggers its retry. */
export async function emitMetric(env, metric, {deadlineMs=25}={}) {
  let timer;
  try {
    const config = telemetryConfiguration(env);
    if (!config || !int(deadlineMs,100) || deadlineMs === 0 || !object(metric)) return false;
    // Copy once before validation: no caller-owned mutable object or getter is passed to the sink.
    const value=normalizeMetric(metric);
    if(!value)return false;
    const attempted = Promise.resolve().then(()=>env.PRIVATE_METRICS.record({metric:value,...config}));
    return await Promise.race([attempted.then(()=>true,()=>false),new Promise(resolve=>{timer=setTimeout(()=>resolve(false),deadlineMs);})]);
  } catch {return false;} finally {clearTimeout(timer);}
}

export function emitMetricDetached(env,metric,ctx) {
  const promise=emitMetric(env,metric);
  try {if(typeof ctx?.waitUntil==='function')ctx.waitUntil(promise);} catch { /* Keep the operation's response independent. */ }
  // emitMetric always handles rejection; no console fallback and no raw request logging.
  return promise;
}

/** Generates a fresh trace locally. Inbound trace/headers and domain IDs are never accepted as trace authority. */
export async function traceOperation(env,{service,operation,clubId=null},work,{clock=Date.now,ctx,selectOutcome=()=> 'completed',mutating=MUTATIONS.has(operation)}={}) {
  const observe=()=>{try{return clock();}catch{return null;}};
  let traceId=null;try{traceId=crypto.randomUUID();}catch{ /* Telemetry cannot prevent the operation. */ }
  const start=observe();let outcome='unknown';
  try {const result=await work();try{const selected=selectOutcome(result);outcome=OUTCOMES.has(selected)?selected:'unknown';}catch{outcome='unknown';}return result;}
  catch(error){try{outcome=!mutating&&['permission_denied','unauthorized','forbidden'].includes(error?.code)?'denied':'unknown';}catch{outcome='unknown';}throw error;}
  finally {try{const end=observe();emitMetricDetached(env,operationMetric({service,operation,traceId,clubId,observedAt:end,durationMs:end-start,outcome}),ctx);}catch{ /* Preserve the original operation result. */ }}
}
