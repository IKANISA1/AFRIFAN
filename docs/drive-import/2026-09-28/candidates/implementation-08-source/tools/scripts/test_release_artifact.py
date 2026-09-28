import hashlib,importlib.util,json,tempfile,unittest,zipfile
from pathlib import Path
import release_artifact as a
class ReleaseArtifactTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name);self.web=self.root/'web';self.web.mkdir();(self.web/'.open-next/assets').mkdir(parents=True)
  for n in a.CONTROL:(self.web/n).write_text('{}')
  (self.web/'.open-next/worker.js').write_text('export default {}');(self.web/'.open-next/assets/app.js').write_text('console.log(1)')
  self.zip=self.root/'release.zip';self.sha='a'*40;self.run='123'
 def sealed(self):return a.seal(self.web,self.zip,self.sha,self.run)['sha256']
 def mutate(self,edit):
  h=self.sealed()
  with zipfile.ZipFile(self.zip) as z:data={n:z.read(n) for n in z.namelist()}
  edit(data)
  with zipfile.ZipFile(self.zip,'w') as z:
   for n,b in data.items():z.writestr(n,b)
  return a.digest(self.zip.read_bytes())
 def test_round_trip(self):
  h=self.sealed();self.assertEqual(a.verify(self.zip,h,self.sha,self.run)['files'],6)
 def test_changed_archive_denied(self):
  h=self.sealed();self.zip.write_bytes(self.zip.read_bytes()+b'changed')
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run)
 def test_wrong_candidate(self):
  h=self.sealed()
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,'b'*40,self.run)
 def test_wrong_run(self):
  h=self.sealed()
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,'124')
 def test_missing_record(self):
  h=self.mutate(lambda d:d.pop('.open-next/worker.js'))
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run)
 def test_unrecorded_file(self):
  h=self.mutate(lambda d:d.update({'outside.txt':b'no'}))
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run)
 def test_changed_payload(self):
  h=self.mutate(lambda d:d.update({'.open-next/worker.js':b'bad'}))
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run)
 def test_extra_manifest_field(self):
  def edit(d):
   m=json.loads(d['release-manifest.json']);m['approved']=True;d['release-manifest.json']=json.dumps(m).encode()
  h=self.mutate(edit)
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run)
 def test_boolean_size(self):
  def edit(d):
   m=json.loads(d['release-manifest.json']);m['files'][0]['bytes']=True;d['release-manifest.json']=json.dumps(m).encode()
  h=self.mutate(edit)
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run)
 def test_duplicate_json(self):
  h=self.mutate(lambda d:d.update({'release-manifest.json':b'{"schemaVersion":1,"schemaVersion":1}'}))
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run)
 def test_duplicate_zip(self):
  self.sealed()
  with zipfile.ZipFile(self.zip,'a') as z:z.writestr('.open-next/worker.js','x')
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,a.digest(self.zip.read_bytes()),self.sha,self.run)
 def test_extract_verified_only(self):
  h=self.sealed();dest=self.root/'dest';dest.mkdir()
  for n in a.CONTROL:(dest/n).write_text('{}')
  self.assertTrue(a.verify(self.zip,h,self.sha,self.run,dest)['extracted']);self.assertEqual((dest/'.open-next/worker.js').read_text(),'export default {}')
 def test_existing_output_not_overwritten(self):
  h=self.sealed()
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run,self.web)
 def test_controls_must_match(self):
  h=self.sealed();dest=self.root/'dest';dest.mkdir()
  for n in a.CONTROL:(dest/n).write_text('changed')
  with self.assertRaises(a.ArtifactError):a.verify(self.zip,h,self.sha,self.run,dest)
  self.assertFalse((dest/'.open-next').exists())
 def test_symlink_input(self):
  (self.web/'.open-next/assets/link').symlink_to(self.web/'package.json')
  with self.assertRaises(a.ArtifactError):self.sealed()
 def test_missing_worker(self):
  (self.web/'.open-next/worker.js').unlink()
  with self.assertRaises(a.ArtifactError):self.sealed()
 def test_never_replace_archive(self):
  self.sealed()
  with self.assertRaises(a.ArtifactError):a.seal(self.web,self.zip,self.sha,self.run)
 def test_bad_commit(self):
  with self.assertRaises(a.ArtifactError):a.seal(self.web,self.zip,'main',self.run)
 def test_bad_run(self):
  with self.assertRaises(a.ArtifactError):a.seal(self.web,self.zip,self.sha,'../run')
for index,path in enumerate(['../x','/x','.open-next/../x','.open-next//x','.open-next/./x','.open-next/evil\\x','.open-next/evil\x00x','.open-next/.env.local','.open-next/upload.jks','.open-next/key.pem','.open-next/name\nx','unrelated.txt']):
 def test(self,path=path):
  with self.assertRaises(a.ArtifactError):a.safe_path(path)
 setattr(ReleaseArtifactTests,f'test_unsafe_path_{index:02}',test)
if __name__=='__main__':unittest.main()
