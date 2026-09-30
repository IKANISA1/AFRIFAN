import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync, readdirSync } from 'node:fs';
import { IdentityService } from '../../src/identity-service.mjs';
import { randomSecret } from '../../src/crypto.mjs';
import gateway from '../../src/index.mjs';
/** Genuine SQLite, with an explicit controlled clock. NOT real D1/workerd. */
export class Database {
 constructor(clock,{file=':memory:',initialize=true}={}){this.sqlite=new DatabaseSync(file);this.sqlite.exec('PRAGMA foreign_keys=ON; PRAGMA busy_timeout=10000;');
  this.sqlite.function('unixepoch', {varargs:true}, (...args)=>{if(args.length!==1||args[0]!=='subsec')throw Error('test clock only supports subsec');return clock.now/1000;});
  if(initialize)for(const name of readdirSync(new URL('../../migrations/',import.meta.url)).filter(n=>n.endsWith('.sql')).sort()) this.sqlite.exec(readFileSync(new URL('../../migrations/'+name,import.meta.url),'utf8'));
  this.failAt=null;this.beforeBatch=null;this.afterCommitError=false;this.when=()=>true;this.lastBatch=[];}
 withSession(mode){if(mode!=='first-primary')throw Error('fixture only supports first-primary');return this;}
 prepare(sql){const db=this;return {sql,args:[],bind(...args){return {...this,args};},
  async first(){return db.sqlite.prepare(sql).get(...this.args)??null;},
  async all(){return {success:true,results:db.sqlite.prepare(sql).all(...this.args)};},
  async run(){const r=db.sqlite.prepare(sql).run(...this.args);return {success:true,meta:{changes:Number(r.changes)}};}};}
 async batch(statements){const active=this.when(statements);if(active&&this.beforeBatch){const f=this.beforeBatch;this.beforeBatch=null;await f();}
  this.lastBatch=statements.map(s=>s.sql);this.sqlite.exec('BEGIN IMMEDIATE');const results=[];
  try{for(let i=0;i<statements.length;i++){if(active&&this.failAt===i)throw Error('injected failure: sensitive SQL and token');const s=statements[i];
   const r=this.sqlite.prepare(s.sql).run(...s.args);results.push({success:true,meta:{changes:Number(r.changes)}});}
   this.sqlite.exec('COMMIT');}catch(error){this.sqlite.exec('ROLLBACK');throw error;}
  if(active&&this.afterCommitError){this.afterCommitError=false;throw Error('response lost after commit');}return results;}
}
export const PHONE='+250700000001',PHONE2='+250700000002',USER='11111111-1111-4111-8111-111111111111';
export function fixture(t){const clock={now:Date.now()};const db=new Database(clock);t.after(()=>db.sqlite.close());
 const env={AUTH_DELIVERY_MODE:'private-deduplicated',AUTH_DELIVERY_HEALTH_ENABLED:'true',OTP_DELIVERY:{async deliverWithReceipt(){throw Error('test requires explicit sender');}},
  AUTH_DELIVERY_POLICY_JSON:JSON.stringify({version:1,clubIds:[24,26],batchLimit:10,perClubLimit:10,rpcTimeoutMs:8000,leaseMs:30000,retryDelayMs:30000,runBudgetMs:25000}),
  AUTH_SERVICE_ENABLED:'true',AUTH_DELIVERY_ENABLED:'true',AUTH_KEY_VERSION:'1',AUTH_HMAC_KEY:'a'.repeat(64),AUTH_ENCRYPTION_KEY:'b'.repeat(64),AUTH_DB:db,
  AUTH_ISSUANCE_POLICY_JSON:JSON.stringify({version:1,globalPerMinute:20,perIpPerMinute:10,phonePer15Minutes:3,clubs:{24:10,26:10}}),
  AUTH_ORIGIN:'https://identity.example.invalid',AUTH_EDGE_LIMIT:{async limit(){return {success:true};}}};
 db.sqlite.prepare('INSERT INTO auth_key_versions VALUES(?,?,?,?,?)').run('1',createHash('sha256').update(env.AUTH_HMAC_KEY).digest('hex'),createHash('sha256').update(env.AUTH_ENCRYPTION_KEY).digest('hex'),'synthetic-local-fixture',clock.now);
 db.sqlite.exec('UPDATE auth_delivery_control SET enabled=1 WHERE singleton=1');
 db.sqlite.exec("UPDATE auth_settings SET import_ready=1,import_evidence='synthetic-local-test' WHERE singleton=1");
 db.sqlite.exec("INSERT INTO auth_clubs(club_id,club_slug,enabled,allow_signup,auth_template) VALUES(24,'rayon_sports_rw',1,1,'synthetic_auth'),(26,'nkana_zm',1,1,'synthetic_auth')");
 const service=new IdentityService(env,{clock:()=>clock.now});const sql=(s,...args)=>db.sqlite.prepare(s).all(...args);
 const f={env,db,clock,service,sql,count:table=>Number(sql(`SELECT count(*) AS n FROM ${table}`)[0].n),key:()=>crypto.randomUUID(),
  setHook({when,failAt=null,before=null,after=false}){db.when=when;db.failAt=failAt;db.beforeBatch=before;db.afterCommitError=after;},
  clearHook(){db.when=()=>true;db.failAt=null;db.beforeBatch=null;db.afterCommitError=false;},
  async issue({phone=PHONE,club=24,key=crypto.randomUUID(),secret=randomSecret()}={}){const c=await service.challenge(club,{phone,clientSecret:secret},key,'c'.repeat(64));
   const row=sql('SELECT * FROM auth_challenges WHERE challenge_id=?',c.challengeId)[0];
   const payload=await service.vault.open(row.delivery_cipher,`challenge:${c.challengeId}`);
   return {...c,secret,code:payload.code,requestKey:key,phone};},
  async login(options={}){const c=await f.issue(options);const key=crypto.randomUUID();const tokens=await service.verify(c.clubId,{challengeId:c.challengeId,clientSecret:c.secret,code:c.code},key);return {c,key,tokens};},
  async account({phone=PHONE,id=USER,status='active'}={}){const hash=await service.vault.hash('phone',phone),cipher=await service.vault.seal({phone},`phone:${hash}`);
   db.sqlite.prepare("INSERT INTO auth_accounts(user_id,phone_hash,phone_cipher,status,verified_at_ms,created_at_ms,source_project,source_user_id) VALUES(?,?,?,?,?,?,?,?)").run(id,hash,cipher,status,clock.now-1000,clock.now-1000,'synthetic-source',id);return id;},
  async call(operation,{body,method,token,key,headers={},club=24,cf=true,origin=env.AUTH_ORIGIN,raw=false}={}){
   const req=new Request(`${origin}/v1/auth/clubs/${club}/${operation}`,{method:method??(body===undefined?'GET':'POST'),headers:{'x-africlub-client':'native-v1','cf-connecting-ip':'203.0.113.10',...(body!==undefined?{'content-type':'application/json'}:{}),...(token?{authorization:`Bearer ${token}`} : {}),...(key?{'idempotency-key':key}:{}),...headers},...(body!==undefined?{body:raw?body:JSON.stringify(body)}:{})});
   if(cf)Object.defineProperty(req,'cf',{value:{colo:'TEST'}});return gateway.fetch(req,env);}
 };return f;}
export const verifying=steps=>steps.some(s=>s.sql.includes("SET state='consumed'"));
export const rotating=steps=>steps.some(s=>s.sql.includes('generation=generation+1'));
export const deleting=steps=>steps.some(s=>s.sql.includes("SET status='deletion_pending'"));
export async function rejectsCode(promise,code){const {default:assert}=await import('node:assert/strict');await assert.rejects(promise,e=>e?.code===code);}
