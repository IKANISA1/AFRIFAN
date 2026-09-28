import base64,json,tempfile,unittest,subprocess
from pathlib import Path
from check_sensitive_source import inspect,path_issue
class SensitiveSourceTests(unittest.TestCase):
 def setUp(self):self.t=tempfile.TemporaryDirectory();self.addCleanup(self.t.cleanup);self.root=Path(self.t.name)
 def scan(self,name,text):
  p=self.root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text);return inspect(self.root,[name])
 def test_normal_code(self):self.assertTrue(self.scan('lib/main.dart','void main() {}')['passed'])
 def test_example_config(self):self.assertTrue(self.scan('.env.example','PUBLIC_SITE_URL=')['passed'])
 def test_private_material_redacted(self):
  value='-----BEGIN '+'PRIVATE KEY-----\nsynthetic-test-only';r=self.scan('config.txt',value);self.assertFalse(r['passed']);self.assertNotIn(value,json.dumps(r));self.assertFalse(r['matchedValuesIncluded'])
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
 def test_oversized_not_silent(self):self.assertFalse(self.scan('large.json','x'*(4*1024*1024+1))['passed'])
 def test_guard_source_is_not_secret(self):
  src=Path(__file__).with_name('check_sensitive_source.py').read_text();self.assertTrue(self.scan('check_sensitive_source.py',src)['passed'])
for n in ['.env','.env.local','.env.production','x/.dev.vars','x/keystore.properties','x/upload.jks','x/key.p12','x/key.pfx','x/source.keystore','/outside','../outside','x/../outside','x\\bad']:
 def test(self,n=n):self.assertIsNotNone(path_issue(n))
 setattr(SensitiveSourceTests,'test_path_'+str(len(SensitiveSourceTests.__dict__)),test)
if __name__=='__main__':unittest.main()
