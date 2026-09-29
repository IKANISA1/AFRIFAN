/** Controlled, real Chromium rendering of the production portal/client/controller/CSS.
 * Run with the repository's pinned Node 22; no package/configuration changes or live API.
 * Synthetic API responses are intercepted before the loopback server. All other origins
 * are denied. Screenshots and detailed reports stay in the ignored web/tmp directory.
 * This is not Next/Workers, cookie cryptography, provider, DNS, or release acceptance.
 */
import assert from 'node:assert/strict';
import {createHash,randomUUID} from 'node:crypto';
import {readFileSync,writeFileSync,mkdirSync,mkdtempSync,rmSync} from 'node:fs';
import {createServer} from 'node:https';
import {tmpdir} from 'node:os';
import {join,resolve,basename,relative} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import {createRequire} from 'node:module';

assert.equal(process.version,'v22.23.2','Use the reviewed Node v22.23.2 runtime.');
const require=createRequire(import.meta.url),web=resolve(fileURLToPath(new URL('..',import.meta.url)));
const repo=resolve(web,'../../..');
const {build}=require('esbuild'),{chromium,devices,expect}=require('@playwright/test');
const AxeBuilder=require('@axe-core/playwright').default;
const postcss=require('postcss'),tailwind=require('@tailwindcss/postcss');
const output=join(web,'tmp','browser-portal-controlled-'+new Date().toISOString().replace(/[:.]/g,'-')+'-'+randomUUID().slice(0,8));
mkdirSync(output,{recursive:true});
const ignored=spawnSync('git',['check-ignore',output],{cwd:repo,encoding:'utf8'});
assert.equal(ignored.status,0,'Controlled private evidence must remain Git ignored.');
const scratch=mkdtempSync(join(tmpdir(),'africlub-browser-portal-render-'));
const sourcePaths=[
 'apps/rayon_sports/web/src/components/browser-membership-portal.tsx',
 'apps/rayon_sports/web/src/components/browser-membership-portal.module.css',
 'apps/rayon_sports/web/src/app/globals.css',
 'apps/rayon_sports/web/src/components/member-portal.css','apps/rayon_sports/web/src/components/home-blue-wall.css',
 'apps/rayon_sports/web/src/ui-kit/theme.css','apps/rayon_sports/web/src/ui-kit/tokens.css',
 'apps/rayon_sports/web/public/sw.js',
 'cloudflare/supporter-browser-api/client.ts','cloudflare/supporter-browser-api/portal-controller.ts',
 'cloudflare/supporter-browser-api/browser-platform.ts',
 'apps/rayon_sports/web/e2e/fixtures/browser-portal-controlled-entry.tsx',
 'apps/rayon_sports/web/scripts/browser-portal-controlled-qa.mjs'
];
const sha=bytes=>createHash('sha256').update(bytes).digest('hex');
const before=sourcePaths.map(path=>({path,sha256:sha(readFileSync(join(repo,path)))}));
const cert=spawnSync('/usr/bin/openssl',['req','-x509','-newkey','rsa:2048','-nodes','-days','1',
 '-keyout',join(scratch,'key.pem'),'-out',join(scratch,'cert.pem'),'-subj','/CN=127.0.0.1'],{encoding:'utf8'});
assert.equal(cert.status,0,'Could not create temporary loopback HTTPS certificate.');
const bundle=await build({entryPoints:[join(web,'e2e/fixtures/browser-portal-controlled-entry.tsx')],
 absWorkingDir:web,bundle:true,write:false,outdir:scratch,entryNames:'portal',platform:'browser',format:'esm',
 jsx:'automatic',define:{'process.env.NODE_ENV':'"production"'},logLevel:'silent'});
const globals=await postcss([tailwind({base:web})]).process(readFileSync(join(web,'src/app/globals.css'),'utf8'),
 {from:join(web,'src/app/globals.css'),to:join(scratch,'globals.css')});
