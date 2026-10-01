/** Actual sealed Next production documents, hydration and browser CSP enforcement.
 * Server sockets cannot connect externally; browser requests stay on loopback.
 * Synthetic injection probes are deliberate and separate from runtime violations.
 */
import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {spawn} from 'node:child_process';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {resolve,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {validateProductionBuild} from '../../apps/rayon_sports/web/scripts/web-build-provenance.mjs';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const web=resolve(root,'apps/rayon_sports/web');
const output=resolve(process.argv[2]??resolve(root,'output/qa/full-stack-20260914/production-goal-20260930-phase4/web-render-security.json'));
const {chromium,devices,expect}=createRequire(resolve(web,'package.json'))('@playwright/test');
assert.equal(process.version,'v22.23.2','pinned_node_required');
const before=validateProductionBuild(web);
const networkControls=()=>['local_web_server_no_network.cjs','local_ops_rehearsal_no_network.cjs'].map(file=>({
 path:'tools/scripts/'+file,sha256:createHash('sha256').update(readFileSync(resolve(root,'tools/scripts',file))).digest('hex')}));
const controlsBefore=networkControls();
const harnessFile=fileURLToPath(import.meta.url);
const harnessSha256=createHash('sha256').update(readFileSync(harnessFile)).digest('hex');
const origin='http://127.0.0.1:3350';
const server=spawn(process.execPath,[resolve(web,'node_modules/next/dist/bin/next'),'start','--hostname','127.0.0.1','--port','3350'],{
 cwd:web,env:{...process.env,AFRICLUB_ALLOW_HTTP_PREVIEW:'1',AFRICLUB_CONTROLLED_ADMIN_EVIDENCE:'1',AFRICLUB_CONTROLLED_ROUTE_EVIDENCE:'1',
 NODE_OPTIONS:`--require=${resolve(root,'tools/scripts/local_web_server_no_network.cjs')}`},stdio:['ignore','pipe','pipe'],detached:true});
let serverBlocked=0,browserBlocked=0,browser,guardReports=0;
const pendingOutput={stdout:'',stderr:''};
function collectGuardOutput(channel,chunk){
 pendingOutput[channel]+=chunk.toString();
 const lines=pendingOutput[channel].split('\n');pendingOutput[channel]=lines.pop();
 if(pendingOutput[channel].length>4096)pendingOutput[channel]='';
 for(const line of lines){
  if(!line.startsWith('{"localValidationNetworkGuard":'))continue;
  try{const record=JSON.parse(line);
   if(record.localValidationNetworkGuard===true&&Number.isInteger(record.outboundNetworkAttemptsBlocked)&&record.outboundNetworkAttemptsBlocked>=0){
    serverBlocked+=record.outboundNetworkAttemptsBlocked;guardReports++;
   }
  }catch{/* Invalid guard record is not admitted. */}
 }
}
server.stdout.on('data',chunk=>collectGuardOutput('stdout',chunk));
server.stderr.on('data',chunk=>collectGuardOutput('stderr',chunk)); // Never persist raw diagnostics.
const results=[];
const report={schemaVersion:1,productionReady:false,providerCalls:0,deploymentActions:0,build:before,
 harness:{path:'tools/scripts/local_web_security_render.mjs',sha256:harnessSha256},
 nodeNetworkControls:controlsBefore,
 nodeNetworkControlScope:'Node TCP/UDP/HTTP/fetch/DNS rejection with local Unix-domain IPC; this is not operating-system network isolation.',
 scope:'Actual sealed Next production documents, desktop/mobile Chromium hydration and controlled CSP injection probes.',results};
const delay=ms=>new Promise(done=>setTimeout(done,ms));
function privateDocument(headers){
 assert.match(headers['cache-control']??'',/\bno-store\b/,'document_cache_not_private');
 assert.equal(headers['cdn-cache-control'],'no-store','cdn_document_cache_not_private');
 assert.equal(headers['cloudflare-cdn-cache-control'],'no-store','cloudflare_document_cache_not_private');
 const policy=headers['content-security-policy']??'';
 const nonce=policy.match(/'nonce-([A-Za-z0-9+/]{22}==)'/)?.[1];
 assert.ok(nonce,'response_nonce_missing');
 const scripts=policy.split(';').find(value=>value.trim().startsWith('script-src '));
 assert.ok(scripts?.includes("'strict-dynamic'"),'strict_dynamic_missing');
 assert.ok(!scripts?.includes("'unsafe-inline'")&&!scripts?.includes("'unsafe-eval'"),'unsafe_script_source');
 assert.ok(policy.includes("script-src-attr 'none'")&&policy.includes("object-src 'none'"),'active_content_policy_missing');
 return nonce;
}
try{
 let ready=false;
 for(let i=0;i<50;i++){
  assert.equal(server.exitCode,null,'production_server_exited');
  try{const response=await fetch(origin+'/offline',{signal:AbortSignal.timeout(3000)});if(response.ok){ready=true;break;}}catch{/* Startup not yet ready. */}
  await delay(200);
 }
 assert.ok(ready,'production_server_not_ready');
 browser=await chromium.launch({channel:'chromium',args:['--disable-features=ViewTransitionOnNavigation']});
 const nonces=new Set();
 for(const project of ['desktop','mobile']){
  const context=await browser.newContext({...project==='mobile'?{...devices['Pixel 7']}:{viewport:{width:1440,height:900}},reducedMotion:'reduce',bypassCSP:false,serviceWorkers:'block'});
  await context.route('**/*',route=>{
   if(new URL(route.request().url()).origin===origin)return route.continue();
   browserBlocked++;return route.abort('blockedbyclient');
  });
  const page=await context.newPage();page.setDefaultTimeout(15000);
  await page.addInitScript(()=>{
   window.__localSecurityViolations=[];
   document.addEventListener('securitypolicyviolation',event=>window.__localSecurityViolations.push({directive:event.effectiveDirective,kind:event.blockedURI==='inline'?'inline':event.blockedURI==='eval'?'eval':'resource'}));
  });
  let pageErrors=0;page.on('pageerror',()=>pageErrors++);
  for(const route of ['/contact','/offline','/membership','/admin?evidence=1','/admin/matches?evidence=1']){
   report.currentStep={project,route,phase:'navigation'};
   const priorErrors=pageErrors;
   await page.setExtraHTTPHeaders({'x-africlub-csp-nonce':'AAAAAAAAAAAAAAAAAAAAAA==','content-security-policy':"script-src 'unsafe-inline' 'unsafe-eval'"});
   const response=await page.goto(origin+route,{waitUntil:'networkidle'});
   report.currentStep={project,route,phase:'response_headers'};
   assert.ok(response?.ok(),'rendered_route_failed');
   const nonce=privateDocument(response.headers());
   assert.notEqual(nonce,'AAAAAAAAAAAAAAAAAAAAAA==','inbound_nonce_trusted');
   assert.ok(!nonces.has(nonce),'request_nonce_reused');nonces.add(nonce);
   const scripts=await page.locator('script').evaluateAll(nodes=>nodes.map(node=>({nonce:node.nonce,kind:node.type,src:!!node.src})));
   report.currentStep={project,route,phase:'script_and_hydration_assertions'};
   const initialScripts=[...(await response.text()).matchAll(/<script\b([^>]*)>/g)].map(match=>({nonce:match[1].match(/\bnonce="([^"]+)"/)?.[1],kind:match[1].match(/\btype="([^"]+)"/)?.[1]??'',src:/\bsrc=/.test(match[1])}));
   report.scriptDiagnostics={project,route,initial:initialScripts.map(node=>({kind:node.kind,src:node.src,matching:node.nonce===nonce,noncePresent:!!node.nonce})),hydrated:scripts.map(node=>({kind:node.kind,src:node.src,matching:node.nonce===nonce,noncePresent:!!node.nonce}))};
   assert.ok(scripts.some(node=>node.src),'framework_scripts_missing');
   assert.ok(scripts.some(node=>node.kind==='application/ld+json'),'jsonld_missing');
   assert.ok(initialScripts.length>0&&initialScripts.every(node=>node.nonce===nonce),'script_nonce_mismatch');
   assert.equal(pageErrors-priorErrors,0,'runtime_page_error');
   assert.deepEqual(await page.evaluate(()=>window.__localSecurityViolations),[],'runtime_csp_violation');
   if(project==='mobile'&&route==='/contact'){
    await page.getByRole('button',{name:'Open menu',exact:true}).click();
    await expect(page.getByRole('dialog',{name:'Navigation menu',exact:true})).toBeVisible();
    await page.keyboard.press('Escape');
    await expect(page.getByRole('button',{name:'Open menu',exact:true})).toHaveAttribute('aria-expanded','false');
   }
   results.push({project,route,status:response.status(),scriptCount:scripts.length,matchingNonces:true,privateCache:true,runtimeErrors:0,runtimeCspViolations:0,hydrationInteraction:project==='mobile'&&route==='/contact'});
  }
  // DevTools evaluation is privileged and cannot demonstrate CSP rejection.
  // Deliver a finite diagnostic document through the HTML parser with the
  // unchanged live response policy. Its nonce-bearing control tests eval;
  // the other inline script/handler have no granted nonce or hash.
  const probeUrl=origin+'/admin/matches?evidence=1&csp-probe=1';
  let probePolicyHash=null;
  await page.route(probeUrl,async route=>{
   const response=await route.fetch({maxRedirects:0});
   assert.equal(response.status(),200,'probe_source_response_failed');
   const headers={...response.headers()},nonce=privateDocument(headers);
   probePolicyHash=createHash('sha256').update(headers['content-security-policy']).digest('hex');
   const body=`<!doctype html><html><head><meta charset="utf-8">
    <script nonce="${nonce}">
     window.__localSecurityControl=true;window.__localSecurityProbe=0;window.__localEvalBlocked=false;
     window.__localSecurityViolations=[];
     document.addEventListener('securitypolicyviolation',function(event){window.__localSecurityViolations.push({directive:event.effectiveDirective,kind:event.blockedURI==='inline'?'inline':event.blockedURI==='eval'?'eval':'resource'});});
     try{new Function('window.__localSecurityProbe+=100')();}catch(error){window.__localEvalBlocked=error instanceof EvalError;}
     document.addEventListener('DOMContentLoaded',function(){document.getElementById('probe-handler').click();});
    </script>
    <script>window.__localSecurityProbe+=1</script>
    </head><body><button id="probe-handler" onclick="window.__localSecurityProbe+=10">Diagnostic handler</button></body></html>`;
   delete headers['content-encoding'];delete headers['transfer-encoding'];
   headers['content-length']=String(Buffer.byteLength(body));
   await route.fulfill({status:response.status(),headers,body});
  });
  await page.goto(probeUrl,{waitUntil:'networkidle'});
  const probes=await page.evaluate(()=>({controlLoaded:window.__localSecurityControl===true,
   value:window.__localSecurityProbe,evalBlocked:window.__localEvalBlocked,violations:window.__localSecurityViolations}));
  assert.equal(probes.controlLoaded,true,'nonce_control_not_executed');
  assert.equal(probes.value,0,'untrusted_script_executed');assert.equal(probes.evalBlocked,true,'eval_not_blocked');
  assert.ok(probes.violations.some(row=>row.directive==='script-src-elem'&&row.kind==='inline'),'inline_probe_not_observed');
  assert.ok(probes.violations.some(row=>row.directive==='script-src-attr'),'handler_probe_not_observed');
  assert.ok(probes.violations.some(row=>row.kind==='eval'),'eval_probe_not_observed');
  results.push({project,scope:'deliberate_untrusted_injection',passed:true,evalBlocked:true,inlineScriptBlocked:true,eventHandlerBlocked:true,
   delivery:'HTML parser with unchanged live response CSP; DevTools only reads the result',livePolicySha256:probePolicyHash});
  await context.close();
 }
 const redirect=await fetch(origin+'/admin/offline?probe=1',{redirect:'manual'});
 assert.equal(redirect.status,308,'recovery_redirect_status');
 assert.equal(new URL(redirect.headers.get('location'),origin).origin,origin,'recovery_redirect_left_origin');
 assert.equal(new URL(redirect.headers.get('location'),origin).pathname,'/admin-offline','recovery_redirect_wrong_path');
 privateDocument(Object.fromEntries(redirect.headers));
 results.push({scope:'actual_recovery_redirect',passed:true,status:308,sameOrigin:true,privateCache:true});
 report.after=validateProductionBuild(web);assert.deepEqual(report.after,before,'build_changed_during_render');
 assert.deepEqual(networkControls(),controlsBefore,'network_controls_changed_during_render');
 assert.equal(createHash('sha256').update(readFileSync(harnessFile)).digest('hex'),harnessSha256,'render_harness_changed_during_execution');
 report.passed=true;
}catch(error){report.passed=false;report.failure=error instanceof assert.AssertionError?error.message:'local_render_verification_failed';report.failureKind=error instanceof assert.AssertionError?'assertion':error?.name==='TimeoutError'?'timeout':'execution';process.exitCode=1;}
finally{
 if(browser)await browser.close();
 if(server.exitCode===null){
  try{process.kill(-server.pid,'SIGTERM');}catch{server.kill('SIGTERM');}
  await Promise.race([new Promise(done=>server.once('close',done)),delay(5000)]);
  if(server.exitCode===null){try{process.kill(-server.pid,'SIGKILL');}catch{server.kill('SIGKILL');}}
 }
 report.serverOutboundAttemptsBlocked=guardReports?serverBlocked:null;
 report.serverNetworkGuardReports=guardReports;report.browserForeignRequestsBlocked=browserBlocked;
 mkdirSync(dirname(output),{recursive:true});writeFileSync(output,JSON.stringify(report,null,2)+'\n');
 process.stdout.write(JSON.stringify({passed:report.passed,checks:results.length,failure:report.failure??null,report:output})+'\n');
}
