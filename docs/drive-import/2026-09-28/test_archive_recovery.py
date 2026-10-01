"""Regression tests for destructive archival consolidation boundaries."""
import subprocess
import os
import contextlib
import io
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

import archive_recovery as recovery


class ArchiveRecoveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base = self.root / "docs/drive-import/2026-09-28"
        self.base.mkdir(parents=True)
        subprocess.run(["git", "init", "-q"], cwd=self.root, check=True)
        self.canonical = "mirror/output/history/source.zip"
        self.duplicate = "mirror/Conversation_Files_2026-09-27/File_Snapshots/001_source.zip"
        payload = self.base / self.canonical
        payload.parent.mkdir(parents=True)
        with zipfile.ZipFile(payload, "w") as archive:
            archive.writestr("source/module.js", "export const value = 1;")
        self.write(self.duplicate, payload.read_bytes())
        self.write("direct-files.tsv", b"immutable historical retrieval IDs and hashes\n")
        self.commit()

    def write(self, name, data):
        path = self.base / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return path

    def commit(self):
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        subprocess.run(["git", "-c", "user.name=Archive test", "-c", "user.email=test@example.invalid", "commit", "-qm", "Synthetic archive"], cwd=self.root, check=True)

    def test_exact_copy_removed_only_after_verified_retained_canonical_and_index(self):
        before = (self.base / "direct-files.tsv").read_bytes()
        plan = recovery.build_plan(self.root, self.base)
        self.assertEqual(plan["removed_regular_paths"], [self.duplicate])
        result = recovery.apply(self.root, self.base, plan)
        self.assertFalse((self.base / self.duplicate).exists())
        self.assertEqual(result["verified_original_paths"], 3)
        self.assertEqual(result["verified_zip_containers"], 1)
        self.assertEqual(recovery.resolve(self.base, self.duplicate, plan), self.base / self.canonical)
        self.assertEqual((self.base / "direct-files.tsv").read_bytes(), before)
        with self.assertRaisesRegex(ValueError, "existing recovery index"):
            recovery.apply(self.root, self.base, plan)

    def test_unique_revision_and_source_grants_tests_migrations_and_git_refs_retained(self):
        unique = self.base / "mirror/Conversation_Files_2026-09-27/File_Snapshots/002_source.zip"
        with zipfile.ZipFile(unique, "w") as archive:
            archive.writestr("source/module.js", "a distinct revision")
        for name in ["003_LICENSE.md", "004_source_grant.md", "005_approval.json", "006_guard_test.js", "007_0001_migration.sql", "008_AndroidManifest.xml"]:
            self.write("mirror/Conversation_Files_2026-09-27/File_Snapshots/" + name, b"protected bytes")
        self.write("variants/git-internal/refs/heads/first", b"protected bytes")
        self.write("variants/git-internal/refs/heads/second", b"protected bytes")
        self.commit()
        plan = recovery.build_plan(self.root, self.base)
        self.assertEqual(plan["removed_regular_paths"], [self.duplicate])
        self.assertGreater(len(plan["blocked_groups"]), 0)
        recovery.apply(self.root, self.base, plan)
        self.assertTrue((self.base / "mirror/Conversation_Files_2026-09-27/File_Snapshots/002_source.zip").exists())

    def test_actual_relative_markdown_consumer_preserves_the_original_path(self):
        path = self.root / "docs/consumer.md"
        path.write_text("[Source](drive-import/2026-09-28/" + self.duplicate + ")")
        self.commit()
        plan = recovery.build_plan(self.root, self.base)
        self.assertNotIn(self.duplicate, plan["removed_regular_paths"])
        self.assertEqual(recovery.references(self.root, self.base, recovery.tracked(self.root))[self.duplicate], ["docs/consumer.md"])

    def test_new_untracked_module_consumer_blocks_a_planned_removal(self):
        plan = recovery.build_plan(self.root, self.base)
        consumer = self.root / "new-consumer.ts"
        consumer.write_text("import './docs/drive-import/2026-09-28/" + self.duplicate + "';")
        with self.assertRaisesRegex(ValueError, "new consumer"):
            recovery.apply(self.root, self.base, plan)
        self.assertTrue((self.base / self.duplicate).exists())

    def test_changed_candidate_or_canonical_fails_before_any_delete(self):
        plan = recovery.build_plan(self.root, self.base)
        (self.base / self.canonical).write_bytes(b"changed source")
        with self.assertRaisesRegex(ValueError, "Canonical content changed"):
            recovery.apply(self.root, self.base, plan)
        self.assertTrue((self.base / self.duplicate).exists())
        self.assertFalse((self.base / recovery.INDEX).exists())
        with self.assertRaisesRegex(ValueError, "Changed or nonregular"):
            recovery.build_plan(self.root, self.base)

    def test_alias_chains_escape_symlinks_and_modified_manifests_fail_closed(self):
        plan = recovery.build_plan(self.root, self.base)
        alias = next(row for row in plan["inventory"] if row["original_path"] == self.duplicate)
        alias["canonical_path"] = "../escape.zip"
        with self.assertRaises(ValueError):
            recovery.verify(self.base, plan, before_removal=True)
        alias["canonical_path"] = self.canonical
        old = self.base / self.duplicate
        old.unlink()
        old.symlink_to(self.base / self.canonical)
        with self.assertRaisesRegex(ValueError, "Symlink"):
            recovery.verify(self.base, plan, before_removal=True)
        old.unlink()
        old.write_bytes((self.base / self.canonical).read_bytes())
        (self.base / "direct-files.tsv").write_text("rewritten provenance")
        with self.assertRaises(ValueError):
            recovery.apply(self.root, self.base, plan)

    def test_removal_race_keeps_the_changed_file_and_original_hash_index(self):
        plan = recovery.build_plan(self.root, self.base)
        original_sha = recovery.sha
        calls = 0
        def racing_sha(path):
            nonlocal calls
            calls += 1
            if calls == 1:
                (self.base / self.duplicate).write_bytes(b"new unique revision")
            return original_sha(path)
        with patch.object(recovery, "sha", racing_sha):
            with self.assertRaises(ValueError):
                recovery.apply(self.root, self.base, plan)
        self.assertEqual((self.base / self.duplicate).read_bytes(), b"new unique revision")

    def test_tampered_removal_list_cannot_delete_a_unique_canonical_or_intake_manifest(self):
        plan = recovery.build_plan(self.root, self.base)
        plan["removed_regular_paths"].append("direct-files.tsv")
        with self.assertRaisesRegex(ValueError, "Removal list differs"):
            recovery.apply(self.root, self.base, plan)
        self.assertTrue((self.base / "direct-files.tsv").exists())
        self.assertTrue((self.base / self.canonical).exists())
        self.assertTrue((self.base / self.duplicate).exists())

    def test_relative_scope_is_normalized_before_index_write(self):
        plan = recovery.build_plan(self.root, self.base)
        previous = Path.cwd()
        try:
            os.chdir(self.root)
            result = recovery.apply(self.root, Path("docs/drive-import/2026-09-28"), plan)
        finally:
            os.chdir(previous)
        self.assertEqual(result["removed_regular_files"], 1)

    def test_interrupted_apply_resumes_without_replacing_its_saved_index(self):
        plan = recovery.build_plan(self.root, self.base)
        with patch.object(recovery, "references", side_effect=RuntimeError("Interrupted pre-delete check")):
            with self.assertRaises(RuntimeError):
                recovery.apply(self.root, self.base, plan)
        checkpoint = (self.base / recovery.INDEX).read_bytes()
        self.assertTrue((self.base / self.duplicate).exists())
        result = recovery.complete_removal(self.root, self.base, plan)
        self.assertEqual(result["removed_regular_files"], 1)
        self.assertEqual((self.base / recovery.INDEX).read_bytes(), checkpoint)

    def test_default_command_verifies_the_existing_index_without_replanning(self):
        plan = recovery.build_plan(self.root, self.base)
        recovery.apply(self.root, self.base, plan)
        saved = (self.base / recovery.INDEX).read_bytes()
        output = io.StringIO()
        with patch.object(recovery, "BASE", self.base), patch.object(recovery, "ROOT", self.root), patch("sys.argv", ["archive_recovery.py"]), contextlib.redirect_stdout(output):
            recovery.main()
        self.assertEqual(json.loads(output.getvalue())["removed_regular_files"], 1)
        self.assertEqual((self.base / recovery.INDEX).read_bytes(), saved)


if __name__ == "__main__":
    unittest.main()
