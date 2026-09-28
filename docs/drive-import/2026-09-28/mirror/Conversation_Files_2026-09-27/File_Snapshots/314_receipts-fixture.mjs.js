import {fixture as baseFixture} from './fixture.mjs';
import {readFileSync} from 'node:fs';
import {StatusAwareDeliveryService} from '../src/status-aware-service.mjs';
import {ReceiptStore} from '../src/receipt-store.mjs';
import {handleReceipt} from '../src/receipt-http.mjs';
export const ACCOUNT='100000000000099';
export function receiptFixture(t) {
 const f=baseFixture();t?.after(()=>f.close());
 f.db.sql.exec(readFileSync(new URL('../migrations/0002_delivery_status_receipts.sql',import.meta.url),'utf8'));
 let failBatchAt=-1,loseBatch=false;
 const oldPrepare=f.db.prepare.bind(f.db);
 f.db.prepare=sql=>{const st=oldPrepare(sql);st.all=async function(){return {results:f.db.sql.prepare(sql).all(...this.args)};};return st;};
 f.db.batch=async statements=>{const out=[];f.db.sql.exec('BEGIN IMMEDIATE');try{
  for(let i=0;i<statements.length;i++){if(i===failBatchAt)throw Error('injected batch failure');out.push(await statements[i].run());}
  f.db.sql.exec('COMMIT');
 }catch(e){f.db.sql.exec('ROLLBACK');throw e;}
 if(loseBatch){loseBatch=false;throw Error('response lost after commit');}return out;};
 const env=Object.assign(f.env,{RECEIPT_BINDING_ENABLED:'true',RECEIPT_WEBHOOK_ENABLED:'true',RECEIPT_READ_ENABLED:'true',RECEIPT_RECONCILE_ENABLED:'true',
  RECEIPT_KEY_VERSION:'1',RECEIPT_HMAC_KEY:'b3'.repeat(32),RECEIPT_ORIGIN:'https://callback.africlub.example',
  RECEIPT_ROUTES_JSON:JSON.stringify([{clubId:24,businessAccountId:ACCOUNT,phoneNumberId:f.route.phoneNumberId}]),
  WA_WEBHOOK_APP_SECRET:'synthetic-meta-app-secret-for-tests-only',WA_WEBHOOK_VERIFY_TOKEN:'synthetic_verification_token_tests_only',
  RECEIPT_EDGE_LIMIT:{async limit(){return {success:true};}}});
 const options={clock:f.now,fetcher:f.fetcher};
 const tracked=new StatusAwareDeliveryService(env,options),store=new ReceiptStore(env,{clock:f.now});
 const count=table=>f.db.sql.prepare(`SELECT COUNT(*) AS n FROM ${table}`).get().n;
 function payload(status='delivered',overrides={}) {
  return {object:'whatsapp_business_account',entry:[{id:ACCOUNT,changes:[{field:'messages',value:{messaging_product:'whatsapp',
   metadata:{display_phone_number:'do-not-persist-this',phone_number_id:f.route.phoneNumberId},
   statuses:[{id:'wamid.SYNTHETIC',recipient_id:f.input.phone.slice(1),timestamp:String(Math.floor(f.now()/1000)),status,...overrides}]}}]}]};
 }
 async function signed(body=payload(),headers={}) {
  const bytes=typeof body==='string'?new TextEncoder().encode(body):body instanceof Uint8Array?body:new TextEncoder().encode(JSON.stringify(body));
  const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(env.WA_WEBHOOK_APP_SECRET),{name:'HMAC',hash:'SHA-256'},false,['sign']);
  const sig=[...new Uint8Array(await crypto.subtle.sign('HMAC',key,bytes))].map(n=>n.toString(16).padStart(2,'0')).join('');
  return new Request(env.RECEIPT_ORIGIN+'/webhooks/whatsapp/auth-delivery',{method:'POST',headers:{'content-type':'application/json','x-hub-signature-256':'sha256='+sig,...headers},body:bytes});
 }
 const send=async(body,headers)=>handleReceipt(await signed(body,headers),env,{clock:f.now});
 return {...f,tracked,store,count,payload,signed,send,failBatchAt(n){failBatchAt=n;},loseBatch(){loseBatch=true;},
  status:()=>store.read({clubId:f.input.clubId,challengeId:f.input.challengeId})};
}
