import {fixture as identityFixture,PHONE,PHONE2} from '../../../supporter-auth/tests/support/fixture.mjs';
import {BrowserSessionService} from '../../../supporter-auth/src/browser-session-service.mjs';
import {publicError} from '../../../supporter-auth/src/errors.mjs';
import {createBrowserGateway} from '../../src/index.mjs';
import {SESSION_COOKIE,BOOTSTRAP_COOKIE} from '../../src/http.mjs';
export {PHONE,PHONE2};
export const ORIGIN='https://browser.example.invalid';
export function fixture(t){
 const f=identityFixture(t);
 Object.assign(f.env,{AUTH_BROWSER_ENABLED:'true',BROWSER_ORIGIN:ORIGIN,BROWSER_CLUB_ID:'24',
  BROWSER_API_ENABLED:'true',BROWSER_MEMBERSHIP_ENABLED:'true',BROWSER_CHECKOUT_ENABLED:'false',
  BROWSER_RATE_KEY:'d'.repeat(64),EDGE_LIMIT:{async limit(){return {success:true};}},SUBJECT_LIMIT:{async limit(){return {success:true};}}});
 f.db.sqlite.exec(`UPDATE auth_browser_control SET enabled=1;INSERT INTO auth_browser_origins(origin,club_id,enabled) VALUES('${ORIGIN}',24,1)`);
 f.browser=()=>new BrowserSessionService(f.env,{clock:()=>f.clock.now});
 f.bind=()=>{const b={};for(const method of ['start','bootstrap','challenge','verify','current','rotate','logout']){
  b[method]=async input=>{try{return {ok:true,value:await f.browser()[method==='bootstrap'?'bootstrapView':method](input)};}
   catch(e){const er=publicError(e);return {ok:false,error:er.code,status:er.status};}};}return b;};
 f.env.BROWSER_IDENTITY=f.bind();
 f.start=async()=>f.browser().start();
 f.challenge=async(b,{phone=PHONE,key=f.key()}={})=>{
  const result=await f.browser().challenge({bootstrapCookie:b.bootstrapCookie,csrfToken:b.view.csrfToken,requestId:key,
   ipKey:'c'.repeat(64),input:{phone}});
  const r=f.sql('SELECT * FROM auth_challenges WHERE challenge_id=?',result.challengeId)[0];
  const {code}=await f.service.vault.open(r.delivery_cipher,`challenge:${result.challengeId}`);
  return {...result,code,key,phone};
 };
 f.verify=async(b,c,{key=f.key(),code=c.code,sessionCookie=null}={})=>{
  const args={bootstrapCookie:b.bootstrapCookie,csrfToken:b.view.csrfToken,requestId:key,
   input:{challengeId:c.challengeId,code},sessionCookie};
  const result=await f.browser().verify(args);return {...result,args};
 };
 f.browserLogin=async()=>{const b=await f.start(),c=await f.challenge(b),s=await f.verify(b,c);return {b,c,s};};
 f.http=async(path,{method='GET',json,raw,headers={},sessionCookie,bootstrapCookie,key,csrf,sessionId,cf=true,url=ORIGIN+path,rpcMs=8000}={})=>{
  const h={'x-africlub-browser-intent':'browser-v1','sec-fetch-site':'same-origin','cf-connecting-ip':'203.0.113.20',
   ...(method==='POST'?{origin:ORIGIN,'content-type':'application/json'}:{}),
   ...(key?{'idempotency-key':key}:{}),...(csrf?{'x-africlub-csrf':csrf}:{}),
   ...(sessionId?{'x-africlub-browser-session':sessionId}:{}),
   ...((sessionCookie||bootstrapCookie)?{cookie:[sessionCookie&&`${SESSION_COOKIE}=${sessionCookie}`,bootstrapCookie&&`${BOOTSTRAP_COOKIE}=${bootstrapCookie}`].filter(Boolean).join('; ')}:{}),...headers};
  for(const k of Object.keys(h))if(h[k]===null)delete h[k];
  const req=new Request(url,{method,headers:h,...(method==='POST'?{body:raw??JSON.stringify(json??{})}:{})});
  if(cf)Object.defineProperty(req,'cf',{value:{colo:'TEST'}});
  return createBrowserGateway({clock:()=>f.clock.now,rpcMs}).fetch(req,f.env);
 };
 f.state=()=>Object.fromEntries(['auth_browser_sessions','auth_browser_rotations','auth_audit'].map(n=>[n,JSON.stringify(f.sql(`SELECT * FROM ${n}`))]));
 return f;
}
export const creating=ss=>ss.some(s=>s.sql.includes('INSERT INTO auth_browser_sessions('));
export const rotating=ss=>ss.some(s=>s.sql.includes('SET cookie_hash='));
export const loggingOut=ss=>ss.some(s=>s.sql.includes('SET revoked_ms='));

export async function withPayments(t){
 const {checkoutFixture,ids}=await import('../../../payment-allocation/tests/checkout-fixture.mjs');
 const f=fixture(t),payment=checkoutFixture();t.after(()=>payment.close());f.clock.now=payment.db.time;
 await f.account({id:ids.user});
 f.env.BROWSER_CHECKOUT_ENABLED='true';
 const calls=[];
 f.env.CHECKOUT={
  async prepare(v){calls.push('prepare');return payment.checkout.prepare(v);},
  async lookupPreparedOperation(v){calls.push('lookup');return payment.checkout.lookupPreparedOperation(v);}
 };
 f.env.CHECKOUT_READER={
async history(v){calls.push('history');return payment.checkoutReader.history(v);},async historicalReceipt(v){calls.push('historicalReceipt');return payment.checkoutReader.historicalReceipt(v);},  async offers(v){calls.push('offers');return payment.checkoutReader.offers(v);},
  async membershipStatus(v){calls.push('membershipStatus');return payment.checkoutReader.membershipStatus(v);},
  async read(v){calls.push('read');return payment.checkoutReader.read(v);}
 };
 f.env.PAYMENT_RECEIPTS={async readReceipt(v){calls.push('receipt');return payment.reader.readReceipt(v);}};
 return {...f,payment,calls,ids,advance(ms){payment.advance(ms);f.clock.now=payment.db.time;},
  async allocate(orderId){const o=payment.db.sql.prepare('SELECT * FROM pa_orders WHERE order_id=?').get(orderId);
   const e=payment.evidence(o);e.parsed.rawId=e.raw.id;await payment.ingestion.ingest(e);
   return payment.allocator.allocate(payment.allocation(e,o));}};
}
