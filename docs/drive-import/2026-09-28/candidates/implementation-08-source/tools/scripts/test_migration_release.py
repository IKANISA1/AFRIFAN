import copy
import datetime as dt
import hashlib
import json
import pathlib
import tempfile
import unittest
from validate_migration_release import validate,template,CUTOVER_GATES,RETIRE_GATES
from build_migration_dispositions import build,SECTIONS

class ReleaseEvidenceTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=pathlib.Path(self.temp.name)
  (self.root/'evidence.txt').write_text('SYNTHETIC TEST EVIDENCE: not real production approval')
  self.artifact={'path':'evidence.txt','sha256':hashlib.sha256((self.root/'evidence.txt').read_bytes()).hexdigest()}
  self.now=dt.datetime.now(dt.timezone.utc);self.candidate='a'*40
 def ready(self,stage='cutover'):
  r=template(stage);r.update(candidateId=self.candidate,singleWriter=True,authoritativeWriter='supabase' if stage=='cutover' else 'cloudflare',cloudflareFinancialWritesStarted=stage=='retire')
  for g in r['gates']:g.update(passed=True,candidateId=self.candidate,observedAt=self.now.isoformat(),reviewer='synthetic:test',artifacts=[self.artifact.copy()])
  return r
 def check(self,r,stage='cutover'):return validate(r,self.root,self.candidate,stage,self.now)
 def test_template_blocks(self):self.assertTrue(self.check(template()))
 def test_complete_synthetic_package(self):self.assertEqual(self.check(self.ready()),[])
 def test_retirement_requires_extra_gates(self):
  r=self.ready('retire');self.assertEqual(self.check(r,'retire'),[]);r['gates'].pop();self.assertTrue(self.check(r,'retire'))
 def test_missing_gate(self):r=self.ready();r['gates'].pop();self.assertTrue(self.check(r))
 def test_duplicate_gate(self):r=self.ready();r['gates'].append(r['gates'][0]);self.assertTrue(self.check(r))
 def test_candidate_mismatch(self):r=self.ready();r['gates'][0]['candidateId']='b'*40;self.assertTrue(self.check(r))
 def test_stale(self):r=self.ready();r['gates'][0]['observedAt']=(self.now-dt.timedelta(days=2)).isoformat();self.assertTrue(self.check(r))
 def test_future(self):r=self.ready();r['gates'][0]['observedAt']=(self.now+dt.timedelta(hours=1)).isoformat();self.assertTrue(self.check(r))
 def test_naive_time(self):r=self.ready();r['gates'][0]['observedAt']='2026-09-26T00:00:00';self.assertTrue(self.check(r))
 def test_no_writer_proof(self):r=self.ready();r['singleWriter']=False;self.assertTrue(self.check(r))
 def test_after_target_financial_write(self):r=self.ready();r['cloudflareFinancialWritesStarted']=True;self.assertTrue(self.check(r))
 def test_changed_artifact(self):r=self.ready();(self.root/'evidence.txt').write_text('changed');self.assertTrue(self.check(r))
 def test_no_artifacts(self):r=self.ready();r['gates'][0]['artifacts']=[];self.assertTrue(self.check(r))
 def test_path_escape(self):r=self.ready();r['gates'][0]['artifacts'][0]['path']='../other';self.assertTrue(self.check(r))
 def test_symlink(self):
  (self.root/'alias').symlink_to(self.root/'evidence.txt');r=self.ready();r['gates'][0]['artifacts'][0]['path']='alias';self.assertTrue(self.check(r))
 def test_boolean_not_truthy_string(self):r=self.ready();r['gates'][0]['passed']='true';self.assertTrue(self.check(r))

class DispositionTests(unittest.TestCase):
 def fixture(self):
  remote={'project_ref':'synthetic-project','query_mode':'read_only','failures':{},'captured_at_utc':'2026-09-25T00:00:00Z','queries':{s:[] for s in SECTIONS}}
  remote['queries']['functions']=[{'schema':'public','name':'example','arguments':'id integer'},{'schema':'public','name':'example','arguments':'id text'}]
  remote['queries']['deployed_edge_functions']=[{'slug':'deployed-only','version':1}]
  return remote,{'edge_functions':['local-only']}
 def test_function_overloads_preserved(self):
  r,l=self.fixture();o=build(r,l);self.assertEqual(len(o['objects']),4);self.assertEqual(o['unresolvedObjects'],4)
 def test_missing_section(self):
  r,l=self.fixture();del r['queries']['indexes']
  with self.assertRaises(RuntimeError):build(r,l)
 def test_failed_inventory(self):
  r,l=self.fixture();r['failures']={'indexes':'error'}
  with self.assertRaises(RuntimeError):build(r,l)
 def test_duplicate_identity(self):
  r,l=self.fixture();r['queries']['functions'].append(r['queries']['functions'][0])
  with self.assertRaises(RuntimeError):build(r,l)
 def test_preserve_unchanged_review(self):
  r,l=self.fixture();previous=build(r,l);row=next(x for x in previous['objects'] if x['kind']=='functions')
  row.update(disposition='migrate',owner='synthetic',approvalEvidence=['synthetic'],contractEvidence=['synthetic'])
  result=build(r,l,previous);self.assertEqual(next(x for x in result['objects'] if x['key']==row['key'])['disposition'],'migrate')
 def test_changed_source_invalidates_review(self):
  r,l=self.fixture();previous=build(r,l);row=next(x for x in previous['objects'] if x['kind']=='functions');row.update(disposition='migrate',owner='synthetic')
  for f in r['queries']['functions']:f['security_definer']=True
  result=build(r,l,previous);self.assertEqual(next(x for x in result['objects'] if x['key']==row['key'])['disposition'],'unresolved')

 def test_cross_project_review_rejected(self):
  r,l=self.fixture();previous=build(r,l);r['project_ref']='another-project'
  with self.assertRaises(RuntimeError):build(r,l,previous)
 def test_local_only_review_preserved(self):
  r,l=self.fixture();previous=build(r,l);row=next(x for x in previous['objects'] if x['kind']=='local-only-edge-function')
  row.update(disposition='retain-temporarily',owner='synthetic',approvalEvidence=['synthetic'],contractEvidence=['synthetic'])
  result=build(r,l,previous);self.assertEqual(next(x for x in result['objects'] if x['key']==row['key'])['disposition'],'retain-temporarily')

if __name__=='__main__':unittest.main()
