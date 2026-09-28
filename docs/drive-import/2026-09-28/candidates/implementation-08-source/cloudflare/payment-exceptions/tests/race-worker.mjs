import {parentPort,workerData} from 'node:worker_threads';
import {CaseDb} from './fixture.mjs';
import {PaymentExceptionService} from '../src/service.mjs';
const db=new CaseDb(workerData.path,false),gate=new Int32Array(workerData.gate);
db.beforeRun=()=>{parentPort.postMessage({ready:true});if(Atomics.wait(gate,0,0,10000)==='timed-out')throw Error('barrier timeout');};
try {
 const service=new PaymentExceptionService({PAYMENT_CASE_DB:db,PAYMENT_CASES_ENABLED:'true',PAYMENT_CASES_ENVIRONMENT:'isolated-staging'});
 const result=await service.command(workerData.input);parentPort.postMessage({ok:true,result});
}catch(e){parentPort.postMessage({ok:false,code:e.code??'unexpected'});}finally{db.close();}
