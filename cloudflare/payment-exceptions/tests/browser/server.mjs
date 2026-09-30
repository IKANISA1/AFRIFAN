/** Isolated HTTPS browser fixture. Synthetic Access context, genuine case SQL.
 * Never deploy. The random control token is printed only to the test runner. */
import https from 'node:https';import {readFileSync} from 'node:fs';import {fixture} from '../fixture.mjs';import gateway from '../../../operator-api/src/index.mjs';
if(process.env.AFRICLUB_SYNTHETIC_UI_TEST!=='1')throw Error('Synthetic test opt-in required');
const [key,cert]=process.argv.slice(2);if(!key||!cert)throw Error('Ephemeral TLS paths required');
const control=crypto.randomUUID();let f,clean,origin,who='maker',lose=false,commands=0;
function reset(){clean?.();f=fixture({after(fn){clean=fn;}});f.httpEnv.OPERATOR_API_ORIGIN=origin;f.httpEnv.OPERATOR_UI_ENABLED='true';who='maker';lose=false;commands=0;}
const server=https.createServer({key:readFileSync(key),cert:readFileSync(cert)},async(req,res)=>{
 try{
  const url=new URL(req.url,origin);
  if(url.pathname.startsWith('/__test/')){
   if(req.headers.authorization!==`Bearer ${control}`){res.writeHead(403);res.end();return;}
   if(req.method==='POST'){
    if(url.pathname==='/__test/reset')reset();
    else if(url.pathname==='/__test/role'){if(!['maker','checker','reader','other'].includes(url.searchParams.get('who')))throw Error('role');who=url.searchParams.get('who');}
    else if(url.pathname==='/__test/loss')lose=true;
    else if(url.pathname==='/__test/revoke')f.db.sql.exec('UPDATE px_grants SET enabled=0');
    else throw Error('control');
   }else if(url.pathname!=='/__test/state')throw Error('control');
   res.writeHead(200,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify({events:f.count(),commands,cases:f.db.sql.prepare('SELECT case_id,state,revision FROM px_cases ORDER BY case_id').all()}));return;
  }
  if(url.pathname==='/favicon.ico'){res.writeHead(204);res.end();return;}
  let size=0;const chunks=[];for await(const c of req){size+=c.length;if(size>8192)throw Error('oversize');chunks.push(c);}
  if(req.method==='POST')commands++;
  const response=await gateway.fetch(new Request(origin+req.url,{method:req.method,headers:req.headers,...(chunks.length?{body:Buffer.concat(chunks)}:{})}),f.httpEnv,f.context(who));
  // Preserve a real committed event, then withhold a usable JSON receipt.
  // Chromium may internally retry pre-header socket resets; this fixture must
  // measure GET-only application recovery with exactly one case command.
  if(lose&&req.method==='POST'&&response.ok){lose=false;res.writeHead(200,{'content-type':'application/json','cache-control':'no-store'});res.end('{');return;}
  res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));
 }catch{res.writeHead(500,{'content-type':'application/json'});res.end('{"synthetic_harness_error":true}');}
});
server.listen(0,'127.0.0.1',()=>{origin=`https://127.0.0.1:${server.address().port}`;reset();console.log(JSON.stringify({origin,control}));});
process.on('SIGTERM',()=>{clean?.();server.close(()=>process.exit(0));});
