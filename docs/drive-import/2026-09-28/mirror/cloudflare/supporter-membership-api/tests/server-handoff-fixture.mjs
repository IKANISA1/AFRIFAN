import {fixture,ids,NOW} from './fixture.mjs';
import {installHandoff} from '../../payment-allocation/tests/handoff-fixture.mjs';
import {createHandoffGateway} from '../src/handoff-index.mjs';
import {reviewHash} from '../../payment-allocation/src/handoff-service.mjs';
export {ids,NOW};
export async function serverFixture(t,{rpcMs=5000,bodyMs=1500}={}){
 const f=await fixture(t);const service=installHandoff(f.payment);let mono=0;
 f.env.SERVER_HANDOFF_API_ENABLED='true';
 f.env.HANDOFF_RESERVER={async reserve(v){f.calls.push('reserve');return service.reserve.reserve(v);}};
 f.env.HANDOFF_RECOVERY={async active(v){f.calls.push('recover');return service.recovery.active(v);}};
 const gateway=createHandoffGateway({clock:()=>f.payment.db.time,rpcMs,bodyMs,monotonicNow:()=>mono});
 const transport=async(url,init)=>{const req=new Request(url,{...init,headers:{...init.headers,'cf-connecting-ip':'203.0.113.10'}});Object.defineProperty(req,'cf',{value:{colo:'TEST'}});return gateway.fetch(req,f.env);};
 const prepared=await f.prepare(),snapshot=JSON.parse(f.payment.db.sql.prepare('SELECT snapshot_json FROM pa_checkout_order_details WHERE order_id=?').get(prepared.orderId).snapshot_json);
 const digest=await reviewHash(snapshot);
 const call=async({read=false,method=read?'GET':'POST',key=crypto.randomUUID(),body={reviewHash:digest},headers={},club=24,id=prepared.orderId,cf=true,access=f.tokens.accessToken,raw=false,suffix}={})=>{
  const path=suffix??(read?'membership/handoffs':`membership/checkouts/${id}/handoff`);
  const req=new Request(`${f.env.NATIVE_ORIGIN}/v1/supporter/clubs/${club}/${path}`,{method,headers:{'authorization':`Bearer ${access}`,'x-africlub-client':'native-v1','x-africlub-session':access.split('.')[0],'cf-connecting-ip':'203.0.113.10',...(method==='POST'?{'idempotency-key':key,'content-type':'application/json'}:{}),...headers},...(!['GET','HEAD'].includes(method)?{body:raw?body:JSON.stringify(body)}:{})});
  if(cf)Object.defineProperty(req,'cf',{value:{colo:'TEST'}});return gateway.fetch(req,f.env);
 };
 return {...f,service,gateway,transport,prepared,snapshot,digest,call,advanceMono(ms){mono+=ms;},mono:()=>mono};
}
// Test-only memory store. The production composition still requires the native encrypted store/lock.
export function memoryStore(){const data=new Map(),tails=new Map();let writes=0;return {data,writes:()=>writes,
 async runExclusive(scope,work){const before=tails.get(scope)??Promise.resolve();let release;tails.set(scope,new Promise(r=>release=r));await before;try{return await work();}finally{release();}},
 async load(scope){return data.get(scope)??null;},async compareAndSet(scope,expected,value){if((data.get(scope)??null)!==expected)return false;data.set(scope,value);writes++;return true;}};}
