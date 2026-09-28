#!/usr/bin/env python3
"""Loopback-only synthetic browser acceptance. No hosted Access/D1 assertions."""
import argparse,json,os,pathlib,subprocess,tempfile,ssl,urllib.request,uuid,shutil
from playwright.sync_api import sync_playwright,expect
p=argparse.ArgumentParser();p.add_argument('--output',required=True);args=p.parse_args();out=pathlib.Path(args.output);out.mkdir(parents=True,exist_ok=True)
results=[];server=None
with tempfile.TemporaryDirectory(prefix='africlub-browser-') as tmp:
 key=pathlib.Path(tmp)/'key.pem';cert=pathlib.Path(tmp)/'cert.pem'
 subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(key),'-out',str(cert),'-days','1','-subj','/CN=localhost'],check=True,capture_output=True)
 log=(out/'browser-server.log').open('w')
 server=subprocess.Popen(['node',str(pathlib.Path(__file__).with_name('server.mjs')),str(key),str(cert)],env={**os.environ,'AFRICLUB_SYNTHETIC_UI_TEST':'1'},stdout=subprocess.PIPE,stderr=log,text=True)
 try:
  launch=json.loads(server.stdout.readline());origin=launch['origin'];token=launch['control']
  def control(action='state',method='GET'):
   r=urllib.request.Request(origin+'/__test/'+action,method=method,headers={'authorization':'Bearer '+token})
   with urllib.request.urlopen(r,context=ssl._create_unverified_context(),timeout=5) as x:return json.load(x)
  def reset():return control('reset','POST')
  with sync_playwright() as pw:
   # Browser plugin was absent; use installed Chromium, not a new dependency.
   browser=pw.chromium.launch(executable_path=shutil.which('chromium'),headless=True,args=['--no-sandbox'])
   ctx=browser.new_context(ignore_https_errors=True,viewport={'width':1365,'height':900})
   page=ctx.new_page();console_errors=[];page.on('pageerror',lambda e:console_errors.append(str(e)))
   def navigate():
    page.goto(origin+'/operator/clubs/24/payment-exceptions');expect(page.locator('#role-context')).to_contain_text('Case');expect(page.locator('#status')).to_contain_text('Workspace updated')
   def open_case():
    page.get_by_role('button',name='Open a case',exact=True).click();page.locator('#order-id').fill(str(uuid.uuid4()));page.get_by_role('button',name='Review command',exact=True).click();expect(page.locator('#confirm-section')).to_be_visible();page.locator('#confirm-ack').check();page.get_by_role('button',name='Confirm case command',exact=True).click();expect(page.locator('#receipt-section')).to_be_visible()
   def action(name,digest=False):
    page.locator('#action').select_option(name)
    if(digest):page.locator('#evidence-digest').fill('d'*64)
    page.get_by_role('button',name='Review command',exact=True).click();page.locator('#confirm-ack').check();page.get_by_role('button',name='Confirm case command',exact=True).click();expect(page.locator('#receipt-section')).to_be_visible();expect(page.locator('#status')).to_contain_text('Workspace updated')
   reset();navigate();assert page.title()=='Payment case review · AFRICLUB';assert 'Resolve the uncertainty.' in page.locator('body').inner_text();assert control()['events']==0
   open_case();assert control()['events']==1;action('propose',True);assert control()['events']==2
   page.screenshot(path=str(out/'case-proposal-desktop.png'),full_page=True)
   results.append({'name':'maker opens and proposes through real UI/API/SQLite','passed':True})
   # A fresh browser context models a different authenticated checker.
   control('role?who=checker','POST');ctx.close();ctx=browser.new_context(ignore_https_errors=True,viewport={'width':1365,'height':900});page=ctx.new_page();page.on('pageerror',lambda e:console_errors.append(str(e)));navigate();page.locator('#case-list button').first.click();expect(page.locator('#case-details')).to_contain_text('awaiting_review');action('approve');assert control()['events']==3
   results.append({'name':'separate checker approves proposal','passed':True})
   control('role?who=maker','POST');ctx.close();ctx=browser.new_context(ignore_https_errors=True,viewport={'width':390,'height':844});page=ctx.new_page();page.on('pageerror',lambda e:console_errors.append(str(e)));navigate();page.locator('#case-list button').first.click();expect(page.locator('#case-details')).to_contain_text('reviewed');action('close',True);assert control()['cases'][0]['state']=='closed';action('reopen');assert control()['cases'][0]['state']=='investigating'
   page.screenshot(path=str(out/'case-review-mobile.png'),full_page=True);assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth')
   results.append({'name':'maker closes/reopens with mobile viewport and no horizontal overflow','passed':True})
   reset();ctx.clear_cookies();page.evaluate('localStorage.clear()');navigate();control('loss','POST');page.get_by_role('button',name='Open a case',exact=True).click();page.locator('#order-id').fill(str(uuid.uuid4()));page.get_by_role('button',name='Review command',exact=True).click();page.locator('#confirm-ack').check();page.get_by_role('button',name='Confirm case command',exact=True).click();expect(page.locator('#pending-section')).to_be_visible();expect(page.locator('#error')).to_be_visible();assert control()['events']==1
   navigate();assert control()['commands']==1;page.get_by_role('button',name='Check original result',exact=True).click();expect(page.locator('#receipt-section')).to_be_visible();expect(page.locator('#pending-section')).to_be_hidden();assert control()['commands']==1
   results.append({'name':'lost response + reload + read-only recovery without resend','passed':True})
   control('revoke','POST');page.get_by_role('button',name='Refresh access',exact=True).click();expect(page.locator('#error')).to_be_visible();expect(page.locator('#command-section')).to_be_hidden()
   results.append({'name':'revoked authority clears private case view and blocks commands','passed':True})
   assert not console_errors,console_errors
   results.append({'name':'no application page errors','passed':True})
   browser.close()
  report={'scope':'Synthetic local Access identity, real gateway and local SQLite; not Cloudflare D1 or hosted Access.','browserPlugin':'absent','browser':'installed Chromium via Playwright','origin':origin,'viewports':['1365x900','390x844'],'tests':results,'passed':len(results),'failed':0,'consolePageErrors':console_errors}
  (out/'browser-results.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
 except Exception as error:
  blocked='ERR_BLOCKED_BY_ADMINISTRATOR' in str(error)
  report={'scope':'Synthetic loopback browser fixture, not hosted Access/D1',
          'status':'blocked' if blocked else 'failed','browserPlugin':'absent',
          'passed':len(results),'failed':0 if blocked else 1,'tests':results,
          'reason':'navigation_blocked_by_administrator' if blocked else 'browser_validation_failed',
          'renderedAcceptance':False,'alternateTransportAttempted':False}
  (out/'browser-results.json').write_text(json.dumps(report,indent=2)+'\n')
  print(json.dumps(report,indent=2))
  raise SystemExit(2 if blocked else 1) from None
 finally:
  if server:server.terminate();server.wait(timeout=5)
  log.close()
