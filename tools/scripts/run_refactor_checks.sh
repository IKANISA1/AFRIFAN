#!/usr/bin/env bash
# Complete checkout gate. No deployment, provider invocation, billing or resets.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
command -v node >/dev/null
command -v python3 >/dev/null
command -v dart >/dev/null
command -v tsc >/dev/null
node -e 'const [a,b,c]=process.versions.node.split(".").map(Number); if(a!==22||b<22||(b===22&&c<2)) { console.error("Use the repository Node 22 toolchain (>=22.22.2 <23); do not lower package requirements.");process.exit(1); }'
python3 -c 'import sys; assert sys.version_info >= (3,10), "Python 3.10+ required"'
node --experimental-sqlite --test \
  tools/scripts/validate_repository_boundary.test.mjs \
  tools/scripts/validate_predict_economics_contract.test.mjs \
  cloudflare/rayon-public/tests/snapshot.test.mjs
node cloudflare/operator-api/scripts/build-ui.mjs --check
node cloudflare/operator-api/scripts/check-deployment.mjs
node --test cloudflare/operator-api/tests/*.test.mjs
(cd tools/scripts && python3 -m unittest -v \
  test_supporter_sms_boundary test_public_snapshot_import test_migration_release)
dart tools/scripts/test_feature_availability_policy.dart
node tools/scripts/validate_repository_boundary.mjs
dart run tools/scripts/validate_workspace_architecture.dart
python3 tools/scripts/validate_supporter_sms_boundary.py "$ROOT"
node tools/scripts/validate_predict_economics_contract.mjs
printf '%s\n' 'Refactor source gates passed. Full Flutter/web/database/device/UAT and production approval remain separate gates.'
