import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {checkDeployment} from '../scripts/check-deployment.mjs';import {inspectProvider} from '../scripts/inspect-provider.mjs';import {fixture,NOW} from './fixture.mjs';
const config=()=>JSON.parse(readFileSync(new URL('../wrangler.staging.jsonc',import.meta.url),'utf8'));
test('shipped deployment is disabled and never grants readiness',()=>{const r=checkDeployment(config());assert.equal(r.configurationPassed,true);assert.equal(r.liveProviderVerified,false);assert.equal(r.releaseAuthorized,false);});
for(const [name,mutate] of [
 ['public dev URL',c=>c.workers_dev=true],['preview URL',c=>c.preview_urls=true],['public route',c=>c.routes=['example.com/*']],
 ['assets router',c=>c.assets={}],['environment override',c=>c.env={prod:{}}],['plaintext token',c=>c.vars.WA_ACCESS_TOKEN='secret'],
 ['plaintext HMAC',c=>c.vars.DISPATCH_HMAC_KEY='secret'],['enabled template',c=>c.vars.DELIVERY_ENABLED='true'],
 ['cron sends',c=>c.triggers.crons=['* * * * *']],['wrong database',c=>c.d1_databases[0].database_name='member-finance'],
 ['invocation logging',c=>c.observability.enabled=true],['binding fanout',c=>c.services=[{binding:'any'}]],
 ])test(`deployment rejects ${name}`,()=>{const c=config();mutate(c);assert.equal(checkDeployment(c).configurationPassed,false);});
test('ready checker rejects disabled placeholder',()=>assert.equal(checkDeployment(config(),{ready:true,now:NOW}).configurationPassed,false));
test('ready configuration does not claim live provider or rights verification',()=>{const f=fixture();try{
 const c=config();Object.assign(c.vars,{DELIVERY_ENABLED:'true',WA_GRAPH_VERSION:'v99.0',DELIVERY_ROUTES_JSON:f.env.DELIVERY_ROUTES_JSON});c.d1_databases[0].database_id=crypto.randomUUID();
 const r=checkDeployment(c,{ready:true,now:NOW});assert.equal(r.configurationPassed,true);assert.equal(r.senderOwnershipVerified,false);assert.equal(r.consentVerified,false);assert.equal(r.copyCodeTemplateReviewed,false);
}finally{f.close();}});
test('provider inspection defaults to zero network calls',async()=>{const f=fixture();try{
 const r=await inspectProvider(f.env,{clock:f.now,fetcher:f.fetcher});assert.equal(r.dryRun,true);assert.equal(f.calls.length,0);assert.equal(r.messagesSent,0);
}finally{f.close();}});
test('explicit provider inspection calls GET only, not messages',async()=>{const f=fixture();try{
 const r=await inspectProvider(f.env,{execute:true,clock:f.now,fetcher:f.fetcher});assert.equal(r.templateMetadataVerified,true);assert.equal(r.messagesSent,0);assert.equal(f.calls.length,1);assert.equal(f.calls[0].init.method,'GET');
}finally{f.close();}});
test('inspection refuses unapproved template',async()=>{const f=fixture();try{
 f.override(async()=>Response.json({...f.template(),status:'PAUSED'}));await assert.rejects(inspectProvider(f.env,{execute:true,clock:f.now,fetcher:f.fetcher}),/template_not_approved/);
}finally{f.close();}});
test('private wrapper has no public send route or unbounded error details',()=>{
 const s=readFileSync(new URL('../src/worker.mjs',import.meta.url),'utf8');assert.match(s,/export class AuthenticationCodeDelivery extends WorkerEntrypoint/);assert.match(s,/status:404/);assert.match(s,/throw new Error\('delivery_unavailable'\)/);assert.doesNotMatch(s,/console\.|request\.json/);
});
test('private RPC declares current queued-auth receipt contract without auto-provider retry',()=>{
 const c=JSON.parse(readFileSync(new URL('../contracts/private-rpc.json',import.meta.url),'utf8'));
 assert.equal(c.currentQueueMethod,'deliverWithReceipt');assert.equal(c.entrypoint,'AuthenticationCodeDelivery');
 assert.equal(c.binding,'OTP_DELIVERY');assert.equal(c.trust.automaticProviderRetry,false);
 assert.equal(c.maxCodeLifetimeMilliseconds,600000);
});
