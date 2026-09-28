import {DatabaseSync} from 'node:sqlite';
import {readFileSync} from 'node:fs';
import {PaymentExceptionService} from '../src/service.mjs';
import {NOW_SQL,rpc} from '../src/policy.mjs';
import gateway from '../../operator-api/src/index.mjs';
export const NOW=Date.UTC(2026,8,28,9,0,0);
export const ACCOUNT='a'.repeat(32), AUD='b'.repeat(64);
export const SUBJECTS={maker:'10000000-0000-4000-8000-000000000001',checker:'10000000-0000-4000-8000-000000000002',reader:'10000000-0000-4000-8000-000000000003',other:'10000000-0000-4000-8000-000000000004'};
export class CaseDb {
 constructor(path=':memory:',initialize=true) {
  this.sql=new DatabaseSync(path);this.time=NOW;this.sql.function('test_now_ms',()=>this.time);
  this.sql.exec('PRAGMA foreign_keys=ON; PRAGMA busy_timeout=10000;');
  if(initialize)this.sql.exec(readFileSync(new URL('../migrations/0001_case_workflow.sql',import.meta.url),'utf8').replaceAll(NOW_SQL,'test_now_ms()'));
  this.beforeRun=null;this.afterRun=null;this.failRun=false;this.loseRun=false;this.sessions=[];
 }
 withSession(mode){if(mode!=='first-primary')throw Error('wrong session');this.sessions.push(mode);return this;}
 prepare(raw) {
  const db=this,sql=raw.replaceAll(NOW_SQL,'test_now_ms()');
  return {sql,args:[],bind(...args){return {...this,args};},
    async first(){return db.sql.prepare(sql).get(...this.args)??null;},
    async all(){return {results:db.sql.prepare(sql).all(...this.args)};},
    async run(){
      if(db.beforeRun){const f=db.beforeRun;db.beforeRun=null;await f();}
      if(db.failRun){db.failRun=false;throw Error('SYNTHETIC-SENSITIVE-FAILURE');}
      const r=db.sql.prepare(sql).run(...this.args);
      if(db.afterRun){const f=db.afterRun;db.afterRun=null;await f();}
      if(db.loseRun){db.loseRun=false;throw Error('SYNTHETIC-COMMIT-RESPONSE-LOSS');}
      return {success:true,meta:{changes:Number(r.changes)}};
    }};
 }
 close(){this.sql.close();}
}
export function fixture(t,path=':memory:') {
 const db=new CaseDb(path);t?.after(()=>db.close());
 db.sql.prepare('UPDATE px_settings SET enabled=1,account_id=?,audience=?,environment=?').run(ACCOUNT,AUD,'isolated-staging');
 for(const clubId of [6,24,26,44,1001])db.sql.prepare('INSERT INTO px_clubs VALUES(?,1)').run(clubId);
 for(const [name,subject] of Object.entries(SUBJECTS)){
  db.sql.prepare('INSERT INTO px_operators VALUES(?,?,?,1,?)').run(subject,ACCOUNT,AUD,NOW+86400000);
  db.sql.prepare('INSERT INTO px_grants VALUES(?,?,?,1)').run(subject,name==='other'?26:24,name==='other'?'maker':name);
 }
 const env={PAYMENT_CASES_ENABLED:'true',PAYMENT_CASES_ENVIRONMENT:'isolated-staging',PAYMENT_CASE_DB:db};
 const service=new PaymentExceptionService(env);
 const identity=(who='maker')=>({accountId:ACCOUNT,audience:AUD,subject:SUBJECTS[who]});
 const command=(patch={})=>({identity:identity(),clubId:24,caseId:crypto.randomUUID(),operationId:crypto.randomUUID(),expectedRevision:0,action:'open',
  detail:{reasonCode:'support_request',evidenceDigest:null,category:'ambiguous',orderId:crypto.randomUUID(),evidenceId:null},...patch});
 const open=async(patch={})=>{const input=command(patch);return {input,result:await service.command(input)};};
 const transition=async(caseId,action,who='maker',patch={})=>{
  const current=await service.get({identity:identity(who),clubId:24,caseId});
  const input=command({identity:identity(who),caseId,expectedRevision:current.revision,action,
   detail:{reasonCode:'review_complete',evidenceDigest:'d'.repeat(64),...(action==='propose'?{disposition:'refer_reconciliation'}:{})},...patch});
  return {input,result:await service.command(input)};
 };
 const httpEnv={...env,OPERATOR_API_ENABLED:'true',OPERATOR_CASES_ENABLED:'true',OPERATOR_API_ORIGIN:'https://operator.example.invalid',ACCESS_ACCOUNT_ID:ACCOUNT,ACCESS_AUD:AUD,
  PAYMENT_EXCEPTION_CASES:Object.fromEntries(['access','operation','get','list','history','command'].map(m=>[m,input=>rpc(()=>service[m](input))]))};
 const context=(who='maker')=>({access:{aud:AUD,getIdentity:async()=>({account_id:ACCOUNT,user_uuid:SUBJECTS[who]})}});
 const call=async(path='',options={})=>{
  const write=options.body!==undefined;
  const headers={...(write?{'content-type':'application/json','origin':httpEnv.OPERATOR_API_ORIGIN,'x-africlub-action':'payment-case-review','idempotency-key':crypto.randomUUID()}:{}),...options.headers};
  const req=new Request(options.url??httpEnv.OPERATOR_API_ORIGIN+'/v1/admin/clubs/24/payment-exceptions'+path,
   {method:options.method??(write?'POST':'GET'),headers,...(write?{body:typeof options.body==='string'?options.body:JSON.stringify(options.body)}:{})});
  return gateway.fetch(req,{...httpEnv,...options.env},options.context??context(options.who));
 };
 const count=()=>Number(db.sql.prepare('SELECT count(*) n FROM px_events').get().n);
 return {db,env,service,identity,command,open,transition,httpEnv,context,call,count};
}
export const rejects=(fn,code)=>import('node:assert/strict').then(({default:assert})=>assert.rejects(fn,e=>e.code===code));
