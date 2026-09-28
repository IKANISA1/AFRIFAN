import {fixture as authFixture} from '../../supporter-auth/tests/support/fixture.mjs';
import {checkoutFixture,ids,NOW} from '../../payment-allocation/tests/checkout-fixture.mjs';
import {createGateway} from '../src/index.mjs';
import {publicError} from '../../supporter-auth/src/errors.mjs';
export {ids,NOW};
export async function fixture(t,options={}) {
  const payment=checkoutFixture();t.after(()=>payment.close());
  const auth=authFixture(t);auth.clock.now=payment.db.time;
  await auth.account({id:ids.user});const {tokens}=await auth.login();const calls=[];
  const env={
    MEMBERSHIP_API_ENABLED:'true',MEMBERSHIP_ENVIRONMENT:'isolated-staging',NATIVE_ORIGIN:'https://membership.example.invalid',
    CLUB_ROUTES_JSON:JSON.stringify([{clubId:24,clubSlug:'rayon_sports_rw'},{clubId:25,clubSlug:'synthetic-other'}]),GATEWAY_RATE_KEY:'1a'.repeat(32),
    IDENTITY:{async current(v){calls.push('identity');try {return {ok:true,value:await auth.service.current(v.clubId,v.accessToken)};}catch(error){const e=publicError(error);return {ok:false,error:e.code,status:e.status};}}},
    CHECKOUT:{async prepare(v){calls.push('prepare');return payment.checkout.prepare(v);}},
    CHECKOUT_READER:{async read(v){calls.push('read');return payment.checkoutReader.read(v);}},
    PAYMENT_RECEIPTS:{async readReceipt(v){calls.push('receipt');return payment.reader.readReceipt(v);}},
    EDGE_LIMIT:{async limit(){calls.push('edge');return {success:true};}},
    SUBJECT_LIMIT:{async limit(){calls.push('subject');return {success:true};}}
  };
  const gateway=createGateway({clock:()=>payment.db.time,...options});
  const call=async(suffix='membership/checkouts',options={})=>{
    const post=suffix==='membership/checkouts';
    const {method=post?'POST':'GET',body=post?{tier:'gold'}:undefined,key=post?crypto.randomUUID():undefined,
      token=tokens.accessToken,clubId=24,origin=env.NATIVE_ORIGIN,headers={},raw=false,cf=true}=options;
    const req=new Request(`${origin}/v1/supporter/clubs/${clubId}/${suffix}`,{method,
      headers:{'x-africlub-client':'native-v1','cf-connecting-ip':'203.0.113.10',authorization:`Bearer ${token}`,
        ...(suffix==='session'?{}:{'x-africlub-session':token.split('.')[0]}),...(key?{'idempotency-key':key}:{}),
        ...(['GET','HEAD'].includes(method)?{}:{'content-type':'application/json'}),...headers},
      ...(!['GET','HEAD'].includes(method)&&body!==undefined?{body:raw?body:JSON.stringify(body)}:{})});
    if(cf)Object.defineProperty(req,'cf',{value:{colo:'TEST'}});
    return gateway.fetch(req,env);
  };
  const prepare=async()=>{const r=await call();if(r.status!==200)throw Error(`fixture prepare ${r.status}: ${await r.text()}`);return r.json();};
  const allocate=async(orderId)=>{const order=payment.db.sql.prepare('SELECT * FROM pa_orders WHERE order_id=?').get(orderId);
    const evidence=payment.evidence(order);evidence.parsed.rawId=evidence.raw.id;await payment.ingestion.ingest(evidence);
    return payment.allocator.allocate(payment.allocation(evidence,order));};
  return {env,gateway,auth,payment,tokens,calls,call,prepare,allocate,
    advance(ms){payment.advance(ms);auth.clock.now=payment.db.time;},
    async attacker(){const userId=crypto.randomUUID();await auth.account({id:userId,phone:'+250700000002'});
      payment.db.sql.prepare('INSERT INTO pa_subjects(user_id,club_id,enabled) VALUES(?,24,1)').run(userId);
      return (await auth.login({phone:'+250700000002'})).tokens;}
  };
}
export async function json(r,status=200){const {default:assert}=await import('node:assert/strict');const body=await r.json();assert.equal(r.status,status,JSON.stringify(body));return body;}
