import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
for(const guard of ['local_ops_rehearsal_no_network.cjs','local_web_server_no_network.cjs'])
 test('preloaded Node guard rejects outbound TCP, UDP, HTTP, fetch and both Resolver APIs '+guard,()=>{
  const script=`(async()=>{
   const assert=require('node:assert/strict'),net=require('node:net'),dns=require('node:dns'),dgram=require('node:dgram');
   const denied=error=>error.code==='LOCAL_VALIDATION_NETWORK_DISABLED';
   for(const operation of [()=>net.connect({host:'127.0.0.1',port:9}),()=>require('node:http').get('http://127.0.0.1:9'),
    ()=>require('node:https').request('https://synthetic.invalid'),()=>dgram.createSocket('udp4'),
    ()=>dgram.Socket.prototype.send.call({},Buffer.from('synthetic'),9,'127.0.0.1'),
    ()=>dgram.Socket.prototype.connect.call({},9,'127.0.0.1'),
    ()=>dns.lookup('synthetic.invalid',()=>{}),()=>dns.resolve4('synthetic.invalid',()=>{}),
    ()=>new dns.Resolver().resolve4('synthetic.invalid',()=>{})])assert.throws(operation,denied);
   for(const operation of [()=>fetch('http://127.0.0.1:9'),()=>dns.promises.lookup('synthetic.invalid'),
    ()=>dns.promises.resolve4('synthetic.invalid'),()=>new dns.promises.Resolver().resolve4('synthetic.invalid')])await assert.rejects(operation,denied);
   if(${JSON.stringify(guard)}==='local_web_server_no_network.cjs'){
    assert.equal((await dns.promises.lookup('127.0.0.1')).address,'127.0.0.1');
    assert.equal((await dns.promises.lookup('::1')).address,'::1');
   }else await assert.rejects(()=>dns.promises.lookup('127.0.0.1'),denied);
   console.log(JSON.stringify({checksPassed:true}));
  })().catch(()=>{console.log(JSON.stringify({checksPassed:false}));process.exitCode=1;});`;
  const childEnv={...process.env};delete childEnv.NODE_OPTIONS;
  const child=spawnSync(process.execPath,['--require',fileURLToPath(new URL(guard,import.meta.url)),'--eval',script],{env:childEnv,encoding:'utf8',timeout:10000});
  assert.equal(child.status,0,'guard_capability_checks_failed');
  const records=(child.stdout+child.stderr).trim().split('\n').map(line=>JSON.parse(line));
  assert.equal(records.find(row=>row.checksPassed)?.checksPassed,true);
  assert.equal(records.find(row=>row.localValidationNetworkGuard)?.outboundNetworkAttemptsBlocked,guard==='local_web_server_no_network.cjs'?13:14);
 });
