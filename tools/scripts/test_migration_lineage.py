import unittest,tempfile,os
from pathlib import Path
from check_migration_lineage import check
class LineageTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name).resolve()
 def write(self,path,text='SELECT 1;'):
  p=self.root/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text);return p
 def test_empty_nonrelease(self):
  r=check(self.root);self.assertTrue(r['passed']);self.assertFalse(r['remoteMigrationAuthorized']);self.assertFalse(r['historicalConflictReconciled'])
 def test_distinct_versions(self):
  self.write('cloudflare/x/migrations/0001_init.sql');self.write('cloudflare/x/migrations/0002_more.sql');self.assertTrue(check(self.root)['passed'])
 def test_duplicate_prefix(self):
  self.write('cloudflare/x/migrations/0003_a.sql');self.write('cloudflare/x/migrations/0003_b.sql');self.assertFalse(check(self.root)['passed'])
 def test_numeric_equivalence(self):
  self.write('cloudflare/x/migrations/3_a.sql');self.write('cloudflare/x/migrations/0003_b.sql');self.assertFalse(check(self.root)['passed'])
 def test_separate_databases(self):
  self.write('cloudflare/x/migrations/0001_a.sql');self.write('cloudflare/y/migrations/0001_b.sql');self.assertTrue(check(self.root)['passed'])
 def test_changed_known_name(self):
  self.write('cloudflare/payment-allocation/migrations/0003_payment_handoff_journal.sql');self.assertFalse(check(self.root)['passed'])
 def test_unknown_handoff_name(self):
  self.write('cloudflare/payment-allocation/migrations/0003_new.sql');self.assertFalse(check(self.root)['passed'])
 def test_migration_symlink(self):
  p=self.write('outside.sql');q=self.root/'cloudflare/x/migrations';q.mkdir(parents=True);(q/'0001_x.sql').symlink_to(p);self.assertFalse(check(self.root)['passed'])
 def test_source_directory_symlink(self):
  (self.root/'cloudflare').symlink_to('/tmp');self.assertFalse(check(self.root)['passed'])
 def test_root_symlink(self):
  p=self.root/'alias';p.symlink_to(self.root,target_is_directory=True);self.assertFalse(check(p)['passed'])
 def test_missing_root(self):self.assertFalse(check(self.root/'missing')['passed'])
 def test_output_ignored(self):
  self.write('output/history/migrations/0003_a.sql');self.write('output/history/migrations/0003_b.sql');self.assertTrue(check(self.root)['passed'])
 def test_retained_archive_is_not_active_lineage(self):
  for prefix in ['docs/drive-import/2026-09-28/candidates/old', '.recovery/old']:
   self.write(prefix+'/migrations/0003_a.sql');self.write(prefix+'/migrations/0003_b.sql')
  result=check(self.root);self.assertTrue(result['passed']);self.assertEqual(result['directories'],[])
 def test_generated_flutter_links_are_not_active_source(self):
  parent=self.root/'apps/club/ios/Flutter/ephemeral/Packages';parent.mkdir(parents=True)
  (parent/'generated').symlink_to('/tmp',target_is_directory=True)
  self.assertTrue(check(self.root)['passed'])
 def test_archive_exclusion_is_exact_namespace(self):
  self.write('docs/drive-import-active/migrations/0003_a.sql');self.write('docs/drive-import-active/migrations/0003_b.sql')
  self.assertFalse(check(self.root)['passed'])
if __name__=='__main__':unittest.main()
