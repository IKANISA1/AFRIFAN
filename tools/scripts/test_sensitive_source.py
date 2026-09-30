import base64,json,tempfile,unittest,subprocess
from pathlib import Path
from check_sensitive_source import inspect,path_issue,MAX_TEXT
class SensitiveSourceTests(unittest.TestCase):
 def setUp(self):self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name)
 def scan(self,name,text):
  p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text);return inspect(self.root,[name])
 def test_normal_code(self):self.assertTrue(self.scan('lib/main.dart','void main() {}')['passed'])
 def test_example_config(self):self.assertTrue(self.scan('.env.example','PUBLIC_SITE_URL=')['passed'])
 def test_private_material_redacted(self):
  value='-----BEGIN '+'PRIVATE KEY-----\n'+('A'*128)+'\n-----END '+'PRIVATE KEY-----';r=self.scan('config.txt',value);self.assertFalse(r['passed']);self.assertNotIn(value,json.dumps(r));self.assertFalse(r['matchedValuesIncluded'])
 def test_privileged_jwt_redacted(self):
  enc=lambda v:base64.urlsafe_b64encode(json.dumps(v).encode()).decode().rstrip('=')
  value=enc({'alg':'HS256'})+'.'+enc({'role':'service_role','testOnly':True})+'.'+'synthetic_signature';r=self.scan('config.ts',value);self.assertFalse(r['passed']);self.assertNotIn(value,json.dumps(r))
 def test_public_client_not_labelled_privileged(self):
  enc=lambda v:base64.urlsafe_b64encode(json.dumps(v).encode()).decode().rstrip('=')
  value=enc({'alg':'HS256'})+'.'+enc({'role':'anon','testOnly':True})+'.'+'synthetic_signature';self.assertTrue(self.scan('client.ts',value)['passed'])
 def test_service_account(self):self.assertFalse(self.scan('account.json',json.dumps({'type':'service_account','private_key':'synthetic'}))['passed'])
 def test_deleted_source(self):self.assertTrue(inspect(self.root,['gone.py'])['passed'])
 def test_symlink_denied(self):
  (self.root/'target').write_text('normal');(self.root/'link').symlink_to(self.root/'target');self.assertFalse(inspect(self.root,['link'])['passed'])
 def test_parent_symlink_denied(self):
  (self.root/'actual').mkdir();(self.root/'actual/a').write_text('normal');(self.root/'linked').symlink_to(self.root/'actual',target_is_directory=True);self.assertFalse(inspect(self.root,['linked/a'])['passed'])
 def test_oversized_not_silent(self):self.assertFalse(self.scan('large.json','x'*(MAX_TEXT+1))['passed'])
 def test_parser_markers_are_not_embedded_key_material(self):
  self.assertTrue(self.scan('parser.ts','const strip = value.replace("-----BEGIN PRIVATE KEY-----", "").replace("-----END PRIVATE KEY-----", "");')['passed'])
 def test_escaped_private_key_material_is_rejected(self):
  value='-----BEGIN '+'PRIVATE KEY-----\\n'+('A'*128)+'\\n-----END '+'PRIVATE KEY-----'
  self.assertFalse(self.scan('config.ts',json.dumps({'key':value}))['passed'])
 def test_archive_namespace_is_reported_separately(self):
  result=self.scan('docs/drive-import/2026-09-28/source/.env','synthetic-private-fixture')
  self.assertTrue(result['passed']);self.assertEqual(result['excludedArchiveFiles'],1)
 def test_archive_exclusion_does_not_hide_active_credentials(self):
  self.assertFalse(self.scan('docs/drive-import-active/.env','synthetic')['passed'])
 def test_guard_source_is_not_secret(self):
  src=Path(__file__).with_name('check_sensitive_source.py').read_text();self.assertTrue(self.scan('check_sensitive_source.py',src)['passed'])
for n in ['.env','.env.local','.env.production','x/.dev.vars','x/keystore.properties','x/upload.jks','x/key.p12','x/key.pfx','x/source.keystore','/outside','../outside','x/../outside','x\\bad']:
 def test(self,n=n):self.assertIsNotNone(path_issue(n))
 setattr(SensitiveSourceTests,'test_path_'+str(len(SensitiveSourceTests.__dict__)),test)
if __name__=='__main__':unittest.main()
