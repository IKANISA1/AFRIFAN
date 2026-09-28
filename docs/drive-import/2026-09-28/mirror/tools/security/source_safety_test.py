import importlib.util,tempfile,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('safety',Path(__file__).with_name('source_safety.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class SourceSafetyTests(unittest.TestCase):
 def setUp(self):self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name)
 def put(self,p,b=b'safe'):
  q=self.root/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(b);return q
 def check(self,p):return m.check_paths(self.root,[p])
 def test_clean_source(self):self.put('src/app.mjs');self.assertEqual(self.check('src/app.mjs'),[])
 def test_env_example_allowed(self):self.put('.env.example',b'SECRET=');self.assertEqual(self.check('.env.example'),[])
 def test_env_local_blocked(self):self.put('.env.local');self.assertEqual(self.check('.env.local')[0]['rule'],'sensitive-file-name')
 def test_signing_file(self):self.put('android/upload-key.jks');self.assertTrue(self.check('android/upload-key.jks'))
 def test_archive_source(self):self.put('output/copy.mjs');self.assertTrue(self.check('output/copy.mjs'))
 def test_dependency_source(self):self.put('node_modules/a.js');self.assertTrue(self.check('node_modules/a.js'))
 def test_symlink(self):self.put('real');(self.root/'alias').symlink_to(self.root/'real');self.assertEqual(self.check('alias')[0]['rule'],'symlink')
 def test_parent_symlink(self):self.put('real/x');(self.root/'alias').symlink_to(self.root/'real');self.assertTrue(self.check('alias/x'))
 def test_deleted_source(self):self.assertEqual(self.check('deleted.mjs'),[])
 def test_path_escape(self):self.assertTrue(self.check('../outside'))
 def test_absolute_path(self):self.assertTrue(self.check('/etc/hosts'))
 def test_backslash_path(self):self.assertTrue(self.check('foo\\bar'))
 def test_case_collision(self):self.put('Foo');self.put('foo');self.assertTrue(m.check_paths(self.root,['Foo','foo']))
 def test_key_is_redacted(self):self.put('bad.txt',b'-----BEGIN '+b'PRIVATE KEY-----\nSYNTHETIC');r=self.check('bad.txt');self.assertEqual(r,[{'path':'bad.txt','rule':'private-key-block'}])
 def test_token_is_redacted(self):self.put('bad.txt',b'gh'+b'p_'+b'X'*36);r=self.check('bad.txt');self.assertEqual(r,[{'path':'bad.txt','rule':'github-token'}])
 def test_binary_no_leak(self):self.put('logo.png',b'\0\xffprivate');self.assertEqual(self.check('logo.png'),[])
if __name__=='__main__':unittest.main()
