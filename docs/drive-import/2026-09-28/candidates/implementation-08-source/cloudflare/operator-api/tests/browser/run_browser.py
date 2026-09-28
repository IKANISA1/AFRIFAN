#!/usr/bin/env python3
"""Run the exact gateway/UI against isolated SQLite and synthetic Access/R2.
Requires Python Playwright, Chromium and openssl already installed. No downloads.
The Browser plugin is not available in this session; regular Playwright is used.
"""
from pathlib import Path
import argparse,json,os,subprocess,tempfile,time
from playwright.sync_api import sync_playwright,expect

ROOT=Path(__file__).resolve().parents[4]
def main():
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--results',type=Path,required=True);parser.add_argument('--chromium',default='/usr/bin/chromium');a=parser.parse_args()
 a.results.mkdir(parents=True,exist_ok=True);results=[];console_by_case={}
 with tempfile.TemporaryDirectory(prefix='africlub-browser-') as d:
  key=Path(d)/'key.pem';cert=Path(d)/'cert.pem'
  subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-keyout',str(key),'-out',str(cert),'-days','1','-nodes','-subj','/CN=localhost','-addext','subjectAltName=IP:127.0.0.1'],check=True,capture_output=True)
  stderr=open(a.results/'server-stderr.log','w')
  process=subprocess.Popen(['node',str(Path(__file__).with_name('server.mjs')),str(key),str(cert)],stdout=subprocess.PIPE,stderr=stderr,text=True,env={**os.environ,'AFRICLUB_SYNTHETIC_UI_TEST':'1'})
  try:
   line=process.stdout.readline();assert line,'Synthetic server did not start';settings=json.loads(line);origin=settings['origin']
   with sync_playwright() as p:
    browser=p.chromium.launch(executable_path=a.chromium,headless=True,args=['--no-sandbox'])
    api=p.request.new_context(ignore_https_errors=True,extra_http_headers={'Authorization':'Bearer '+settings['control']})
    def state():return api.get(origin+'/__test/state').json()
    def reset(mode='normal'):assert api.post(origin+'/__test/reset?mode='+mode).ok
    def start(width=1280,height=900):
     ctx=browser.new_context(ignore_https_errors=True,viewport={'width':width,'height':height},reduced_motion='reduce')
     page=ctx.new_page();return ctx,page
    def load(page):
     page.goto(origin+'/operator/clubs/24/public-source');expect(page.locator('#status')).to_have_text('Choose a snapshot to inspect.');assert page.title()=='Content publication · AFRICLUB'
    def review(page):
     page.locator('#candidates button').first.click();expect(page.locator('#candidate-section')).to_be_visible();page.locator('#evidence').fill('editorial:synthetic-browser')
     page.locator('#review').click();expect(page.locator('#status')).to_have_text('Verification passed. Nothing has been published.');assert state()['publications']==0
    def confirm(page):
     phrase=page.locator('#confirmation-phrase').inner_text();page.locator('#acknowledge').check();page.locator('#confirmation').fill(phrase);expect(page.locator('#publish')).to_be_enabled();page.locator('#publish').click()
    def case(name,fn,mode='normal',width=1280,height=900,expected_console=False):
     try:reset(mode)
     except Exception as e:
      results.append({'name':name,'passed':False,'error':'Fixture reset failed: '+str(e)});return
     ctx,page=start(width,height);logs=[];errors=[]
     page.on('console',lambda m:logs.append({'level':m.type,'text':m.text}) if m.type in ('warning','error') else None)
     page.on('pageerror',lambda e:errors.append(str(e)))
     try:
      fn(page,ctx);assert not errors,errors
      if not expected_console:assert not logs,logs
      results.append({'name':name,'passed':True,'viewport':[width,height],'console_errors':logs,'page_errors':errors})
     except Exception as e:
      results.append({'name':name,'passed':False,'error':str(e),'console':logs,'page_errors':errors});page.screenshot(path=str(a.results/(name+'-failed.png')),full_page=True)
     finally:
      ctx.close();(a.results/'browser-progress.json').write_text(json.dumps(results,indent=2)+'\n')
    def desktop(page,ctx):
     load(page);assert state()['reviews']==0;page.screenshot(path=str(a.results/'operator-desktop-candidates.png'),full_page=True)
     review(page);expect(page.locator('#publish')).to_be_disabled();page.locator('#preview-load').click();expect(page.locator('#preview')).to_contain_text('Synthetic club training update')
     assert page.locator('#preview img').count()==0
     assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
     page.screenshot(path=str(a.results/'operator-desktop-review.png'),full_page=True)
     confirm(page);expect(page.locator('#receipt-section')).to_be_visible();assert state()['publications']==1 and state()['audit']==1
     page.screenshot(path=str(a.results/'operator-desktop-receipt.png'),full_page=True);page.reload();expect(page.locator('#receipt-section')).to_be_visible();assert state()['publications']==1
    case('desktop-complete-flow',desktop)
    def mobile(page,ctx):
     load(page);review(page);page.locator('#preview-load').click();expect(page.locator('#preview')).to_contain_text('Synthetic club training update')
     assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
     for id in ['evidence','confirmation','publish','preview-route']:
      box=page.locator('#'+id).bounding_box()
      if box:assert box['x']>=-1 and box['x']+box['width']<=page.viewport_size['width']+1,(id,box)
     page.screenshot(path=str(a.results/f"operator-mobile-{page.viewport_size['width']}.png"),full_page=True)
    case('mobile-390',mobile,width=390,height=844);case('compact-320',mobile,width=320,height=740)
    def unknown(page,ctx):
     load(page);review(page);confirm(page);expect(page.locator('#recovery-note')).to_be_visible();expect(page.locator('#status')).to_have_text('Publication outcome requires verification.')
     assert state()['publications']==1;assert page.locator('#reset').is_hidden();page.screenshot(path=str(a.results/'operator-unknown-outcome.png'),full_page=True)
     # Reload never auto-posts a confirmation, even after a response was lost.
     writes=[];page.on('request',lambda r:writes.append(r.url) if r.method=='POST' else None)
     page.reload();expect(page.locator('#receipt-section')).to_be_visible();assert writes==[],writes;assert state()['publications']==1
    case('lost-response-reload-recovery',unknown,mode='loss',expected_console=True)
    def expiry(page,ctx):
     load(page);review(page);api.post(origin+'/__test/expire');page.locator('#check-result').click();expect(page.locator('#status')).to_have_text('The review has expired.');expect(page.locator('#publish')).to_be_disabled();assert state()['publications']==0
    case('expired-review',expiry)
    def revoke(page,ctx):
     load(page);review(page);api.post(origin+'/__test/revoke');confirm(page);expect(page.locator('#error')).to_contain_text('permission');assert state()['publications']==0
    case('revoked-permission',revoke,expected_console=True)
    def empty(page,ctx):
     load(page);expect(page.locator('#candidates')).to_contain_text('No reviewable snapshots');assert state()['reviews']==0;page.screenshot(path=str(a.results/'operator-empty.png'),full_page=True)
    case('empty-imports',empty,mode='empty')
    def markup(page,ctx):
     load(page);review(page);page.locator('#preview-load').click();expect(page.locator('#preview')).to_contain_text('<img src=x');assert not page.evaluate('Boolean(window.injected)');assert page.locator('#preview img').count()==0
    case('source-markup-not-executed',markup,mode='markup')
    def read_only(page,ctx):
     load(page);review(page);page.locator('#acknowledge').check();page.locator('#confirmation').fill(page.locator('#confirmation-phrase').inner_text());expect(page.locator('#publish')).to_be_disabled();assert state()['publications']==0
    case('review-only-operator',read_only,mode='review-only')
    def storage_fail(page,ctx):
     page.add_init_script("Storage.prototype.setItem=function(){throw new DOMException('Denied','SecurityError')}")
     page.goto(origin+'/operator/clubs/24/public-source');expect(page.locator('#error')).to_contain_text('durable recovery');page.locator('#candidates button').first.click();expect(page.locator('#review')).to_be_disabled();assert state()['reviews']==0
    case('storage-unavailable',storage_fail)
    def keyboard(page,ctx):
     load(page);page.keyboard.press('Tab');expect(page.locator('.skip-link')).to_be_focused();page.keyboard.press('Enter');assert page.evaluate('location.hash')=='#main'
     review(page);expect(page.locator('#review-heading')).to_be_focused()
    case('keyboard-focus-and-skip',keyboard)
    def tabs(page,ctx):
     load(page);review(page);second=ctx.new_page();load_url=origin+'/operator/clubs/24/public-source';second.goto(load_url);expect(second.locator('#review-section')).to_be_visible();assert state()['reviews']==1
     # Acquire the origin-scoped Web Lock in one real tab; the other cannot write.
     page.evaluate("""() => {const k=Object.keys(localStorage).find(k=>k.startsWith('africlub:public-source:v1:'));window.releaseLock=null;window.lockReady=false;navigator.locks.request(k,async()=>{window.lockReady=true;await new Promise(r=>window.releaseLock=r)})}""")
     page.wait_for_function('window.lockReady');confirm(second);expect(second.locator('#error')).to_contain_text('Another tab');assert state()['publications']==0;page.evaluate('window.releaseLock()');second.close()
    case('real-cross-tab-lock',tabs)
    def zoom(page,ctx):
     load(page);review(page);page.evaluate("document.documentElement.style.zoom='2'");assert page.evaluate('document.documentElement.scrollWidth<=innerWidth');page.screenshot(path=str(a.results/'operator-200-percent-zoom.png'),full_page=True)
    case('200-percent-page-zoom',zoom,width=1440,height=1000)
    browser_version=browser.version;api.dispose();browser.close()
   report={'scope':'Exact gateway and browser UI; synthetic Access/RPC/R2 and genuine local SQLite; not Cloudflare runtime','browser_plugin':'not available; regular Python Playwright','browser':browser_version,'cases':results,'passed':sum(x['passed'] for x in results),'failed':sum(not x['passed'] for x in results),'remote_calls':False}
   (a.results/'browser-results.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps({'passed':report['passed'],'failed':report['failed']}));return 0 if not report['failed'] else 1
  finally:
   process.terminate()
   try:process.wait(timeout=5)
   except subprocess.TimeoutExpired:process.kill();process.wait()
   stderr.close()
if __name__=='__main__':raise SystemExit(main())
