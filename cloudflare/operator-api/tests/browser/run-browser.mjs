#!/usr/bin/env node
/** Controlled loopback HTTPS acceptance using installed Node Playwright.
 * Original Python harnesses remain source evidence. No browser installation,
 * policy changes, hosted identity, remote provider or deployment is performed.
 */
import assert from 'node:assert/strict';
import {spawn,execFileSync} from 'node:child_process';
import {mkdtempSync,mkdirSync,writeFileSync,rmSync,createWriteStream} from 'node:fs';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {createRequire} from 'node:module';
import {createInterface} from 'node:readline';
import {fileURLToPath} from 'node:url';

const require=createRequire(import.meta.url);
const {chromium}=require(process.env.PLAYWRIGHT_MODULE||'playwright');
const {expect}=require(process.env.PLAYWRIGHT_TEST_MODULE||'@playwright/test');
const [output,executablePath]=process.argv.slice(2);
if(!output||!executablePath||process.argv.length!==4)throw Error('Usage: run-browser.mjs OUTPUT INSTALLED_CHROMIUM');
const root=fileURLToPath(new URL('../../../../',import.meta.url)),out=resolve(output);
mkdirSync(out,{recursive:true});
const temporary=mkdtempSync(join(tmpdir(),'africlub-operator-browser-'));
const key=join(temporary,'key.pem'),cert=join(temporary,'cert.pem');
execFileSync('openssl',['req','-x509','-newkey','rsa:2048','-keyout',key,'-out',cert,'-days','1','-nodes','-subj','/CN=localhost','-addext','subjectAltName=IP:127.0.0.1'],{stdio:'pipe'});
const results=[],processes=[],streams=[];let browser,blocked=false;
const save=()=>writeFileSync(join(out,'browser-results.json'),JSON.stringify({
 schemaVersion:1,scope:'Actual installed Chromium, active gateway/UI and local SQLite with synthetic Access/RPC/R2; no hosted Cloudflare acceptance',
 browser:browser?.version(),playwright:require(process.env.PLAYWRIGHT_MODULE?join(process.env.PLAYWRIGHT_MODULE,'package.json'):'playwright/package.json').version,
 renderedAcceptance:results.length===19&&results.every(x=>x.passed),navigationBlockedByAdministrator:blocked,
 browserPolicyChanged:false,remoteCalls:false,passed:results.filter(x=>x.passed).length,failed:results.filter(x=>!x.passed).length,cases:results,
},null,2)+'\n');
async function startServer(path,name){
 const log=createWriteStream(join(out,name+'-server.log'));streams.push(log);
 const child=spawn(process.execPath,[join(root,path),key,cert],{env:{...process.env,AFRICLUB_SYNTHETIC_UI_TEST:'1'},stdio:['ignore','pipe','pipe']});processes.push(child);child.stderr.pipe(log);
 const lines=createInterface({input:child.stdout});
 const setting=await new Promise((resolve,reject)=>{
  const timer=setTimeout(()=>reject(Error('Synthetic server startup timeout')),15000);
  lines.once('line',line=>{clearTimeout(timer);try{resolve(JSON.parse(line));}catch(error){reject(error);}});
  child.once('exit',code=>{clearTimeout(timer);reject(Error('Synthetic server exited '+code));});
 });
 lines.close();assert.match(setting.origin,/^https:\/\/127\.0\.0\.1:\d+$/);
 const api=await browser.newContext({ignoreHTTPSErrors:true});
 const control=async(path='state',method='GET')=>{
  const response=await api.request.fetch(setting.origin+'/__test/'+path,{method,headers:{authorization:'Bearer '+setting.control}});
  assert.equal(response.ok(),true,'Synthetic fixture control failed');return response.json();
 };
 return {...setting,control,dispose:()=>api.close()};
}
async function runCase(name,task,{width=1280,height=900,expectedConsole=false}={}){
 if(blocked)return;
 const ctx=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width,height},reducedMotion:'reduce'}),page=await ctx.newPage(),consoleErrors=[],pageErrors=[],requestFailures=[];
 page.on('requestfailed',request=>requestFailures.push({method:request.method(),path:new URL(request.url()).pathname,error:request.failure()?.errorText}));
 page.on('console',m=>{if(['warning','error'].includes(m.type()))consoleErrors.push(m.text());});page.on('pageerror',e=>pageErrors.push(String(e)));
 try{
  await task(page,ctx);assert.deepEqual(pageErrors,[]);if(!expectedConsole)assert.deepEqual(consoleErrors,[]);
  results.push({name,passed:true,viewport:[width,height],pageErrors,consoleErrors});
 }catch(error){
  blocked=String(error).includes('ERR_BLOCKED_BY_ADMINISTRATOR');
  results.push({name,passed:false,error:String(error),blockedByAdministrator:blocked,pageErrors,consoleErrors,requestFailures});
  await page.screenshot({path:join(out,name+'-failed.png'),fullPage:true}).catch(()=>{});
 }finally{await ctx.close();save();}
}
try{
 browser=await chromium.launch({executablePath,headless:true});
 const f=await startServer('cloudflare/operator-api/tests/browser/server.mjs','publication');
 const state=()=>f.control(),reset=mode=>f.control('reset?mode='+(mode||'normal'),'POST');
 const load=async page=>{await page.goto(f.origin+'/operator/clubs/24/public-source');await expect(page.locator('#status')).toHaveText('Choose a snapshot to inspect.');assert.equal(await page.title(),'Content publication · AFRICLUB');};
 const review=async page=>{await page.locator('#candidates button').first().click();await expect(page.locator('#candidate-section')).toBeVisible();await page.locator('#evidence').fill('editorial:synthetic-browser');await page.locator('#review').click();await expect(page.locator('#status')).toHaveText('Verification passed. Nothing has been published.');assert.equal((await state()).publications,0);};
 const confirm=async page=>{await page.locator('#acknowledge').check();await page.locator('#confirmation').fill(await page.locator('#confirmation-phrase').innerText());await expect(page.locator('#publish')).toBeEnabled();await page.locator('#publish').click();};
 const publicationCase=(name,task,options={},mode)=>runCase(name,async(page,ctx)=>{await reset(mode);await task(page,ctx);},options);
 await publicationCase('desktop-complete-flow',async page=>{
  await load(page);assert.equal((await state()).reviews,0);await page.screenshot({path:join(out,'publication-desktop.png'),fullPage:true});
  await review(page);await expect(page.locator('#publish')).toBeDisabled();await page.locator('#preview-load').click();await expect(page.locator('#preview')).toContainText('Synthetic club training update');assert.equal(await page.locator('#preview img').count(),0);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  await confirm(page);await expect(page.locator('#receipt-section')).toBeVisible();assert.equal((await state()).publications,1);assert.equal((await state()).audit,1);
  await page.screenshot({path:join(out,'publication-receipt.png'),fullPage:true});await page.reload();await expect(page.locator('#receipt-section')).toBeVisible();assert.equal((await state()).publications,1);
 });
 for(const width of [390,320])await publicationCase('mobile-'+width,async page=>{
  await load(page);await review(page);await page.locator('#preview-load').click();await expect(page.locator('#preview')).toContainText('Synthetic club training update');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
  for(const id of ['evidence','confirmation','publish','preview-route']){const box=await page.locator('#'+id).boundingBox();if(box)assert.ok(box.x>=-1&&box.x+box.width<=width+1,id);}
  await page.screenshot({path:join(out,'publication-mobile-'+width+'.png'),fullPage:true});
 },{width,height:width===390?844:740});
 await publicationCase('lost-response-reload-recovery',async page=>{
  await load(page);await review(page);await confirm(page);await expect(page.locator('#recovery-note')).toBeVisible();await expect(page.locator('#status')).toHaveText('Publication outcome requires verification.');assert.equal((await state()).publications,1);assert.equal((await state()).commands,1);await expect(page.locator('#reset')).toBeHidden();
  const writes=[];page.on('request',r=>{if(r.method()==='POST')writes.push(r.url());});await page.reload();await expect(page.locator('#receipt-section')).toBeVisible();assert.deepEqual(writes,[]);assert.equal((await state()).publications,1);assert.equal((await state()).commands,1);
 },{expectedConsole:true},'loss');
 await publicationCase('expired-review',async page=>{await load(page);await review(page);await f.control('expire','POST');await page.locator('#check-result').click();await expect(page.locator('#status')).toHaveText('The review has expired.');await expect(page.locator('#publish')).toBeDisabled();assert.equal((await state()).publications,0);});
 await publicationCase('revoked-permission',async page=>{await load(page);await review(page);await f.control('revoke','POST');await confirm(page);await expect(page.locator('#error')).toContainText('permission');await expect(page.locator('#candidate-section')).toBeHidden();assert.equal((await state()).publications,0);},{expectedConsole:true});
 await publicationCase('empty-imports',async page=>{await load(page);await expect(page.locator('#candidates')).toContainText('No reviewable snapshots');assert.equal((await state()).reviews,0);}, {},'empty');
 await publicationCase('source-markup-not-executed',async page=>{await load(page);await review(page);await page.locator('#preview-load').click();await expect(page.locator('#preview')).toContainText('<img src=x');assert.equal(await page.evaluate(()=>Boolean(window.injected)),false);assert.equal(await page.locator('#preview img').count(),0);},{},'markup');
 await publicationCase('review-only-operator',async page=>{await load(page);await review(page);await page.locator('#acknowledge').check();await page.locator('#confirmation').fill(await page.locator('#confirmation-phrase').innerText());await expect(page.locator('#publish')).toBeDisabled();assert.equal((await state()).publications,0);},{},'review-only');
 await publicationCase('storage-unavailable',async page=>{await page.addInitScript(()=>{Storage.prototype.setItem=function(){throw new DOMException('Denied','SecurityError');};});await page.goto(f.origin+'/operator/clubs/24/public-source');await expect(page.locator('#error')).toContainText('durable recovery');await page.locator('#candidates button').first().click();await expect(page.locator('#review')).toBeDisabled();assert.equal((await state()).reviews,0);});
 await publicationCase('keyboard-focus-and-skip',async page=>{await load(page);await page.keyboard.press('Tab');await expect(page.locator('.skip-link')).toBeFocused();await page.keyboard.press('Enter');assert.equal(await page.evaluate(()=>location.hash),'#main');await review(page);await expect(page.locator('#review-heading')).toBeFocused();});
 await publicationCase('real-cross-tab-lock',async(page,ctx)=>{
  await load(page);await review(page);const other=await ctx.newPage();await other.goto(f.origin+'/operator/clubs/24/public-source');await expect(other.locator('#review-section')).toBeVisible();assert.equal((await state()).reviews,1);
  await page.evaluate(()=>{const key=Object.keys(localStorage).find(k=>k.startsWith('africlub:public-source:v1:'));window.lockReady=false;navigator.locks.request(key,async()=>{window.lockReady=true;await new Promise(r=>{window.releaseLock=r;});});});await page.waitForFunction(()=>window.lockReady);
  await confirm(other);await expect(other.locator('#error')).toContainText('Another tab');assert.equal((await state()).publications,0);await page.evaluate(()=>window.releaseLock());await other.close();
 });
 await publicationCase('200-percent-page-zoom',async page=>{await load(page);await review(page);await page.evaluate(()=>{document.documentElement.style.zoom='2';});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);await page.screenshot({path:join(out,'publication-200-percent-zoom.png'),fullPage:true});},{width:1440,height:1000});
 await f.dispose();
 if(!blocked){
  const c=await startServer('cloudflare/payment-exceptions/tests/browser/server.mjs','cases');let caseId;
  const navigate=async page=>{await page.goto(c.origin+'/operator/clubs/24/payment-exceptions');await expect(page.locator('#role-context')).toHaveText(/Case|Read-only/);await expect(page.locator('#status')).toContainText('Workspace updated');};
  const command=async(page,action,digest=false)=>{await page.locator('#action').selectOption(action);if(digest)await page.locator('#evidence-digest').fill('d'.repeat(64));await page.getByRole('button',{name:'Review command',exact:true}).click();await page.locator('#confirm-ack').check();await page.getByRole('button',{name:'Confirm case command',exact:true}).click();await expect(page.locator('#receipt-section')).toBeVisible();await expect(page.locator('#status')).toContainText('Workspace updated');};
  const open=async page=>{await page.getByRole('button',{name:'Open a case',exact:true}).click();await page.locator('#order-id').fill(crypto.randomUUID());await command(page,'open');};
  await c.control('reset','POST');
  await runCase('case-maker-opens-and-proposes',async page=>{await navigate(page);assert.equal(await page.title(),'Payment case review · AFRICLUB');assert.equal((await c.control()).events,0);await open(page);assert.equal((await c.control()).events,1);await command(page,'propose',true);const s=await c.control();assert.equal(s.events,2);caseId=s.cases[0].case_id;await page.screenshot({path:join(out,'case-proposal-desktop.png'),fullPage:true});});
  await c.control('role?who=checker','POST');
  await runCase('case-separate-checker-approves',async page=>{await navigate(page);await page.locator('#case-list button').first().click();await expect(page.locator('#case-details')).toContainText('awaiting_review');await command(page,'approve');assert.equal((await c.control()).events,3);});
  await c.control('role?who=maker','POST');
  await runCase('case-maker-closes-reopens-mobile',async page=>{await navigate(page);await page.locator('#case-list button').first().click();await expect(page.locator('#case-details')).toContainText('reviewed');await command(page,'close',true);assert.equal((await c.control()).cases.find(x=>x.case_id===caseId).state,'closed');await command(page,'reopen');assert.equal((await c.control()).cases[0].state,'investigating');assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);await page.screenshot({path:join(out,'case-mobile.png'),fullPage:true});},{width:390,height:844});
  await runCase('case-lost-response-read-only-recovery',async page=>{
   await c.control('reset','POST');await navigate(page);await c.control('loss','POST');await page.getByRole('button',{name:'Open a case',exact:true}).click();await page.locator('#order-id').fill(crypto.randomUUID());await page.getByRole('button',{name:'Review command',exact:true}).click();await page.locator('#confirm-ack').check();await page.getByRole('button',{name:'Confirm case command',exact:true}).click();await expect(page.locator('#pending-section')).toBeVisible();await expect(page.locator('#error')).toBeVisible();assert.equal((await c.control()).events,1);
   await navigate(page);assert.equal((await c.control()).commands,1);await page.getByRole('button',{name:'Check original result',exact:true}).click();await expect(page.locator('#receipt-section')).toBeVisible();await expect(page.locator('#pending-section')).toBeHidden();assert.equal((await c.control()).commands,1);
  },{expectedConsole:true});
  await runCase('case-revoked-access-clears-private-view',async page=>{await navigate(page);await page.locator('#case-list button').first().click();await expect(page.locator('#detail-section')).toBeVisible();await c.control('revoke','POST');await page.getByRole('button',{name:'Refresh access',exact:true}).click();await expect(page.locator('#error')).toBeVisible();await expect(page.locator('#command-section')).toBeHidden();await expect(page.locator('#detail-section')).toBeHidden();},{expectedConsole:true});
  await runCase('case-reader-cannot-command',async page=>{await c.control('reset','POST');await c.control('role?who=reader','POST');await navigate(page);await expect(page.locator('#new-case')).toBeDisabled();assert.equal((await c.control()).commands,0);});
  await c.dispose();
 }
}catch(error){blocked=String(error).includes('ERR_BLOCKED_BY_ADMINISTRATOR');results.push({name:'harness',passed:false,error:String(error),blockedByAdministrator:blocked});}
finally{
 save();await browser?.close();
 for(const child of processes){child.kill('SIGTERM');await new Promise(resolve=>{if(child.exitCode!==null)return resolve();const timer=setTimeout(()=>{child.kill('SIGKILL');resolve();},5000);child.once('exit',()=>{clearTimeout(timer);resolve();});});}
 for(const stream of streams)stream.end();rmSync(temporary,{recursive:true,force:true});
}
console.log(JSON.stringify({passed:results.filter(x=>x.passed).length,failed:results.filter(x=>!x.passed).length,blocked,report:join(out,'browser-results.json')}));
process.exitCode=blocked?2:results.length===19&&results.every(x=>x.passed)?0:1;
