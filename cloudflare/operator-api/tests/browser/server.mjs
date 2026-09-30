#!/usr/bin/env node
/** Loopback-only SYNTHETIC browser harness. Never deploy this file. It cannot
 * reach a Cloudflare account or production database and never accepts real auth.
 */
import https from 'node:https';import {readFileSync} from 'node:fs';import {randomUUID} from 'node:crypto';
import {fixture,imported} from '../support/fixture.mjs';import gateway from '../../src/index.mjs';
if(process.env.AFRICLUB_SYNTHETIC_UI_TEST!=='1')throw Error('Explicit synthetic test opt-in required');
const [key,cert]=process.argv.slice(2);if(!key||!cert)throw Error('Ephemeral TLS key/certificate paths required');
const control=randomUUID();let f,cleanup,origin,snapshot,loss=false,commands=0;
async function reset(mode='normal'){
 cleanup?.();f=fixture({after(fn){cleanup=fn;}});f.httpEnv.OPERATOR_API_ORIGIN=origin;f.httpEnv.OPERATOR_UI_ENABLED='true';
 // Empty state starts without an import; immutable retention is never bypassed.
 snapshot=mode==='empty'?{id:null}:await imported(f,{title:mode==='markup'?'<img src=x onerror="window.injected=true">':'Synthetic club training update'});
 if(mode==='review-only')f.db.sqlite.exec('UPDATE public_operator_grants SET can_publish=0');
 loss=mode==='loss';commands=0;
}
function state(){return {origin,snapshotId:snapshot.id,reviews:f.sql('SELECT COUNT(*) n FROM public_operator_reviews')[0].n,
 commands,publications:f.sql('SELECT COUNT(*) n FROM public_operator_publications')[0].n,audit:f.sql("SELECT COUNT(*) n FROM public_operator_audit WHERE event_type='snapshot_published'")[0].n};}
const server=https.createServer({key:readFileSync(key),cert:readFileSync(cert)},async(req,res)=>{
 try{
  if(req.url.startsWith('/__test/')){
   if(req.headers.authorization!==`Bearer ${control}`){res.writeHead(403);res.end();return;}
   if(req.url.startsWith('/__test/reset')&&req.method==='POST'){await reset(new URL(req.url,origin).searchParams.get('mode')??'normal');}
   else if(req.url==='/__test/revoke'&&req.method==='POST')f.db.sqlite.exec('UPDATE public_operator_grants SET enabled=0');
   else if(req.url==='/__test/expire'&&req.method==='POST')f.clock.now+=6*60000;
   else if(req.url!=='/__test/state'){res.writeHead(404);res.end();return;}
   res.writeHead(200,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify(state()));return;
  }
  // Browsers may request the site icon implicitly. It carries no application state.
  if(req.url==='/favicon.ico'){res.writeHead(204);res.end();return;}
  const chunks=[];let size=0;for await(const chunk of req){size+=chunk.length;if(size>8192)throw Error('oversize test request');chunks.push(chunk);}
  const body=chunks.length?Buffer.concat(chunks):undefined;
  const request=new Request(origin+req.url,{method:req.method,headers:req.headers,...(body?{body}:{} )});
  if(req.method==='POST'&&req.url.endsWith('/publications'))commands++;
  const response=await gateway.fetch(request,f.httpEnv,f.ctx);
  // A pre-header socket reset can be retried internally by Chromium. Return an
  // unusable acknowledgement after the real commit to deterministically exercise
  // application-level unknown recovery without requesting another publication.
  if(loss&&req.method==='POST'&&req.url.endsWith('/publications')&&response.status===200){loss=false;res.writeHead(200,{'content-type':'application/json','cache-control':'no-store'});res.end('{');return;}
  res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));
 }catch(error){res.writeHead(500,{'content-type':'application/json'});res.end('{"synthetic_harness_error":true}');}
});
server.listen(0,'127.0.0.1',async()=>{origin=`https://127.0.0.1:${server.address().port}`;await reset();console.log(JSON.stringify({origin,control}));});
process.on('SIGTERM',()=>{cleanup?.();server.close(()=>process.exit(0));});
