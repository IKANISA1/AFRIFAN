import {test} from 'node:test';import assert from 'node:assert/strict';
import {Worker} from 'node:worker_threads';import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';
import {fixture} from './support/fixture.mjs';import {Database} from '../../supporter-auth/tests/support/fixture.mjs';
import {BrowserSessionService} from '../../supporter-auth/src/browser-session-service.mjs';
for(const scenario of ['same-key rotations','different-key rotations','rotation versus logout'])test(`independent SQLite connections: ${scenario}`,async t=>{
 const f=fixture(t),{s}=await f.browserLogin(),dir=mkdtempSync(join(tmpdir(),'africlub-browser-race-')),file=join(dir,'identity.sqlite');
 t.after(()=>rmSync(dir,{recursive:true,force:true}));f.db.sqlite.prepare('VACUUM INTO ?').run(file);
 const barrier=new SharedArrayBuffer(4),flag=new Int32Array(barrier),workers=[],key=f.key();let ready=0;
 const env=Object.fromEntries(Object.entries(f.env).filter(([,v])=>typeof v==='string'));
 const jobs=[0,1].map(i=>new Promise((resolve,reject)=>{
  const w=new Worker(new URL('./support/race-worker.mjs',import.meta.url),{workerData:{file,now:f.clock.now,barrier,env,
   method:scenario==='rotation versus logout'&&i===1?'logout':'rotate',
   args:{sessionCookie:s.sessionCookie,csrfToken:s.view.csrfToken,requestId:scenario==='same-key rotations'?key:f.key()}}});workers.push(w);
  w.on('message',m=>{if(m.ready){ready++;if(ready===2){Atomics.store(flag,0,1);Atomics.notify(flag,0);}}if(m.done)resolve(m);});
  w.on('error',reject);
 }));
 t.after(async()=>{await Promise.all(workers.map(w=>w.terminate()));});
 const results=await Promise.all(jobs);
 const db=new Database(f.clock,{file,initialize:false});t.after(()=>db.sqlite.close());const service=new BrowserSessionService({...f.env,AUTH_DB:db},{clock:()=>f.clock.now});
 if(scenario==='same-key rotations'){
  assert.equal(results.filter(r=>r.ok).length,2);assert.equal(results[0].result.sessionCookie,results[1].result.sessionCookie);
  await service.current(results[0].result.sessionCookie);
 }else assert.equal(results.filter(r=>r.ok).length,1);
 await assert.rejects(service.current(s.sessionCookie));
 assert.equal(db.sqlite.prepare('SELECT count(*) AS n FROM auth_browser_sessions').get().n,1);
 assert.equal(db.sqlite.prepare('SELECT count(*) AS n FROM auth_assertions').get().n,0);
});
