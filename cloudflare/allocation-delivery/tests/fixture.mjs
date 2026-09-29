import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {fixture as financialFixture,ready,ids,NOW} from '../../payment-allocation/tests/fixture.mjs';
import {DeliverySource} from '../src/source.mjs';
import {AllocationInbox} from '../src/inbox.mjs';
import {NOW_SQL} from '../src/policy.mjs';
export {ids,NOW};
export const CONSUMER='90000000-0000-4000-8000-000000000001';
export class TestD1 {
 constructor(path=':memory:'){
  this.sql=new DatabaseSync(path);this.time=NOW;this.sql.exec('PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000');
  this.sql.function('test_now_ms',()=>this.time);this.beforeRun=null;this.afterRun=null;this.loseRun=false;
 }
 withSession(mode){if(mode!=='first-primary')throw Error('bad session');return this;}
 prepare(raw){const db=this,sql=raw.replaceAll(NOW_SQL,'test_now_ms()');return {sql,args:[],bind(...args){return {...this,args};},
  async first(){return db.sql.prepare(sql).get(...this.args)??null;},async all(){return {results:db.sql.prepare(sql).all(...this.args)};},
  async run(){if(db.beforeRun){const f=db.beforeRun;db.beforeRun=null;f();}const r=db.sql.prepare(sql).run(...this.args);
   if(db.afterRun){const f=db.afterRun;db.afterRun=null;f();}if(db.loseRun){db.loseRun=false;throw Error('lost response');}
   return {success:true,meta:{changes:Number(r.changes)}};}};}
 async batch(statements){this.sql.exec('BEGIN IMMEDIATE');try{const result=[];for(const s of statements)result.push(await s.run());this.sql.exec('COMMIT');return result;}catch(e){this.sql.exec('ROLLBACK');throw e;}}
 close(){this.sql.close();}
}
export function sourceEnv(db){return {PAYMENT_ALLOCATION_ENABLED:'true',ALLOCATION_ENVIRONMENT:'isolated-staging',ALLOCATION_DB:db,ALLOCATION_DELIVERY_ENABLED:'true',DELIVERY_CONSUMER_ID:CONSUMER};}
export function inboxEnv(db){return {INBOX_ENABLED:'true',DELIVERY_ENVIRONMENT:'isolated-staging',DELIVERY_CONSUMER_ID:CONSUMER,INBOX_DB:db};}
export async function fixture(){
 const f=financialFixture();
 f.db.sql.exec(readFileSync(new URL('../../payment-allocation/migrations/0006_reliable_event_delivery.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
 for(const c of [24,25]){
  f.db.sql.prepare('INSERT INTO pa_delivery_control VALUES(?,1,?,3,10000,1000,?)').run(c,CONSUMER,'SYNTHETIC-NOT-APPROVAL');
  f.db.sql.prepare("INSERT INTO pa_delivery_grants VALUES(?,?,'dispatch',1)").run(ids.outbox,c);
  f.db.sql.prepare("INSERT INTO pa_delivery_grants VALUES(?,?,'review',1)").run(ids.other,c);
 }
 const db=new TestD1();db.sql.exec(readFileSync(new URL('../migrations/0001_operations_inbox.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
 db.sql.prepare("INSERT INTO adi_control VALUES(1,'africlub-allocation-inbox',1,?,?)").run(CONSUMER,'SYNTHETIC-NOT-APPROVAL');
 db.sql.exec('INSERT INTO adi_clubs VALUES(24,1),(25,1)');
 const env=sourceEnv(f.db),sinkEnv=inboxEnv(db),source=new DeliverySource(env,ids.outbox),review=new DeliverySource(env,ids.other),sink=new AllocationInbox(sinkEnv);
 const receipt=await f.allocator.allocate(await ready(f));
 return {...f,env,sinkEnv,source,review,sink,sinkDb:db,receipt,
  runner:{DELIVERY_DISPATCH_ENABLED:'true',DELIVERY_ENVIRONMENT:'isolated-staging',DELIVERY_CLUB_IDS:'[24,25]',DELIVERY_TIMEOUT_MS:'100',SOURCE:source,INBOX:sink},
  async addOrder(patch={}){const order=f.createOrder(patch),e=f.evidence(order);e.parsed.rawId=e.raw.id;await f.ingestion.ingest(e);return f.allocator.allocate(f.allocation(e,order));},
  advance(ms){f.advance(ms);db.time+=ms;},close(){f.close();db.close();}};
}
export async function claimed(f){const {event}=await f.source.take({clubId:24});const data=await f.source.readForDispatch({clubId:24,eventId:event.eventId,leaseId:event.leaseId});return {claim:event,...data};}
