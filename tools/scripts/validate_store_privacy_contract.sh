#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT/apps/rayon_sports"
TV_DIR="$ROOT/apps/rayon_sports_tv"

python3 - \
  "$APP_DIR/store_metadata/privacy_policy.html" \
  "$APP_DIR/store_metadata/play_store/data_safety.md" \
  "$APP_DIR/store_metadata/play_store/listing.md" \
  "$APP_DIR/store_metadata/app_store/privacy_nutrition.md" \
  "$APP_DIR/store_metadata/release_policy_assessment.md" \
  "$APP_DIR/android/app/src/main/AndroidManifest.xml" \
  "$TV_DIR/android/app/src/main/AndroidManifest.xml" \
  "$ROOT/packages/core/core_network/lib/src/crashlytics_service.dart" \
  "$ROOT/packages/features/feat_sms_ledger/lib/src/services/momo_sms_autoread_service.dart" <<'PY'
import pathlib
import sys
import xml.etree.ElementTree as ET

(
    privacy_path,
    data_safety_path,
    listing_path,
    apple_privacy_path,
    assessment_path,
    mobile_manifest_path,
    tv_manifest_path,
    crashlytics_path,
    sms_path,
) = (pathlib.Path(value) for value in sys.argv[1:])

paths = (
    privacy_path,
    data_safety_path,
    listing_path,
    apple_privacy_path,
    assessment_path,
    mobile_manifest_path,
    tv_manifest_path,
    crashlytics_path,
    sms_path,
)
missing_files = [str(path) for path in paths if not path.is_file()]
if missing_files:
    raise SystemExit("Missing store/privacy contract files:\n" + "\n".join(missing_files))

privacy = privacy_path.read_text()
data_safety = data_safety_path.read_text()
listing = listing_path.read_text()
apple_privacy = apple_privacy_path.read_text()
assessment = assessment_path.read_text()
crashlytics = crashlytics_path.read_text()
sms = sms_path.read_text()

checks = {
    "privacy policy deletion anchor": 'id="account-deletion"' in privacy,
    "privacy policy support route": "support@ikanisa.com" in privacy,
    "privacy policy Crashlytics disclosure": "crash" in privacy.lower(),
    "privacy policy performance disclosure": "performance" in privacy.lower(),
    "removed stale ML Kit disclosure": "Google ML Kit" not in privacy,
    "Play crash-log disclosure": "Crash logs" in data_safety,
    "Play performance disclosure": "Diagnostics / performance" in data_safety,
    "Play product-interaction disclosure": "Product interaction" in data_safety,
    "Play external account-deletion route": "https://gikundiro.com/privacy#account-deletion" in data_safety,
    "listing external account-deletion route": "https://gikundiro.com/privacy#account-deletion" in listing,
    "truthful ticket language": "Purchase match tickets directly" not in listing,
    "truthful conditional live language": "authorized club feed" in listing,
    "truthful conditional commerce language": "authorized commerce and payment service" in listing,
    "Apple tracking exclusion": "Tracking: No." in apple_privacy,
    "Apple signed-archive evidence gate": "Signed archive and Xcode-generated privacy report" in apple_privacy,
    "policy no-authority boundary": "No row authorizes upload, signing, submission, production enablement, or release." in assessment,
    "Crashlytics excludes raw Flutter details": "recordFlutterFatalError" not in crashlytics,
    "Crashlytics excludes account identifiers": "setUserIdentifier(userId" not in crashlytics,
    "Crashlytics uses sanitized runtime failure": "runtime_failure:${error.runtimeType}" in crashlytics,
    "SMS diagnostics exclude account ID": "session.user.id}" not in sms,
}

expected_apple_categories = {
    "Name",
    "Phone number",
    "User ID",
    "Device ID",
    "Purchase history",
    "Other financial information",
    "Gameplay content",
    "Product interaction",
    "Crash data",
    "Performance data",
}
for category in expected_apple_categories:
    checks[f"Apple category: {category}"] = f"| {category} |" in apple_privacy

android_ns = "{http://schemas.android.com/apk/res/android}"
tools_ns = "{http://schemas.android.com/tools}"

def active_permissions(path: pathlib.Path) -> set[str]:
    root = ET.parse(path).getroot()
    result = set()
    for element in root.findall("uses-permission"):
        if element.get(f"{tools_ns}node") == "remove":
            continue
        name = element.get(f"{android_ns}name")
        if name:
            result.add(name)
    return result

mobile_permissions = active_permissions(mobile_manifest_path)
tv_permissions = active_permissions(tv_manifest_path)
checks["mobile active permissions are minimal"] = mobile_permissions == {
    "android.permission.INTERNET",
    "android.permission.POST_NOTIFICATIONS",
}
checks["TV active permissions are minimal"] = tv_permissions == {
    "android.permission.INTERNET",
}

failures = [label for label, passed in checks.items() if not passed]
if failures:
    raise SystemExit(
        "Store/privacy contract failed:\n- " + "\n- ".join(sorted(failures))
    )

print(
    "Store/privacy contract passed: "
    f"{len(checks)} assertions; mobile_permissions={sorted(mobile_permissions)}; "
    f"tv_permissions={sorted(tv_permissions)}."
)
PY
