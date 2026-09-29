"""Behavioral regressions for the tracked-source secret gate and log redaction."""

import pathlib
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name("validate_source_secrets.sh")


class SourceSecretsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="africlub-secret-gate-")
        self.root = pathlib.Path(self.temp.name)
        (self.root / "tools/scripts").mkdir(parents=True)
        shutil.copyfile(SCRIPT, self.root / "tools/scripts" / SCRIPT.name)
        self.write("supabase/config.toml", "[auth]\n")
        subprocess.run(["git", "init", "-q", str(self.root)], check=True)

    def tearDown(self):
        self.temp.cleanup()

    def write(self, path, content):
        target = self.root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content)

    def run_gate(self):
        subprocess.run(["git", "add", "."], cwd=self.root, check=True)
        return subprocess.run(
            ["bash", "tools/scripts/validate_source_secrets.sh"],
            cwd=self.root, capture_output=True, text=True,
        )

    def test_clean_source_and_public_client_key_pass(self):
        self.write("apps/club/lib/config.dart", "const publicKey = 'sb_publishable_example';\n")
        result = self.run_gate()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_live_secret_fails_without_printing_value_or_source_line(self):
        secret = "sk_" + "live_" + "A" * 24
        self.write("docs/private-config.txt", "PAYMENT_TOKEN=" + secret + "\n")
        result = self.run_gate()
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("docs/private-config.txt", output)
        self.assertNotIn(secret, output)
        self.assertNotIn("PAYMENT_TOKEN=", output)

    def test_client_service_role_fails_without_printing_assignment(self):
        value = "do-not-publish-this-value"
        self.write("packages/core/client/lib/config.dart", "const service_role = '" + value + "';\n")
        result = self.run_gate()
        output = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("packages/core/client/lib/config.dart", output)
        self.assertNotIn(value, output)

    def test_service_role_in_negative_client_test_is_allowed(self):
        self.write("packages/core/client/test/denied_test.dart", "// service_role must be denied\n")
        self.assertEqual(self.run_gate().returncode, 0)

    def test_signing_material_is_rejected(self):
        self.write("apps/club/android/app/release.jks", "synthetic-keystore")
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("apps/club/android/app/release.jks", result.stderr)
        self.assertNotIn("synthetic-keystore", result.stderr)

    def test_deployment_vars_are_rejected_but_example_is_allowed(self):
        self.write("apps/club/web/.dev.vars.example", "EXAMPLE=true\n")
        self.assertEqual(self.run_gate().returncode, 0)
        self.write("apps/club/web/.dev.vars", "PRIVATE_VALUE=redacted\n")
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PRIVATE_VALUE=", result.stdout + result.stderr)

    def test_fixed_otp_mapping_is_rejected_without_printing_phone_or_code(self):
        phone, code = "250700000001", "123456"
        self.write("supabase/config.toml", '[auth.sms.test_otp]\n"' + phone + '" = "' + code + '"\n')
        result = self.run_gate()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn(phone, result.stdout + result.stderr)
        self.assertNotIn(code, result.stdout + result.stderr)

    def test_comment_only_otp_section_is_allowed(self):
        self.write("supabase/config.toml", '[auth.sms.test_otp]\n# No committed mappings.\n')
        self.assertEqual(self.run_gate().returncode, 0)


if __name__ == "__main__":
    unittest.main()
