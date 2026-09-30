import {parentPort,workerData} from 'node:worker_threads';
import {TestD1,sourceEnv} from './fixture.mjs';
import {DeliveryRecovery} from '../../src/recovery.mjs';
const db=new TestD1(workerData.file),env={...sourceEnv(db),ALLOCATION_RECOVERY_ENABLED:'true'};
parentPort.postMessage({ready:true});
parentPort.once('message',async()=>{
 try{const service=new DeliveryRecovery(env,workerData.principal);const result=await service[workerData.operation](workerData.input);parentPort.postMessage({ok:true,result});}
 catch(error){parentPort.postMessage({ok:false,code:error.code??'unavailable'});}finally{db.close();}
});
