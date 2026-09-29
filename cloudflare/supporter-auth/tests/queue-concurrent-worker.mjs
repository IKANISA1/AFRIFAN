// Test-only independent SQLite connection and synthetic sender; no external requests.
import {parentPort,workerData} from 'node:worker_threads';
import {Database} from './support/fixture.mjs';
import {drainOtp} from '../src/reliable-delivery.mjs';
const clock={now:workerData.now},db=new Database(clock,{file:workerData.file,initialize:false});
const env={...workerData.env,AUTH_DB:db,OTP_DELIVERY:{async deliverWithReceipt(){throw Error('test uses synthetic sender');}}};
parentPort.postMessage({ready:true});Atomics.wait(new Int32Array(workerData.gate),0,0);
const calls=[];
try{const result=await drainOtp(env,{clock:()=>clock.now,sender:async(_env,input)=>{calls.push(input.challengeId);return {accepted:true,messageId:'wamid.synthetic'};}});parentPort.postMessage({ok:true,result,calls});}
catch(e){parentPort.postMessage({ok:false,code:e.code??'unexpected',calls});}
finally{db.sqlite.close();parentPort.close();}
