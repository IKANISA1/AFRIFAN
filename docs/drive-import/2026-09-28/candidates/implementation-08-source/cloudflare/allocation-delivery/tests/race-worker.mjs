import {parentPort,workerData} from 'node:worker_threads';
import {TestD1,sourceEnv,inboxEnv,ids} from './fixture.mjs';
import {DeliverySource} from '../src/source.mjs';
import {AllocationInbox} from '../src/inbox.mjs';
import {AllocationOutbox} from '../../payment-allocation/src/outbox.mjs';
const db=new TestD1(workerData.file);
parentPort.postMessage({ready:true});
parentPort.once('message',async()=>{
 try{
  const env=sourceEnv(db);let result;
  if(workerData.operation==='take')result=await new DeliverySource(env,ids.outbox).take({clubId:24});
  if(workerData.operation==='legacy')result=await new AllocationOutbox(env,ids.outbox).claim({clubId:24,limit:1});
  if(workerData.operation==='redrive')result=await new DeliverySource(env,ids.other).redrive(workerData.input);
  if(workerData.operation==='accept')result=await new AllocationInbox(inboxEnv(db)).accept(workerData.input);
  parentPort.postMessage({ok:true,result});
 }catch(error){parentPort.postMessage({ok:false,code:error.code??'unavailable'});}finally{db.close();}
});
