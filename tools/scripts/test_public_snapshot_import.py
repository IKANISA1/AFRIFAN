import copy
import datetime as dt
import json
import pathlib
import sqlite3
import tempfile
import unittest
from seed_rayon_public_d1_local import EXPECTED_TABLES, prepare_snapshot, digest
from verify_rayon_public_d1_local import verify
from stage_rayon_public_media_r2 import verified_objects

ROOT = pathlib.Path(__file__).resolve().parents[2]

class SnapshotImportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name); self.media = self.root/'app-media'; self.media.mkdir()
        self.rows = {table: [] for table in EXPECTED_TABLES}
        self.rows['clubs'] = [{'id':'club-24','name':"Vital’O / Synthetic"}]
        self.rows['news_posts'] = [{'id':'a', 'club_id':'club-24', 'title':"Quoted 'text' 🏟"}]
        self.manifest = {'public_read_only':True,'club_id':'club-24',
            'captured_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(), 'rows_sha256':'a'*64,
            'counts':{t:len(v) for t,v in self.rows.items()}}
        self.media_manifest = {'objects':[]}
    def build(self):
        self.manifest['counts'] = {t:len(v) for t,v in self.rows.items()}
        return prepare_snapshot(self.rows,self.manifest,self.media_manifest,self.media)
    def db(self):
        db=sqlite3.connect(':memory:'); db.execute('PRAGMA foreign_keys=ON'); self.addCleanup(db.close)
        for p in sorted((ROOT/'cloudflare/rayon-public/migrations').glob('*.sql')): db.executescript(p.read_text())
        return db
    def store_source(self):
        raw=json.dumps(self.rows,ensure_ascii=False).encode(); (self.root/'rayon-public-source-rows.json').write_bytes(raw)
        self.manifest['rows_sha256']=digest(raw); self.manifest['counts']={t:len(v) for t,v in self.rows.items()}
        (self.root/'manifest.json').write_text(json.dumps(self.manifest))
        (self.media/'manifest.json').write_text(json.dumps(self.media_manifest))
    def add_media(self):
        blob=b'fixture'; (self.media/'a.bin').write_bytes(blob)
        h=digest(blob)
        self.rows['media_assets']=[{'id':'asset','club_id':'club-24','storage_bucket':'source','storage_path':'image.png',
          'checksum_sha256':h,'usage_rights':'club-approved','usage_scopes':['squad']}]
        self.media_manifest['objects']=[{'source_id':'asset','source_bucket':'source','source_path':'image.png','file':'a.bin',
          'bytes':len(blob),'sha256':h,'usage_rights':'club-approved','usage_scopes':['squad']}]
    def test_deterministic(self):
        self.assertEqual(self.build(),self.build())
    def test_import_retains_legacy_and_is_unpublished(self):
        id,m,sql=self.build(); db=self.db(); db.executescript(sql)
        self.assertEqual(db.execute('SELECT status FROM public_snapshots').fetchone()[0],'importing')
        self.assertEqual(db.execute('SELECT COUNT(*) FROM public_snapshot_head').fetchone()[0],0)
        self.assertEqual(db.execute('SELECT manifest_json FROM public_snapshots').fetchone()[0],json.dumps(m,sort_keys=True,ensure_ascii=False,separators=(',',':')))
    def test_resume_import(self):
        id,m,sql=self.build(); db=self.db(); db.executescript(sql); db.executescript(sql)
        self.assertEqual(db.execute('SELECT COUNT(*) FROM public_snapshot_records').fetchone()[0],2)
    def test_large_manifest_has_bounded_statements(self):
        self.rows['news_posts']=[{'id':str(i).zfill(5),'title':'x'} for i in range(2700)]
        id,m,sql=self.build(); self.assertGreater(len(json.dumps(m)),100_000)
        self.assertTrue(all(len(line.encode())<90_000 for line in sql.splitlines()))
        db=self.db(); db.executescript(sql)
        self.assertEqual(digest(db.execute('SELECT manifest_json FROM public_snapshots').fetchone()[0]),id)
    def test_missing_table(self):
        self.rows.pop('partners')
        with self.assertRaises(RuntimeError):self.build()
    def test_nonpublic_source(self):
        self.manifest['public_read_only']=False
        with self.assertRaises(RuntimeError):self.build()
    def test_wrong_tenant(self):
        self.rows['news_posts'][0]['club_id']='other'
        with self.assertRaises(RuntimeError):self.build()
    def test_duplicate_record(self):
        self.rows['news_posts']*=2
        with self.assertRaises(RuntimeError):self.build()
    def test_source_counts_mismatch(self):
        self.manifest['counts']['news_posts']=7
        with self.assertRaises(RuntimeError):prepare_snapshot(self.rows,self.manifest,self.media_manifest,self.media)
    def test_capture_requires_timezone(self):
        self.manifest['captured_at_utc']='2026-09-26T12:00:00'
        with self.assertRaises(RuntimeError):self.build()
    def test_nonfinite_values(self):
        self.rows['news_posts'][0]['value']=float('nan')
        with self.assertRaises(ValueError):self.build()
    def test_media_bytes_checked(self):
        self.add_media(); (self.media/'a.bin').write_bytes(b'wrong')
        with self.assertRaises(RuntimeError):self.build()
    def test_media_provenance_checked(self):
        self.add_media(); self.media_manifest['objects'][0]['source_path']='other.png'
        with self.assertRaises(RuntimeError):self.build()
    def test_media_rights_checked(self):
        self.add_media(); self.media_manifest['objects'][0]['usage_rights']='invented'
        with self.assertRaises(RuntimeError):self.build()
    def test_malformed_media_item(self):
        self.media_manifest['objects']=[None]
        with self.assertRaises(RuntimeError):self.build()
    def test_export_path_escape(self):
        self.add_media(); self.media_manifest['objects'][0]['file']='../outside.bin'
        with self.assertRaises(RuntimeError):self.build()
    def test_parity_verifier(self):
        self.add_media(); self.store_source(); id,m,sql=self.build(); db=self.db(); db.executescript(sql)
        result=verify(db,self.root,id); self.assertFalse(result['approvedActiveHead']); self.assertEqual(result['sourceRows'],3)
        with self.assertRaises(RuntimeError):verify(db,self.root,id,True)
    def test_parity_verifier_rejects_changed_rows(self):
        self.store_source(); id,m,sql=self.build(); db=self.db();db.executescript(sql)
        db.execute("UPDATE public_snapshot_records SET payload_json='{}' WHERE source_table='news_posts'")
        with self.assertRaises(RuntimeError):verify(db,self.root,id)
    def test_r2_content_addressed_keys(self):
        self.add_media(); self.store_source(); objects=verified_objects(self.media)
        self.assertEqual(objects[0]['key'],'assets/'+digest(b'fixture')+'.bin')
    def test_r2_type_rejected(self):
        self.add_media(); self.media_manifest['objects'][0]['source_path']='script.html'; self.store_source()
        with self.assertRaises(RuntimeError):verified_objects(self.media)

if __name__ == '__main__':unittest.main()
