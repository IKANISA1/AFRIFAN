import {parentPort,workerData} from 'node:worker_threads';
import {Database} from '../../../supporter-auth/tests/support/fixture.mjs';
import {BrowserSessionService} from '../../../supporter-auth/src/browser-session-service.mjs';
const clock={now:workerData.now},db=new Database(clock,{file:workerData.file,initialize:false});
const barrier=new Int32Array(workerData.barrier);
db.when=ss=>ss.some(s=>s.sql.includes('SET cookie_hash=')||s.sql.includes('SET revoked_ms='));
db.beforeBatch=async()=>{parentPort.postMessage({ready:true});Atomics.wait(barrier,0,0,10000);};
try{
 const result=await new BrowserSessionService({...workerData.env,AUTH_DB:db},{clock:()=>clock.now})[workerData.method](workerData.args);
 parentPort.postMessage({done:true,ok:true,result});
}catch(e){parentPort.postMessage({done:true,ok:false,error:e.code??'database_conflict'});}
finally{db.sqlite.close();}