const assets=new Map(bundle.outputFiles.map(file=>['/'+basename(file.path),Buffer.from(file.contents)]));
assets.set('/globals.css',Buffer.from(globals.css));
const html=Buffer.from('<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Controlled synthetic membership QA</title><link rel="stylesheet" href="/globals.css"><link rel="stylesheet" href="/portal.css"></head><body><div id="root"></div><script type="module" src="/portal.js"></script></body></html>');
const blank=Buffer.from('<!doctype html><html lang="en"><head><title>Controlled blank page</title></head><body><main>Controlled local browser setup</main></body></html>');
const csp="default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'self'; font-src 'self'; img-src 'self' data:; worker-src 'self'; object-src 'none'; base-uri 'self'";
const serverUnexpected=[];
const server=createServer({key:readFileSync(join(scratch,'key.pem')),cert:readFileSync(join(scratch,'cert.pem'))},(req,res)=>{
 const pathname=new URL(req.url,'https://127.0.0.1').pathname;
 const headers={'cache-control':'no-store','content-security-policy':csp,'x-content-type-options':'nosniff'};
 if(pathname.startsWith('/v1/')){serverUnexpected.push(pathname);res.writeHead(500,headers);res.end('Synthetic API interception required');return;}
 let bytes=assets.get(pathname),type=pathname.endsWith('.css')?'text/css':'text/javascript';
 if(pathname==='/'){bytes=html;type='text/html';}
 if(['/blank','/offline','/admin-offline'].includes(pathname)){bytes=blank;type='text/html';}
 if(pathname==='/sw.js'){bytes=readFileSync(join(web,'public/sw.js'));type='text/javascript';}
 if(pathname==='/reject-sw.js'){bytes=Buffer.from("self.addEventListener('install',e=>e.waitUntil(self.skipWaiting()));self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));");type='text/javascript';}
 if(pathname==='/manifest.webmanifest'){bytes=Buffer.from('{}');type='application/manifest+json';}
 if(pathname==='/brand-mark.svg'){bytes=Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><title>Synthetic fixture</title><rect width="32" height="32"/></svg>');type='image/svg+xml';}
 if(pathname==='/favicon.ico'){res.writeHead(204,headers);res.end();return;}
 if(!bytes){serverUnexpected.push(pathname);res.writeHead(404,headers);res.end('Not found');return;}
 res.writeHead(200,{...headers,'content-type':type,'service-worker-allowed':'/'});res.end(bytes);
});
await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const origin='https://127.0.0.1:'+server.address().port;
const ids={user:'99590000-0000-4000-8000-000000000100',session:'99590000-0000-4000-8000-000000000200',
 membership:'99590000-0000-4000-8000-000000000300',order:'99590000-0000-4000-8000-000000000400',
 challenge:'99590000-0000-4000-8000-000000000500',allocation:'99590000-0000-4000-8000-000000000600'};
const phone='+250700000001',code='123456',csrf='a'.repeat(64),bootCsrf='b'.repeat(64);
const checks=[],evidence=[],denied=[],errors=[];
let browser;
function synthetic(){return {signedIn:true,clubId:24,checkoutEnabled:true,loseCheckout:false,loseChallenge:false,
 rotateLost:false,logoutHold:null,sessionHold:null,checkoutKey:null,challengeKeys:[],rotateKeys:[],writes:[],reads:[],authenticatedAt:Date.now()-1000};}
const sessionView=s=>({schemaVersion:1,clubId:s.clubId,userId:ids.user,sessionId:ids.session,authenticatedAt:s.authenticatedAt,
 expiresAt:Date.now()+300000,absoluteExpiresAt:Date.now()+3600000,role:'supporter',phoneVerified:true,csrfToken:csrf});
const prepared=s=>({schemaVersion:1,clubId:s.clubId,requestId:s.checkoutKey,orderId:ids.order,tier:'gold',reused:false,paymentVerified:false,membershipActivated:false});
async function replies(route,state,page){
 const request=route.request(),url=new URL(request.url()),path=url.pathname,method=request.method();
 const key=request.headers()['idempotency-key'];
 const send=async(value,status=200)=>route.fulfill({status,headers:{'content-type':'application/json','cache-control':'private, no-store'},body:JSON.stringify(value)});
 if(method==='POST')state.writes.push({path,key});else state.reads.push(path);
 if(path==='/v1/browser/session'){
  if(state.sessionHold)await state.sessionHold;
  return state.signedIn?send(sessionView(state)):send({schemaVersion:1,error:'unauthenticated'},401);
 }
 if(path==='/v1/browser/session/start')return send({schemaVersion:1,clubId:state.clubId,csrfToken:bootCsrf,expiresAt:Date.now()+60000});
 if(path==='/v1/browser/session/challenge'){
  assert.equal(request.postDataJSON().phone,phone);assert.match(key,/^[0-9a-f-]{36}$/);state.challengeKeys.push(key);
  if(state.loseChallenge){state.loseChallenge=false;return send({schemaVersion:1,error:'identity_outcome_unknown',outcome:'unknown',requestId:key},503);}
  return send({schemaVersion:1,clubId:state.clubId,challengeId:ids.challenge,expiresAt:Date.now()+60000,delivery:'queued_or_pending'});
 }
 if(path==='/v1/browser/session/verify'){
  assert.deepEqual(request.postDataJSON(),{challengeId:ids.challenge,code});state.signedIn=true;return send(sessionView(state));
 }
 if(path==='/v1/browser/session/rotate'){
  state.rotateKeys.push(key);if(state.rotateLost){state.rotateLost=false;return send({schemaVersion:1,error:'identity_outcome_unknown',outcome:'unknown',requestId:key},503);}
  return send(sessionView(state));
 }
 if(path==='/v1/browser/session/logout'){
  if(state.logoutHold)await state.logoutHold;state.signedIn=false;return send({schemaVersion:1,loggedOut:true,scope:'current'});
 }
 if(path==='/v1/browser/membership/status')return send({schemaVersion:1,clubId:state.clubId,userId:ids.user,observedAt:Date.now(),historical:false,currentStatus:'active',isActive:true,
  membership:{membershipId:ids.membership,tier:'gold',recordedStatus:'active',paymentStatus:'verified',renewedAt:Date.now()-1000,expiresAt:Date.now()+300000}});
 if(path==='/v1/browser/membership/offers')return state.checkoutEnabled?send({schemaVersion:1,clubId:state.clubId,observedAt:Date.now(),preparationOnly:true,offers:[{tier:'gold',amount:10000,currency:'RWF',country:'RW'}]}):send({schemaVersion:1,error:'browser_disabled'},503);
 if(path==='/v1/browser/membership/checkouts'){
  assert.equal(request.headers()['x-africlub-browser-session'],ids.session);assert.equal(request.headers()['x-africlub-csrf'],csrf);
  const records=await page.evaluate(()=>Object.values(localStorage).filter(value=>value.includes('"savedAt"')).map(value=>JSON.parse(value)));
  assert.equal(records.length,1);assert.equal(records[0].requestId,key);assert.equal(records[0].clubId,state.clubId);
  if(state.checkoutKey)assert.equal(key,state.checkoutKey);state.checkoutKey=key;
  if(state.loseCheckout)return send({schemaVersion:1,error:'checkout_outcome_unknown',outcome:'unknown',requestId:key},503);
  return send(prepared(state));
 }
 if(path==='/v1/browser/membership/operations/'+state.checkoutKey)return send({schemaVersion:1,clubId:state.clubId,requestId:state.checkoutKey,observedAt:Date.now(),found:false,mayRetryWithNewKey:false,result:null});
 if(path==='/v1/browser/membership/checkouts/'+ids.order)return send({schemaVersion:1,clubId:state.clubId,orderId:ids.order,tier:'gold',status:'pending_current',paymentEvidenceAllocated:false,observedAt:Date.now(),expiresAt:Date.now()+300000,
  paymentInstruction:{amount:10000,currency:'RWF',country:'RW',provider:'synthetic',recipient:'123456',ussdCode:'*182*8*1*123456*10000#'}});
 if(path==='/v1/browser/membership/history')return send({schemaVersion:1,clubId:state.clubId,userId:ids.user,observedAt:Date.now(),scope:'membership_allocations',historical:true,snapshot:false,items:[],nextCursor:null});
 throw new Error('Unexpected synthetic API path '+path);
}
async function setup(project,state=synthetic()){
 const settings=project==='desktop'?{viewport:{width:1440,height:900}}:{...devices['Pixel 7']};
 const context=await browser.newContext({...settings,ignoreHTTPSErrors:true,reducedMotion:'reduce'});
 context.setDefaultTimeout(10000);
 const page=await context.newPage();
 page.on('pageerror',error=>errors.push({project,text:error.message}));
 page.on('console',msg=>{if(msg.type()==='error'&&!msg.location().url?.includes('/v1/browser/'))errors.push({project,text:msg.text()});});
 await context.route('**/*',async route=>{
  const url=new URL(route.request().url());
  if(url.origin!==origin){denied.push({project,origin:url.origin});await route.abort('blockedbyclient');return;}
  if(url.pathname.startsWith('/v1/browser/'))return replies(route,state,page);
  return route.continue();
 });
 return {context,page,state};
}
const visibleMember=async page=>expect(page.getByText(ids.membership,{exact:true})).toBeVisible();
const noPrivate=async page=>expect(page.getByText(ids.membership,{exact:true})).toHaveCount(0);
async function screenshot(page,project,name){
 const file=project+'-'+name+'.png',path=join(output,file);await page.screenshot({path,fullPage:true});
 evidence.push({file,sha256:sha(readFileSync(path)),privateSynthetic:true});
}
async function privacy(page){
 const values=await page.evaluate(()=>Object.values(localStorage).join('\n'));
 for(const text of [phone,code,csrf,bootCsrf,'csrfToken','sessionCookie','accessToken','refreshToken'])assert(!values.includes(text),'Credential/OTP leaked to recovery metadata');
}
async function targets(page){
 const controls=await page.locator('main button:visible,main a:visible,main input:visible').evaluateAll(nodes=>nodes.map(node=>{
  const target=node instanceof HTMLInputElement&&node.type==='checkbox'?node.closest('label'):node;
  const r=target.getBoundingClientRect();return {tag:node.tagName,type:node.getAttribute('type'),height:r.height,width:r.width};
 }));
 assert(controls.length>0);for(const r of controls)assert(r.height>=47.5&&r.width>=47.5,'Interactive target below 48 CSS px: '+JSON.stringify(r));
 return controls.length;
}
async function layout(page){
 const box=await page.evaluate(()=>({width:document.documentElement.clientWidth,scroll:document.documentElement.scrollWidth,
  clipped:[...document.querySelectorAll('main button,main input,main article,main h1,main h2,main dd')].filter(node=>{
   const r=node.getBoundingClientRect();return r.width>0&&(r.left<-.5||r.right>document.documentElement.clientWidth+.5);
  }).map(node=>node.tagName)}));
 assert(box.scroll<=box.width+1,'Horizontal page overflow');assert.deepEqual(box.clipped,[],'Clipped primary content');return box;
}
async function axe(page){
 const result=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']).analyze();
 assert.deepEqual(result.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.length})),[],'Axe accessibility violations');
 return {rulesPassed:result.passes.length,incomplete:result.incomplete.map(v=>({id:v.id,nodes:v.nodes.length}))};
}
async function run(project,name,fn){
 const f=await setup(project);const start=Date.now();let timer;
 try{const detail=await Promise.race([fn(f),new Promise((_,reject)=>{timer=setTimeout(()=>reject(Error('Controlled rendered check exceeded 30 seconds')),30000);})]);
  checks.push({project,name,status:'passed',durationMs:Date.now()-start,...detail});}
 catch(error){checks.push({project,name,status:'failed',durationMs:Date.now()-start,error:error.message});try{await screenshot(f.page,project,name+'-failure');}catch{}}
 finally{clearTimeout(timer);await f.context.close();}
 process.stdout.write(project+' '+name+' '+checks.at(-1).status+'\n');
}
try{
 browser=await chromium.launch({channel:'chromium',headless:true,args:['--disable-features=ViewTransitionOnNavigation',
  '--ignore-certificate-errors','--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1']});
 for(const project of ['desktop','mobile']){
  await run(project,'render-css-keyboard-a11y',async({page,state})=>{
   state.signedIn=false;await page.goto(origin);await expect(page.getByLabel('Phone number, including country code')).toBeVisible();
   assert.equal(await page.title(),'Controlled synthetic membership QA');assert.equal(state.writes.length,0);
   const style=await page.locator('main').evaluate(node=>({background:getComputedStyle(document.body).backgroundColor,foreground:getComputedStyle(node).color,font:getComputedStyle(document.body).fontFamily}));
   assert.equal(style.background,'rgb(0, 0, 0)');assert.equal(style.foreground,'rgb(244, 244, 244)');
   await page.keyboard.press('Tab');await expect(page.getByRole('button',{name:'Check session and refresh'})).toBeFocused();
   const outline=await page.getByRole('button',{name:'Check session and refresh'}).evaluate(node=>getComputedStyle(node).outlineWidth);assert.equal(outline,'3px');
   await page.keyboard.press('Tab');await expect(page.getByRole('link',{name:'Help and support'})).toBeFocused();
   await page.keyboard.press('Tab');await expect(page.getByLabel('Phone number, including country code')).toBeFocused();
   await page.keyboard.type(phone);await page.keyboard.press('Tab');await expect(page.getByRole('button',{name:'Request sign-in code'})).toBeFocused();
   const touchTargets=await targets(page),accessibility=await axe(page);await layout(page);await screenshot(page,project,'signed-out');
   return {touchTargets,accessibility,productionTokens:style};
  });
  await run(project,'explicit-sign-in-and-original-key-retry',async({page,state})=>{
   state.signedIn=false;state.loseChallenge=true;await page.goto(origin);const phoneInput=page.getByLabel('Phone number, including country code');await expect(phoneInput).toBeVisible();
   await phoneInput.fill(phone);await phoneInput.press('Enter');await expect(page.getByRole('button',{name:'Retry the same sign-in request'})).toBeVisible();
   await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true})));
   await page.getByRole('button',{name:'Check session and refresh'}).click();await expect(page.getByRole('button',{name:'Retry the same sign-in request'})).toBeVisible();
   await page.getByRole('button',{name:'Retry the same sign-in request'}).click();await expect(page.getByLabel('One-time code')).toBeVisible();
   assert.equal(state.challengeKeys.length,2);assert.equal(state.challengeKeys[0],state.challengeKeys[1]);
   await page.getByLabel('One-time code').fill(code);await page.getByLabel('One-time code').press('Enter');await visibleMember(page);
   await privacy(page);await screenshot(page,project,'signed-in');return {challengeRequests:2,sameOperationKey:true,credentialPersistence:false};
  });
  await run(project,'checkout-review-unknown-recovery',async({page,state})=>{
   state.loseCheckout=true;await page.goto(origin);await visibleMember(page);assert.equal(state.writes.length,0);
   await page.getByRole('button',{name:'Review gold'}).click();await expect(page.getByRole('heading',{name:'Review checkout preparation'})).toBeVisible();assert.equal(state.writes.length,0);
   await page.getByRole('button',{name:'Confirm preparation only'}).click();const retry=page.getByRole('button',{name:'Retry original checkout request'});await expect(retry).toBeVisible();await expect(retry).toBeDisabled();
   await expect(page.getByRole('status')).toContainText('outcome is unknown');const key=state.checkoutKey;await privacy(page);
   const pendingTouchTargets=await targets(page),pendingAccessibility=await axe(page);
   await page.getByRole('button',{name:'Check original result'}).click();await expect(page.getByRole('status')).toContainText('does not prove failure');assert.equal(state.checkoutKey,key);assert.equal(state.writes.length,1);
   state.loseCheckout=false;const confirmation=page.getByRole('checkbox');await confirmation.focus();await page.keyboard.press('Space');await expect(retry).toBeEnabled();await retry.click();
   await expect(page.getByText(ids.order,{exact:true})).toBeVisible();assert.equal(state.writes.length,2);assert.equal(state.writes[0].key,state.writes[1].key);
   await expect(page.getByText('No payment confirmation is shown.')).toBeVisible();assert.equal(await page.locator('a[href^="tel:"],a[href^="ussd:"]').count(),0);
   await privacy(page);const touchTargets=await targets(page);await layout(page);await screenshot(page,project,'checkout');return {sameOperationKey:true,explicitRetryConfirmation:true,touchTargets,pendingTouchTargets,pendingAccessibility,automaticPayment:false};
  });
  await run(project,'lifecycle-offline-storage-back-forward',async({page,context,state})=>{
   await page.goto(origin);await visibleMember(page);const writes=state.writes.length;
   await context.setOffline(true);await noPrivate(page);await context.setOffline(false);
   await page.getByRole('button',{name:'Check session and refresh'}).click();await visibleMember(page);
   await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pagehide')));await noPrivate(page);
   await page.getByRole('button',{name:'Check session and refresh'}).click();await visibleMember(page);
   await page.evaluate(()=>{Object.defineProperty(document,'visibilityState',{value:'hidden',configurable:true});document.dispatchEvent(new Event('visibilitychange'));});await noPrivate(page);
   await page.evaluate(()=>{Object.defineProperty(document,'visibilityState',{value:'visible',configurable:true});document.dispatchEvent(new Event('visibilitychange'));});
   await page.getByRole('button',{name:'Check session and refresh'}).click();await visibleMember(page);
   await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true})));await noPrivate(page);
   await page.getByRole('button',{name:'Check session and refresh'}).click();await visibleMember(page);
   const other=await context.newPage();await other.goto(origin+'/blank');await other.evaluate(()=>localStorage.setItem('africlub-browser-session-change:v1',crypto.randomUUID()));await noPrivate(page);
   await other.close();await page.bringToFront();await page.getByRole('button',{name:'Check session and refresh'}).click();await visibleMember(page);
   assert.equal(state.writes.length,writes);await screenshot(page,project,'lifecycle-restored');return {offlineConceals:true,realCrossTabStorageConceals:true,syntheticPageHideConceals:true,syntheticHiddenVisibilityConceals:true,syntheticPersistedPageShowConceals:true,businessWrites:0};
  });
  await run(project,'tenant-change-and-delayed-read-unmount',async({page,state})=>{
   await page.goto(origin);await visibleMember(page);let release;state.sessionHold=new Promise(resolve=>{release=resolve;});state.clubId=26;
   await page.evaluate(()=>window.__AFRICLUB_CONTROLLED_FIXTURE__.setClub(26));await expect(page.getByText('Synthetic Club B · Supporter membership')).toBeVisible();await noPrivate(page);
   assert.equal(state.writes.length,0);await screenshot(page,project,'tenant-change-pending');
   await page.evaluate(()=>window.__AFRICLUB_CONTROLLED_FIXTURE__.unmount());release();await expect(page.locator('main')).toHaveCount(0);return {previousTenantConcealed:true,lateReadAfterUnmountConcealed:true,businessWrites:0};
  });
  await run(project,'session-retry-and-immediate-logout-concealment',async({page,state})=>{
   await page.goto(origin);await visibleMember(page);state.rotateLost=true;await page.getByRole('button',{name:'Renew browser session'}).click();await expect(page.getByRole('button',{name:'Retry the same session request'})).toBeVisible();
   await page.evaluate(()=>window.dispatchEvent(new PageTransitionEvent('pageshow',{persisted:true})));await page.getByRole('button',{name:'Retry the same session request'}).click();await visibleMember(page);
   assert.equal(state.rotateKeys.length,2);assert.equal(state.rotateKeys[0],state.rotateKeys[1]);
   let release;state.logoutHold=new Promise(resolve=>{release=resolve;});await page.getByRole('button',{name:'Sign out'}).click();await noPrivate(page);release();
   await expect(page.getByLabel('Phone number, including country code')).toBeVisible();await privacy(page);return {sameRotationKey:true,logoutConcealsBeforeResponse:true};
  });
  await run(project,'200-percent-equivalent-viewport-and-text',async({page})=>{
   await page.goto(origin);await visibleMember(page);
   if(project==='desktop')await page.setViewportSize({width:720,height:450});else await page.setViewportSize({width:320,height:640});
   await page.evaluate(()=>document.documentElement.style.fontSize='200%');
   const measurement=await layout(page),touchTargets=await targets(page),accessibility=await axe(page);await screenshot(page,project,'large-text');
   return {measurement,touchTargets,accessibility,textScalePercent:200,desktopLayoutViewportEquivalentZoomPercent:project==='desktop'?200:null,nativeBrowserZoom:false};
  });
  await run(project,'actual-service-worker-private-cache-purge',async({page,state})=>{
   await page.goto(origin+'/blank');await page.evaluate(async()=>{
    const cache=await caches.open('gikundiro-pages-v8');await cache.put('/membership',new Response('SYNTHETIC-PRIVATE-CACHE'));
    const other=await caches.open('another-app');await other.put('/sentinel',new Response('keep'));
    localStorage.setItem('controlled-recovery-sentinel','keep');await navigator.serviceWorker.register('/sw.js');await navigator.serviceWorker.ready;
    if(!navigator.serviceWorker.controller)await new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true}));
   });
   await page.goto(origin);await visibleMember(page);
   const result=await page.evaluate(async()=>({keys:await caches.keys(),recovery:localStorage.getItem('controlled-recovery-sentinel')}));
   assert(!result.keys.some(key=>/^gikundiro-(pages|api)-v\d+$/.test(key)));assert(result.keys.includes('another-app'));assert.equal(result.recovery,'keep');assert.equal(state.writes.length,0);
   return {productionServiceWorker:true,privateDynamicCachesPurged:true,otherAppCachePreserved:true,recoveryStoragePreserved:true};
  });
  await run(project,'unsupported-worker-blocks-private-reads',async({page,state})=>{
   await page.goto(origin+'/blank');await page.evaluate(async()=>{
    await navigator.serviceWorker.register('/reject-sw.js');await navigator.serviceWorker.ready;
    if(!navigator.serviceWorker.controller)await new Promise(resolve=>navigator.serviceWorker.addEventListener('controllerchange',resolve,{once:true}));
   });
   await page.goto(origin);await expect(page.getByRole('status')).toContainText('site update is required',{timeout:5000});await noPrivate(page);assert.equal(state.reads.length,0);assert.equal(state.writes.length,0);
   return {unsupportedWorkerBlocks:true,apiCalls:0};
  });
 }
}finally{
 if(browser)await browser.close();await new Promise(resolve=>server.close(resolve));rmSync(scratch,{recursive:true,force:true});
 const after=sourcePaths.map(path=>({path,sha256:sha(readFileSync(join(repo,path)))}));
 const sourceStable=JSON.stringify(before)===JSON.stringify(after);
 const summary={schemaVersion:1,kind:'controlled_synthetic_browser_rendering',generatedAt:new Date().toISOString(),
  runtime:process.version,playwright:require('@playwright/test/package.json').version,browserPlugin:'unavailable',
  realProductionComponentClientControllerAndStyles:true,syntheticApiOnly:true,externalNetworkDenied:true,
  loopbackOnlySelfSignedHttps:true,certificateErrorsIgnoredInControlledBrowser:true,
  sourceStable,sourceHashes:after,projects:['desktop-chromium-1440x900','mobile-chromium-Pixel7'],
  passed:checks.filter(c=>c.status==='passed').length,failed:checks.filter(c=>c.status==='failed').length,
  browserErrors:errors.length,unexpectedServerRequests:serverUnexpected.length,externalRequests:denied.length,
  checks:checks.map(({error,...rest})=>({...rest,...(error?{failureDetail:'See the local ignored private-details.json'}: {})})),
  evidence:evidence.map(({file,sha256})=>({file,sha256,privacy:'synthetic IDs only; local ignored artifact'})),
  compiledAssetHashes:[...assets].map(([path,bytes])=>({path,sha256:sha(bytes),bytes:bytes.length})),
  limitations:['No Next rendering or middleware acceptance','No Workers/workerd service bindings or real cookie authentication',
   'No actual SMS/WhatsApp/payment provider calls','No DNS/TLS deployment, approved feature enablement, device/store or release acceptance',
   'Chromium desktop/mobile emulation only; no Safari/Firefox or physical devices','Uses system font fallback; Next font loader absent',
   '200% desktop layout viewport equivalence and 200% CSS text scaling, not native browser zoom',
   'Visibility/pagehide/persisted pageshow events simulated; no OS backgrounding or actual back-forward cache admission proof'],
  releaseAccepted:false,providersCalled:false,deploymentPerformed:false};
 writeFileSync(join(output,'public-summary.json'),JSON.stringify(summary,null,2)+'\n');
 writeFileSync(join(output,'private-details.json'),JSON.stringify({errors,serverUnexpected,denied,checks},null,2)+'\n');
 process.stdout.write(JSON.stringify({output:relative(repo,output),passed:summary.passed,failed:summary.failed,browserErrors:errors.length,unexpectedServerRequests:serverUnexpected.length,sourceStable})+'\n');
 if(summary.failed||errors.length||serverUnexpected.length||denied.length||!sourceStable)process.exitCode=1;
}
