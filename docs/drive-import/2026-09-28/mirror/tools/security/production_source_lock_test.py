import hashlib,importlib.util,json,tempfile,unittest
from pathlib import Path
SPEC=importlib.util.spec_from_file_location('candidate_runner',Path(__file__).resolve().parents[1]/'scripts/verify_production_candidate.py')
MODULE=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(MODULE)
class SourceLockTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.root=Path(self.tmp.name);(self.root/'source.mjs').write_text('source');self.row={'path':'source.mjs','sha256':hashlib.sha256(b'source').hexdigest()}
 def check(self,rows):return MODULE.check_lock(self.root,{'schemaVersion':1,'files':rows})
 def test_valid(self):self.assertEqual(self.check([self.row]),[])
 def test_tamper(self):
  (self.root/'source.mjs').write_text('changed');self.assertTrue(self.check([self.row]))
 def test_missing(self):self.assertTrue(self.check([{**self.row,'path':'missing'}]))
 def test_empty(self):self.assertTrue(self.check([]))
 def test_bad_schema(self):self.assertTrue(MODULE.check_lock(self.root,{'schemaVersion':0,'files':[self.row]}))
 def test_duplicate(self):self.assertTrue(self.check([self.row,self.row]))
 def test_case_collision(self):self.assertTrue(self.check([self.row,{**self.row,'path':'Source.mjs'}]))
 def test_bad_hash(self):self.assertTrue(self.check([{**self.row,'sha256':'x'}]))
 def test_extra_key(self):self.assertTrue(self.check([{**self.row,'approved':True}]))
 def test_unsafe_paths(self):
  for value in ['/source.mjs','../source.mjs','a//b','./source.mjs','a/../source.mjs','a\\b','a\nfile']:
   with self.subTest(path=value):self.assertTrue(self.check([{**self.row,'path':value}]))
 def test_symlink(self):
  (self.root/'link').symlink_to(self.root/'source.mjs');self.assertTrue(self.check([{**self.row,'path':'link'}]))
 def test_internal_directory_alias(self):
  (self.root/'dir').mkdir();(self.root/'dir/source.mjs').write_text('source');(self.root/'alias').symlink_to(self.root/'dir');self.assertTrue(self.check([{**self.row,'path':'alias/source.mjs'}]))
if __name__=='__main__':unittest.main()
