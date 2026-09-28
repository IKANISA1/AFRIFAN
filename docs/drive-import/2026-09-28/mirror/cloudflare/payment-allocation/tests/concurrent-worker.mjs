// Test-only independent SQLite connection. Never used by a production entrypoint.
import {workerData,parentPort} from 'node:worker_threads';
import {DatabaseSync} from 'node:sqlite';
import {PaymentAllocationService} from '../src/service.mjs';
import {NOW_SQL} from '../src/policy.mjs';
const sql=new DatabaseSync(workerData.file);sql.function('test_now_ms',()=>workerData.now);sql.exec('PRAGMA busy_timeout=10000;PRAGMA foreign_keys=ON;');
const db={withSession(mode){if(mode!=='first-primary')throw Error('non-primary');return this;},prepare(text){const query=text.replaceAll(NOW_SQL,'test_now_ms()');return {query,args:[],bind(...args){return {...this,args};},async first(){return sql.prepare(query).get(...this.args)??null;},async all(){return {results:sql.prepare(query).all(...this.args)};},async run(){const r=sql.prepare(query).run(...this.args);return {success:true,meta:{changes:Number(r.changes)}};}};},async batch(statements){sql.exec('BEGIN IMMEDIATE');try{const out=statements.map(s=>({success:true,meta:{changes:Number(sql.prepare(s.query).run(...s.args).changes)}}));sql.exec('COMMIT');return out;}catch(e){sql.exec('ROLLBACK');throw e;}}};
parentPort.postMessage({ready:true});const gate=new Int32Array(workerData.gate);Atomics.wait(gate,0,0);
try{const service=new PaymentAllocationService({PAYMENT_ALLOCATION_ENABLED:'true',ALLOCATION_ENVIRONMENT:'isolated-staging',ALLOCATION_DB:db},workerData.principal);const result=await service.allocate(workerData.input);parentPort.postMessage({ok:true,result});}catch(error){parentPort.postMessage({ok:false,code:error.code??'unexpected'});}finally{sql.close();parentPort.close();}
