import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {PaymentAllocationService} from '../src/service.mjs';
import {AllocationOutbox} from '../src/outbox.mjs';
import {NOW_SQL} from '../src/policy.mjs';
export const NOW=Date.UTC(2026,8,26,14,0,0,123);
export const ids={ingest:'10000000-0000-4000-8000-000000000001',allocate:'10000000-0000-4000-8000-000000000002',read:'10000000-0000-4000-8000-000000000003',outbox:'10000000-0000-4000-8000-000000000004',other:'10000000-0000-4000-8000-000000000005',user:'20000000-0000-4000-8000-000000000001',partner:'30000000-0000-4000-8000-000000000001',receiver:'40000000-0000-4000-8000-000000000001'};
export class Db {
 constructor(){this.time=NOW;this.sql=new DatabaseSync(':memory:');this.sql.function('test_now_ms',()=>this.time);
  this.sql.exec(readFileSync(new URL('../migrations/0001_payment_allocation.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
  this.beforeStatement=null;this.beforeBatch=null;this.afterCommit=null;this.failAt=-1;this.loseBatch=false;this.loseRun=false;this.beforeRun=null;this.sessions=[];}
 withSession(mode){if(mode!=='first-primary')throw Error('not primary');this.sessions.push(mode);return this;}
 prepare(raw){const db=this,sql=raw.replaceAll(NOW_SQL,'test_now_ms()');return {sql,args:[],bind(...args){return {...this,args};},
  async first(){return db.sql.prepare(sql).get(...this.args)??null;},
  async all(){return {results:db.sql.prepare(sql).all(...this.args)};},
  async run(){if(db.beforeRun){const f=db.beforeRun;db.beforeRun=null;f();}const r=db.sql.prepare(sql).run(...this.args);
   if(db.loseRun){db.loseRun=false;throw Error('lost acknowledgement');}return {success:true,meta:{changes:Number(r.changes)}};}};}
 async batch(statements){if(this.beforeBatch){const f=this.beforeBatch;this.beforeBatch=null;f();}this.sql.exec('BEGIN IMMEDIATE');const results=[];
  try{for(let i=0;i<statements.length;i++){if(this.beforeStatement)this.beforeStatement(i);if(this.failAt===i){this.failAt=-1;throw Error('injected batch failure');}
   const s=statements[i],r=this.sql.prepare(s.sql).run(...s.args);results.push({success:true,meta:{changes:Number(r.changes)}});}
   this.sql.exec('COMMIT');
  }catch(error){this.sql.exec('ROLLBACK');throw error;}
  if(this.afterCommit){const f=this.afterCommit;this.afterCommit=null;f();}
  if(this.loseBatch){this.loseBatch=false;throw Error('reply lost after commit');}return results;}
 close(){this.sql.close();}
}
export function fixture(){
 const db=new Db(); const env={PAYMENT_ALLOCATION_ENABLED:'true',ALLOCATION_ENVIRONMENT:'isolated-staging',ALLOCATION_DB:db};
 db.sql.exec(`UPDATE pa_settings SET writer_mode='isolated-staging',source_reconciled=1,historical_claims_verified=1,evidence_ref='SYNTHETIC-NOT-APPROVAL';`);
 for(const c of [24,25])db.sql.prepare('INSERT INTO pa_clubs(club_id,club_slug,country,currency,enabled) VALUES(?,?,?,?,1)').run(c,`synthetic-club-${c}`,'RW','RWF');
 for(const [cap,id] of Object.entries(ids).filter(([x])=>['ingest','allocate','read','outbox','other'].includes(x))){
  db.sql.prepare('INSERT INTO pa_principals VALUES(?,1,1,?)').run(id,NOW+7*86400000);
  for(const c of [24,25]) db.sql.prepare('INSERT INTO pa_grants VALUES(?,?,?,1,1)').run(id,c,cap==='other'?'outbox':cap);
 }
 for(const c of [24,25]) db.sql.prepare('INSERT INTO pa_subjects(user_id,club_id,enabled) VALUES(?,?,1)').run(ids.user,c);
 db.sql.prepare('INSERT INTO pa_receivers(receiver_id,club_id,partner_id,provider,country,currency,recipient,active) VALUES(?,24,?,?,?,?,?,1)')
  .run(ids.receiver,ids.partner,'mtn_rwanda','RW','RWF','123456');
 const createOrder=(patch={})=>{
  const row={order_id:crypto.randomUUID(),source_intent_id:crypto.randomUUID(),kind:'membership',user_id:ids.user,club_id:24,
   partner_id:ids.partner,receiver_id:ids.receiver,amount:10000,currency:'RWF',country:'RW',provider:'mtn_rwanda',recipient:'123456',
   tier:'gold',initiative_id:null,checkout_reference:`MEM-${crypto.randomUUID()}`,expires_at_ms:db.time+86400000,
   created_at_ms:db.time-1000,state:'pending',source_sha256:'a1'.repeat(32),...patch};
  const keys=Object.keys(row);db.sql.prepare(`INSERT INTO pa_orders(${keys.join(',')}) VALUES(${keys.map(()=>'?').join(',')})`).run(...Object.values(row));return row;
 };
 const order=createOrder();
 const evidence=(o=order,patch={})=>({requestId:crypto.randomUUID(),raw:{id:crypto.randomUUID(),userId:o.user_id,clubId:o.club_id,country:o.country,
   provider:o.provider,sha256:'b2'.repeat(32),receivedAt:db.time,isMock:false},parsed:{id:crypto.randomUUID(),rawId:'',userId:o.user_id,clubId:o.club_id,
   country:o.country,providerReference:`TX-${crypto.randomUUID()}`,amount:o.amount,currency:o.currency,recipient:o.recipient,
   direction:'debit',parseStatus:'parsed',isMock:false,transactionAt:db.time},attestationRef:'SYNTHETIC-RECONCILIATION',...patch});
 const input=evidence();input.parsed.rawId=input.raw.id;
 const ingestion=new PaymentAllocationService(env,ids.ingest),allocator=new PaymentAllocationService(env,ids.allocate),reader=new PaymentAllocationService(env,ids.read),outbox=new AllocationOutbox(env,ids.outbox);
 const allocation=(e=input,o=order)=>({requestId:crypto.randomUUID(),clubId:o.club_id,orderId:o.order_id,evidenceId:e.parsed.id});
 const count=table=>Number(db.sql.prepare(`SELECT count(*) n FROM ${table}`).get().n);
 const membership=(patch={})=>{const row={membership_id:crypto.randomUUID(),user_id:ids.user,club_id:24,partner_id:ids.partner,tier:'gold',status:'active',payment_status:'verified',points:321,membership_number:`MEM-${crypto.randomUUID()}`,member_code:'876543',renewed_at_ms:db.time-10000,expires_at_ms:db.time+86400000,...patch};
  const keys=Object.keys(row);db.sql.prepare(`INSERT INTO pa_memberships(${keys.join(',')}) VALUES(${keys.map(()=>'?').join(',')})`).run(...Object.values(row));return row;};
 return {db,env,order,input,ingestion,allocator,reader,outbox,createOrder,evidence,allocation,count,membership,close(){db.close();},advance(ms){db.time+=ms;}};
}
export async function ready(f){await f.ingestion.ingest(f.input);return f.allocation();}
