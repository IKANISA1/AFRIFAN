/** Explicit isolated-staging queue policy. No implicit legacy dispatch fallback. */
export class OtpDispatchError extends Error {
  constructor(code) { super(code); this.name='OtpDispatchError'; this.code=code; }
}
export function deliveryDemand(ok,code='invalid_delivery_policy') {
  if(!ok) throw new OtpDispatchError(code);
}
const fields=['version','clubIds','batchLimit','perClubLimit','rpcTimeoutMs','leaseMs','retryDelayMs','runBudgetMs'];
export function queuePolicy(env) {
  deliveryDemand(env.AUTH_DELIVERY_MODE==='private-deduplicated','private_delivery_required');
  let p;try {
    deliveryDemand(typeof env.AUTH_DELIVERY_POLICY_JSON==='string'&&env.AUTH_DELIVERY_POLICY_JSON.length<=4096);
    p=JSON.parse(env.AUTH_DELIVERY_POLICY_JSON);
  }catch { throw new OtpDispatchError('invalid_delivery_policy'); }
  deliveryDemand(p&&typeof p==='object'&&!Array.isArray(p)&&Object.keys(p).length===fields.length&&fields.every(k=>Object.hasOwn(p,k)));
  deliveryDemand(p.version===1&&Array.isArray(p.clubIds)&&p.clubIds.length>0&&p.clubIds.length<=32);
  deliveryDemand(p.clubIds.every(x=>Number.isSafeInteger(x)&&x>0&&x<=2147483647)&&new Set(p.clubIds).size===p.clubIds.length);
  for(const k of fields.filter(x=>!['version','clubIds'].includes(x)))deliveryDemand(Number.isSafeInteger(p[k]));
  deliveryDemand(p.batchLimit>=1&&p.batchLimit<=20&&p.perClubLimit>=1&&p.perClubLimit<=p.batchLimit);
  deliveryDemand(p.rpcTimeoutMs>=1000&&p.rpcTimeoutMs<=10000&&p.leaseMs>=p.rpcTimeoutMs+15000&&p.leaseMs<=120000);
  deliveryDemand(p.retryDelayMs>=30000&&p.retryDelayMs<=300000&&p.runBudgetMs>=p.rpcTimeoutMs&&p.runBudgetMs<=25000);
  return Object.freeze({...p,clubIds:Object.freeze([...p.clubIds].sort((a,b)=>a-b))});
}
export async function boundedDelivery(work,ms) {
  let timer;
  try {return await Promise.race([Promise.resolve().then(work),new Promise((_,reject)=>{
    timer=setTimeout(()=>reject(new OtpDispatchError('private_delivery_timeout')),ms);
  })]);}finally {clearTimeout(timer);}
}

export function deliveryPolicy(env) {
  const policy = queuePolicy(env);
  deliveryDemand(env.OTP_DELIVERY && typeof env.OTP_DELIVERY.deliverWithReceipt === 'function', 'private_delivery_unavailable');
  return policy;
}
