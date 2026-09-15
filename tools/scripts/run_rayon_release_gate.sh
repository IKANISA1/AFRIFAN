#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
if [[ $# -ne 2 || -z "$1" || -z "$2" ]]; then
  echo "Usage: run_rayon_release_gate.sh <android-acceptance-id> <ios-acceptance-id>" >&2
  echo "Both reviewed MOBILE-DESIGN-100 records are required. Engineering checks are available through run_rayon_engineering_checks.sh." >&2
  exit 2
fi
validate_mobile_acceptance() {
  node tools/scripts/validate_mobile_design_release.mjs --app rayon_sports --platform android --acceptance-id "$1"
  node tools/scripts/validate_mobile_design_release.mjs --app rayon_sports --platform ios --acceptance-id "$2"
}
# Fail before build side effects when the candidate is not already reviewable.
validate_mobile_acceptance "$1" "$2"
bash tools/scripts/run_rayon_engineering_checks.sh
# Recheck the exact bytes after engineering commands and fail on any drift.
validate_mobile_acceptance "$1" "$2"
echo "Rayon Sports engineering and MOBILE-DESIGN-100 release gates passed for the reviewed Android and iOS artifacts. Deployment, providers, signing, store review and public availability require their own evidence."
