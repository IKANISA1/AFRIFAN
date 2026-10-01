import {parentPort,workerData} from 'node:worker_threads';
import {DatabaseSync} from 'node:sqlite';
import {PrivateWebObservationStore,runWebObservationRetention} from '../sink.mjs';
const sql=new DatabaseSync(workerData.file);
sql.exec('PRAGMA busy_timeout=10000; PRAGMA synchronous=FULL;');
sql.function('test_now_ms',()=>workerData.now);
const env={WEB_OBSERVATIONS_ENABLED:'true',WEB_OBSERVATIONS_STORE_ENABLED:'true',
 WEB_OBSERVATIONS_ENVIRONMENT:'isolated-staging',WEB_OBSERVATIONS_ORIGIN:'https://synthetic.invalid',
 WEB_OBSERVATIONS_CLUB_ID:String(workerData.clubId),WEB_OBSERVATIONS_RETENTION_MS:'3600000',
 WEB_OBSERVATIONS_POLICY_REF:'SYNTHETIC_TEST_POLICY',WEB_OBSERVATIONS_DB:{prepare(raw){
 const query=raw.replaceAll("CAST(unixepoch('subsec') * 1000 AS INTEGER)",'test_now_ms()');
 return {args:[],bind(...args){return {...this,args};},async run(){
  return {meta:{changes:Number(sql.prepare(query).run(...this.args).changes)}};
 }};}}};
const barrier=new Int32Array(workerData.barrier);
parentPort.postMessage({ready:true});
Atomics.wait(barrier,0,0);
try{
 if(workerData.operation==='expire'){
  const result=await runWebObservationRetention(env);
  parentPort.postMessage({removed:result.removed});
 }else{
  const store=new PrivateWebObservationStore(env);let accepted=0,rejected=0;
  for(let i=0;i<60;i++){
   try{await store.record({observation:{schemaVersion:1,event:'web_vital',name:'LCP',value:1200,rating:'good'},
    clubId:workerData.clubId,retentionMs:3600000,policyRef:'SYNTHETIC_TEST_POLICY'});accepted++;}
   catch(error){if(error.message!=='web_observation_unavailable')throw error;rejected++;}
  }
  parentPort.postMessage({accepted,rejected});
 }
}finally{sql.close();}
