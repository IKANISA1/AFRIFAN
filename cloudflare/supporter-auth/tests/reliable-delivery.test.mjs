import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fixture,PHONE} from './support/fixture.mjs';
import {drainOtp,otpQueueHealth} from '../src/reliable-delivery.mjs';
import {deliveryPolicy} from '../src/delivery-policy.mjs';
const accepted=async()=>({accepted:true,messageId:'wamid.synthetic'});
function policy(f,patch={}){const p={...JSON.parse(f.env.AUTH_DELIVERY_POLICY_JSON),...patch};f.env.AUTH_DELIVERY_POLICY_JSON=JSON.stringify(p);return p;}
const drain=(f,extra={})=>drainOtp(f.env,{clock:()=>f.clock.now,sender:accepted,...extra});
const q=f=>f.sql('SELECT * FROM auth_challenges')[0];
const leased=steps=>steps.some(s=>s.sql.includes('INSERT INTO auth_delivery_attempts'));
const acceptedBatch=steps=>steps.some(s=>s.sql.includes("delivery_state='accepted'"));
const invalids=[
 ['version',0],['version','1'],['clubIds',[]],['clubIds',[24,24]],['clubIds',[0]],['clubIds',[1.5]],['clubIds',['24']],['clubIds',[2147483648]],
 ['clubIds',Array.from({length:33},(_,i)=>i+1)],['batchLimit',0],['batchLimit',21],['batchLimit',1.5],['perClubLimit',0],['perClubLimit',11],
 ['rpcTimeoutMs',0],['rpcTimeoutMs',10001],['rpcTimeoutMs','8000'],['leaseMs',20000],['leaseMs',120001],['retryDelayMs',1],['retryDelayMs',300001],
 ['runBudgetMs',7000],['runBudgetMs',25001]
];
for(const [key,value] of invalids)test(`queue rejects invalid ${key}=${JSON.stringify(value)}`,t=>{
 const f=fixture(t);policy(f,{[key]:value});assert.throws(()=>deliveryPolicy(f.env),/invalid_delivery_policy/);
});
for(const mode of [undefined,'legacy','typo','PRIVATE-DEDUPLICATED'])test(`no delivery-mode fallback: ${mode}`,async t=>{
 const f=fixture(t);await f.issue();f.env.AUTH_DELIVERY_MODE=mode;
 await assert.rejects(drain(f,{sender:()=>assert.fail('sender called')}),/private_delivery_required/);assert.equal(q(f).delivery_attempts,0);
});
for(const raw of ['', '{', '[]','null','false','"test"','x'.repeat(4097)])test(`invalid policy envelope ${raw.slice(0,20)}`,t=>{
 const f=fixture(t);f.env.AUTH_DELIVERY_POLICY_JSON=raw;assert.throws(()=>deliveryPolicy(f.env),/invalid_delivery_policy/);
});
test('unknown policy fields and missing fields rejected',t=>{const f=fixture(t);let p=policy(f,{anything:true});assert.throws(()=>deliveryPolicy(f.env));delete p.anything;delete p.runBudgetMs;f.env.AUTH_DELIVERY_POLICY_JSON=JSON.stringify(p);assert.throws(()=>deliveryPolicy(f.env));});
test('private binding required even with a test sender',async t=>{const f=fixture(t);await f.issue();delete f.env.OTP_DELIVERY;await assert.rejects(drain(f),/private_delivery_unavailable/);assert.equal(q(f).delivery_attempts,0);});
test('new SQL delivery control is disabled on migration and blocks dispatch',async t=>{const f=fixture(t);await f.issue();f.db.sqlite.exec('UPDATE auth_delivery_control SET enabled=0');await assert.rejects(drain(f),/delivery_control_disabled/);assert.equal(q(f).delivery_attempts,0);});
test('runtime-disabled delivery makes no database calls',async()=>{const r=await drainOtp({AUTH_DELIVERY_ENABLED:'false'});assert.equal(r.disabled,true);assert.equal(r.accepted,0);});
test('requires first-primary sessions rather than unsafe fallback',async t=>{const f=fixture(t);f.env.AUTH_DB={prepare:()=>assert.fail()};await assert.rejects(drain(f),/primary_database_required/);});
test('legacy unresolved attempts are quarantined without external calls',async t=>{const f=fixture(t);await f.issue();f.db.sqlite.exec("UPDATE auth_challenges SET delivery_attempts=1,delivery_state='retry'");const r=await drain(f,{sender:()=>assert.fail('legacy resend')});assert.equal(r.quarantined,1);assert.equal(q(f).delivery_cipher,null);assert.equal(f.count('auth_delivery_quarantine'),1);assert.equal(f.count('auth_delivery_attempts'),0);});
test('quarantine failure never turns legacy uncertainty into permission to send',async t=>{const f=fixture(t);await f.issue();f.db.sqlite.exec("UPDATE auth_challenges SET delivery_attempts=1,delivery_state='retry'");f.setHook({when:st=>st.some(x=>x.sql.includes('INSERT INTO auth_delivery_quarantine')),failAt:0});await assert.rejects(drain(f,{sender:()=>assert.fail()}),/delivery_quarantine_unavailable/);assert.equal(q(f).delivery_attempts,1);assert.equal(q(f).delivery_state,'retry');});
test('already accepted historical messages are not reinterpreted by adoption',async t=>{const f=fixture(t);await f.issue();f.db.sqlite.exec("UPDATE auth_challenges SET delivery_attempts=1,delivery_state='accepted',provider_message_id='wamid.historical',delivery_cipher=NULL");const r=await drain(f,{sender:()=>assert.fail()});assert.equal(r.quarantined,0);assert.equal(q(f).provider_message_id,'wamid.historical');});
test('least-served tenant scheduling prevents a backlog from crowding out another club',async t=>{
 const f=fixture(t);policy(f,{batchLimit:4,perClubLimit:2});for(let i=0;i<6;i++)await f.issue({phone:`+25070100000${i}`,club:24});await f.issue({club:26});const seen=[];
 const r=await drain(f,{sender:async(_e,p)=>{seen.push(p.clubId);return accepted();}});
 assert.equal(r.accepted,3);assert.ok(seen.slice(0,2).includes(26));assert.equal(seen.filter(x=>x===24).length,2);
});
test('scheduler fairness persists across independent drain invocations',async t=>{
 const f=fixture(t);policy(f,{batchLimit:1,perClubLimit:1});for(const club of [24,26])for(let i=0;i<3;i++)await f.issue({club,phone:`+25070${club}0000${i}`});const seen=[];
 for(let i=0;i<6;i++)await drain(f,{sender:async(_e,p)=>{seen.push(p.clubId);return accepted();}});
 for(let i=1;i<seen.length;i++)assert.notEqual(seen[i],seen[i-1]);assert.equal(f.sql('SELECT sequence FROM auth_delivery_control')[0].sequence,6);
});
test('unconfigured clubs remain unsent',async t=>{const f=fixture(t);policy(f,{clubIds:[24]});await f.issue({club:26});const r=await drain(f,{sender:()=>assert.fail()});assert.equal(r.leased,0);assert.equal(q(f).delivery_attempts,0);});
test('successful acceptance atomically saves one receipt outcome and clears code',async t=>{const f=fixture(t);await f.issue();const r=await drain(f);assert.equal(r.accepted,1);assert.equal(q(f).delivery_cipher,null);assert.equal(f.sql('SELECT outcome FROM auth_delivery_outcomes')[0].outcome,'accepted');assert.equal(f.count('auth_sessions'),0);assert.equal(f.count('auth_accounts'),0);});
test('indefinite private RPC is deadline bounded without pretending to cancel remote work',async t=>{const f=fixture(t);await f.issue();const begin=performance.now();const r=await drain(f,{rpcTimeoutMs:10,sender:()=>new Promise(()=>{})});assert.ok(performance.now()-begin<1000);assert.equal(r.unconfirmed,1);assert.equal(q(f).delivery_state,'retry');});
test('late RPC completion cannot overwrite the timed-out local attempt',async t=>{const f=fixture(t);await f.issue();let resolve;const p=new Promise(r=>resolve=r);const r=await drain(f,{rpcTimeoutMs:10,sender:()=>p});resolve(await accepted());await new Promise(r=>setTimeout(r,5));assert.equal(r.unconfirmed,1);assert.equal(q(f).delivery_state,'retry');assert.equal(f.sql('SELECT outcome FROM auth_delivery_outcomes')[0].outcome,'unconfirmed');});
test('lost lease prevents false accepted count and leaves newer lease untouched',async t=>{const f=fixture(t);await f.issue();const foreign=crypto.randomUUID();const r=await drain(f,{sender:async()=>{f.db.sqlite.prepare('UPDATE auth_challenges SET lease_id=?').run(foreign);return accepted();}});assert.equal(r.accepted,0);assert.equal(r.leaseLost,1);assert.equal(q(f).lease_id,foreign);});
test('expired lease cannot acknowledge an in-flight provider acceptance',async t=>{const f=fixture(t);await f.issue();const r=await drain(f,{sender:async()=>{f.clock.now+=30001;return accepted();}});assert.equal(r.accepted,0);assert.equal(r.unconfirmed,1);assert.equal(q(f).delivery_state,'retry');});
test('response lost after accepted transaction recovers committed outcome without another send',async t=>{const f=fixture(t);await f.issue();let n=0;f.setHook({when:acceptedBatch,after:true});const r=await drain(f,{sender:async()=>{n++;return accepted();}});assert.equal(r.accepted,1);assert.equal(n,1);assert.equal(q(f).delivery_state,'accepted');f.clearHook();await drain(f,{sender:()=>assert.fail()});});
test('lost lease-acquisition reply never sends speculatively',async t=>{const f=fixture(t);await f.issue();policy(f,{batchLimit:1,perClubLimit:1});f.setHook({when:leased,after:true});const r=await drain(f,{sender:()=>assert.fail()});assert.equal(r.skipped,1);assert.equal(q(f).delivery_state,'leased');assert.equal(f.count('auth_delivery_attempts'),1);});
test('expired known lease becomes backoff then same-challenge recovery, not a legacy quarantine',async t=>{const f=fixture(t);const c=await f.issue();policy(f,{batchLimit:1,perClubLimit:1});f.setHook({when:leased,after:true});await drain(f,{sender:()=>assert.fail()});f.clearHook();f.clock.now+=30001;const recovery=await drain(f,{sender:()=>assert.fail('backoff ignored')});assert.equal(recovery.quarantined,0);assert.equal(q(f).delivery_state,'retry');f.clock.now+=30001;let id;const r=await drain(f,{sender:async(_e,p)=>{id=p.challengeId;return accepted();}});assert.equal(r.accepted,1);assert.equal(id,c.challengeId);});
for(let position=0;position<12;position++)test(`lease transaction failure at statement ${position} leaves no send/partial mutation`,async t=>{
 const f=fixture(t);await f.issue();policy(f,{batchLimit:1,perClubLimit:1});f.setHook({when:leased,failAt:position});const r=await drain(f,{sender:()=>assert.fail('uncommitted lease sent')});
 assert.equal(r.accepted,0);assert.equal(q(f).delivery_attempts,0);assert.equal(f.count('auth_delivery_attempts'),0);assert.equal(f.sql('SELECT sequence FROM auth_delivery_control')[0].sequence,0);
});
for(let position=0;position<6;position++)test(`acceptance transaction failure at statement ${position} keeps receipt effects atomic`,async t=>{
 const f=fixture(t);await f.issue();f.setHook({when:acceptedBatch,failAt:position});const r=await drain(f);assert.equal(r.accepted,0);assert.equal(r.unconfirmed,1);assert.equal(q(f).provider_message_id,null);assert.equal(q(f).delivery_state,'retry');assert.equal(f.sql("SELECT * FROM auth_delivery_outcomes WHERE outcome='accepted'").length,0);
});
for(const [name,sql] of [
 ['control','UPDATE auth_delivery_control SET enabled=0'],['club','UPDATE auth_clubs SET enabled=0'],['source','UPDATE auth_settings SET import_ready=0'],
 ['account',"UPDATE auth_accounts SET status='suspended'"]
])test(`post-lease ${name} revocation blocks provider call`,async t=>{
 const f=fixture(t);await f.account();await f.issue();const batch=f.db.batch.bind(f.db);f.db.batch=async st=>{const r=await batch(st);if(leased(st))f.db.sqlite.exec(sql);return r;};
 const r=await drain(f,{sender:()=>assert.fail('revoked before external call')});assert.equal(r.unconfirmed,1);assert.equal(q(f).delivery_state,'failed');
});
test('policy changed after lease is rejected before sending',async t=>{const f=fixture(t);await f.issue();const batch=f.db.batch.bind(f.db);f.db.batch=async st=>{const r=await batch(st);if(leased(st))policy(f,{batchLimit:1,perClubLimit:1});return r;};const r=await drain(f,{sender:()=>assert.fail()});assert.equal(r.unconfirmed,1);});
test('verification during provider request does not become a delivery-granted session',async t=>{const f=fixture(t);const c=await f.issue();const r=await drain(f,{sender:async()=>{await f.service.verify(24,{challengeId:c.challengeId,clientSecret:c.secret,code:c.code},f.key());return accepted();}});assert.equal(r.accepted,0);assert.equal(f.count('auth_sessions'),1);assert.equal(q(f).state,'consumed');});
test('run budget stops new provider requests',async t=>{const f=fixture(t);await f.issue();let tick=0;const r=await drain(f,{monotonic:()=>{tick+=30000;return tick;},sender:()=>assert.fail()});assert.equal(r.leased,0);});
test('retained queue audit cannot be rewritten or deleted',async t=>{const f=fixture(t);await f.issue();await drain(f);for(const table of ['auth_delivery_attempts','auth_delivery_outcomes'])for(const op of ['DELETE FROM', 'UPDATE']){const sql=op==='DELETE FROM'?`${op} ${table}`:`${op} ${table} SET lease_id='replacement'`;assert.throws(()=>f.db.sqlite.exec(sql));}});
test('health output is read-only, aggregated and contains no challenge/phone/code data',async t=>{const f=fixture(t);const c=await f.issue();const before=f.db.sqlite.prepare('SELECT total_changes() n').get().n;const h=await otpQueueHealth(f.env);assert.equal(h.clubs.find(x=>x.clubId===24).states.queued.count,1);assert.equal(h.paymentAuthority,false);assert.equal(h.authenticationAuthority,false);assert.equal(f.db.sqlite.prepare('SELECT total_changes() n').get().n,before);const raw=JSON.stringify(h);for(const secret of [PHONE,c.code,c.challengeId])assert.ok(!raw.includes(secret));});
test('health inspection is independently disabled',async t=>{const f=fixture(t);f.env.AUTH_DELIVERY_HEALTH_ENABLED='false';await assert.rejects(otpQueueHealth(f.env),/delivery_health_disabled/);});
test('health counts saturate rather than scanning unbounded history',async t=>{const f=fixture(t);await f.issue();const original=q(f);const names=Object.keys(original),insert=f.db.sqlite.prepare(`INSERT INTO auth_challenges(${names.join(',')}) VALUES(${names.map(()=>'?').join(',')})`);for(let i=0;i<1005;i++){const row={...original,challenge_id:crypto.randomUUID(),request_key_hash:crypto.randomUUID()};insert.run(...names.map(k=>row[k]));}const h=await otpQueueHealth(f.env);assert.deepEqual(h.clubs.find(x=>x.clubId===24).states.queued,{count:1000,capped:true});});
test('scheduling has club-indexed lookup available',t=>{const f=fixture(t);const plan=f.sql("EXPLAIN QUERY PLAN SELECT challenge_id FROM auth_challenges WHERE club_id=24 AND state='open' AND delivery_cipher IS NOT NULL AND delivery_attempts<3 ORDER BY next_attempt_ms,challenge_id LIMIT 1");assert.ok(plan.some(x=>x.detail.includes('auth_club_delivery_due')));});
test('unexpected database errors are sanitized',async t=>{const f=fixture(t);f.db.withSession=()=>({prepare(){throw Error('PRIVATE SQL TOKEN');}});await assert.rejects(drain(f),e=>e.message==='delivery_storage_unavailable');});
