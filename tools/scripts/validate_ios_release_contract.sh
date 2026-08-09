#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_SLUG="${1:-rayon_sports}"
APP_DIR="$ROOT/apps/$APP_SLUG"
IOS_DIR="$APP_DIR/ios"
INFO_PLIST="$IOS_DIR/Runner/Info.plist"
ENTITLEMENTS_PLIST="$IOS_DIR/Runner/Runner.entitlements"
PRIVACY_MANIFEST="$IOS_DIR/Runner/PrivacyInfo.xcprivacy"
GOOGLE_SERVICE_INFO_PLIST="$IOS_DIR/Runner/GoogleService-Info.plist"
LAUNCH_SCREEN_STORYBOARD="$IOS_DIR/Runner/Base.lproj/LaunchScreen.storyboard"
PODFILE="$IOS_DIR/Podfile"
APP_FRAMEWORK_INFO_PLIST="$IOS_DIR/Flutter/AppFrameworkInfo.plist"
XCODE_PROJECT="$IOS_DIR/Runner.xcodeproj/project.pbxproj"
RUNNER_SCHEME="$IOS_DIR/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme"
GENERATED_SWIFT_PACKAGE="$IOS_DIR/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift"
IOS_MINIMUM_VERSION="${IOS_MINIMUM_VERSION:-15.5}"

if [ ! -d "$APP_DIR" ]; then
  echo "Unknown app slug: $APP_SLUG" >&2
  exit 1
fi

python3 - \
  "$INFO_PLIST" \
  "$ENTITLEMENTS_PLIST" \
  "$PRIVACY_MANIFEST" \
  "$GOOGLE_SERVICE_INFO_PLIST" \
  "$LAUNCH_SCREEN_STORYBOARD" \
  "$PODFILE" \
  "$APP_FRAMEWORK_INFO_PLIST" \
  "$XCODE_PROJECT" \
  "$RUNNER_SCHEME" \
  "$GENERATED_SWIFT_PACKAGE" \
  "$IOS_MINIMUM_VERSION" <<'PY'
import pathlib
import plistlib
import re
import sys

info_path = pathlib.Path(sys.argv[1])
entitlements_path = pathlib.Path(sys.argv[2])
privacy_manifest_path = pathlib.Path(sys.argv[3])
google_service_path = pathlib.Path(sys.argv[4])
launch_screen_path = pathlib.Path(sys.argv[5])
podfile_path = pathlib.Path(sys.argv[6])
framework_info_path = pathlib.Path(sys.argv[7])
xcode_project_path = pathlib.Path(sys.argv[8])
runner_scheme_path = pathlib.Path(sys.argv[9])
generated_package_path = pathlib.Path(sys.argv[10])
required_ios_version = sys.argv[11]

for path, label in (
    (info_path, "Info.plist"),
    (entitlements_path, "Runner.entitlements"),
    (privacy_manifest_path, "PrivacyInfo.xcprivacy"),
    (google_service_path, "GoogleService-Info.plist"),
    (launch_screen_path, "LaunchScreen.storyboard"),
    (podfile_path, "Podfile"),
    (framework_info_path, "Flutter/AppFrameworkInfo.plist"),
    (xcode_project_path, "Runner.xcodeproj/project.pbxproj"),
    (runner_scheme_path, "Runner.xcscheme"),
):
    if not path.exists():
        raise SystemExit(f"Missing {label}: {path}")

try:
    info = plistlib.loads(info_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"Invalid Info.plist: {exc}") from exc

required_ipad_orientations = {
    "UIInterfaceOrientationPortrait",
    "UIInterfaceOrientationPortraitUpsideDown",
    "UIInterfaceOrientationLandscapeLeft",
    "UIInterfaceOrientationLandscapeRight",
}
actual_ipad_orientations = set(info.get("UISupportedInterfaceOrientations~ipad", []))
if actual_ipad_orientations != required_ipad_orientations:
    raise SystemExit(
        "Info.plist must declare all four iPad orientations for App Store multitasking; "
        f"actual={sorted(actual_ipad_orientations)}."
    )
if info.get("ITSAppUsesNonExemptEncryption") is not False:
    raise SystemExit(
        "Info.plist must explicitly declare ITSAppUsesNonExemptEncryption=false."
    )

try:
    entitlements = plistlib.loads(entitlements_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"Invalid Runner.entitlements: {exc}") from exc

try:
    privacy_manifest = plistlib.loads(privacy_manifest_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"Invalid PrivacyInfo.xcprivacy: {exc}") from exc

if privacy_manifest.get("NSPrivacyTracking") is not False:
    raise SystemExit("PrivacyInfo.xcprivacy must explicitly disable tracking.")
if privacy_manifest.get("NSPrivacyTrackingDomains") != []:
    raise SystemExit(
        "PrivacyInfo.xcprivacy must not declare tracking domains while tracking is disabled."
    )
if privacy_manifest.get("NSPrivacyAccessedAPITypes") != []:
    raise SystemExit(
        "The Runner target must not claim required-reason APIs used only by bundled SDKs; each SDK owns its manifest."
    )

expected_data_types = {
    "NSPrivacyCollectedDataTypeName",
    "NSPrivacyCollectedDataTypePhoneNumber",
    "NSPrivacyCollectedDataTypeUserID",
    "NSPrivacyCollectedDataTypeDeviceID",
    "NSPrivacyCollectedDataTypePurchaseHistory",
    "NSPrivacyCollectedDataTypeOtherFinancialInfo",
    "NSPrivacyCollectedDataTypeGameplayContent",
    "NSPrivacyCollectedDataTypeOtherUserContent",
    "NSPrivacyCollectedDataTypeProductInteraction",
    "NSPrivacyCollectedDataTypeCrashData",
    "NSPrivacyCollectedDataTypePerformanceData",
}
data_entries = privacy_manifest.get("NSPrivacyCollectedDataTypes")
if not isinstance(data_entries, list):
    raise SystemExit("PrivacyInfo.xcprivacy must declare collected data types.")
actual_data_types = {
    entry.get("NSPrivacyCollectedDataType")
    for entry in data_entries
    if isinstance(entry, dict)
}
if actual_data_types != expected_data_types:
    missing = sorted(expected_data_types - actual_data_types)
    unexpected = sorted(actual_data_types - expected_data_types)
    raise SystemExit(
        "PrivacyInfo.xcprivacy data-type mismatch; "
        f"missing={missing}, unexpected={unexpected}."
    )
for entry in data_entries:
    if not isinstance(entry, dict):
        raise SystemExit("PrivacyInfo.xcprivacy data entries must be dictionaries.")
    if entry.get("NSPrivacyCollectedDataTypeTracking") is not False:
        raise SystemExit("No declared data type may be used for tracking.")
    if not isinstance(entry.get("NSPrivacyCollectedDataTypeLinked"), bool):
        raise SystemExit("Every declared data type must state whether it is linked.")
    purposes = entry.get("NSPrivacyCollectedDataTypePurposes")
    if not isinstance(purposes, list) or not purposes:
        raise SystemExit("Every declared data type must have a collection purpose.")

try:
    google_service = plistlib.loads(google_service_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"Invalid GoogleService-Info.plist: {exc}") from exc

background_modes = info.get("UIBackgroundModes") or []
if "remote-notification" not in background_modes:
    raise SystemExit(
        "Info.plist must declare remote-notification background mode for push delivery."
    )

app_attest_environment = str(
    entitlements.get("com.apple.developer.devicecheck.appattest-environment", "")
).strip()
if app_attest_environment != "production":
    raise SystemExit(
        "Runner.entitlements must set com.apple.developer.devicecheck.appattest-environment=production."
    )

aps_environment = str(entitlements.get("aps-environment", "")).strip()
if aps_environment != "production":
    raise SystemExit(
        "Runner.entitlements must set aps-environment=production for release push delivery."
    )

bundle_id = str(google_service.get("BUNDLE_ID", "")).strip()
project_id = str(google_service.get("PROJECT_ID", "")).strip()
app_id = str(google_service.get("GOOGLE_APP_ID", "")).strip()

if not bundle_id or bundle_id.startswith("com.example."):
    raise SystemExit("GoogleService-Info.plist must contain a real BUNDLE_ID.")
if not project_id:
    raise SystemExit("GoogleService-Info.plist must contain PROJECT_ID.")
if not app_id:
    raise SystemExit("GoogleService-Info.plist must contain GOOGLE_APP_ID.")

launch_storyboard = launch_screen_path.read_text()
if "<imageView" in launch_storyboard:
    raise SystemExit(
        "LaunchScreen.storyboard must not render a second branded native splash image."
    )
if "backgroundColor" not in launch_storyboard:
    raise SystemExit("LaunchScreen.storyboard must declare a solid background color.")

def version_tuple(raw: str) -> tuple[int, ...]:
    try:
        return tuple(int(part) for part in raw.split("."))
    except ValueError as exc:
        raise SystemExit(f"Invalid iOS deployment version: {raw}") from exc

required_version = version_tuple(required_ios_version)
podfile = podfile_path.read_text()
podfile_match = re.search(r"platform\s+:ios,\s*['\"]([^'\"]+)['\"]", podfile)
if podfile_match is None:
    raise SystemExit("Podfile must declare an explicit iOS deployment target.")
if version_tuple(podfile_match.group(1)) < required_version:
    raise SystemExit(
        f"Podfile iOS target {podfile_match.group(1)} is below {required_ios_version}."
    )

try:
    framework_info = plistlib.loads(framework_info_path.read_bytes())
except Exception as exc:
    raise SystemExit(f"Invalid Flutter/AppFrameworkInfo.plist: {exc}") from exc
framework_minimum = str(framework_info.get("MinimumOSVersion", "")).strip()
if not framework_minimum or version_tuple(framework_minimum) < required_version:
    raise SystemExit(
        "Flutter/AppFrameworkInfo.plist MinimumOSVersion must be at least "
        f"{required_ios_version}; found {framework_minimum or 'missing'}."
    )

xcode_project = xcode_project_path.read_text()
if "PrivacyInfo.xcprivacy in Resources" not in xcode_project:
    raise SystemExit(
        "Runner.xcodeproj must include PrivacyInfo.xcprivacy in the app resources phase."
    )
deployment_targets = re.findall(
    r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([0-9.]+);", xcode_project
)
if not deployment_targets:
    raise SystemExit("Runner Xcode project has no explicit deployment target.")
too_low_targets = [
    value for value in deployment_targets if version_tuple(value) < required_version
]
if too_low_targets:
    raise SystemExit(
        "Runner Xcode deployment targets below "
        f"{required_ios_version}: {', '.join(sorted(set(too_low_targets)))}"
    )

runner_scheme = runner_scheme_path.read_text()
if "Run Prepare Flutter Framework Script" not in runner_scheme:
    raise SystemExit("Runner scheme is missing the Flutter SwiftPM prepare pre-action.")
if 'xcode_backend.sh&quot; prepare' not in runner_scheme:
    raise SystemExit("Runner scheme does not invoke xcode_backend.sh prepare.")

if generated_package_path.exists():
    generated_package = generated_package_path.read_text()
    generated_match = re.search(r'\.iOS\("([^"]+)"\)', generated_package)
    if generated_match is None:
        raise SystemExit(
            "Generated Flutter Swift package has no explicit iOS platform."
        )
    if version_tuple(generated_match.group(1)) < required_version:
        raise SystemExit(
            "Generated Flutter Swift package target is below "
            f"{required_ios_version}; run "
            "`python3 tools/scripts/sync_ios_swiftpm_deployment_target.py "
            "--manifest apps/rayon_sports/ios/Flutter/ephemeral/Packages/"
            "FlutterGeneratedPluginSwiftPackage/Package.swift --minimum "
            f"{required_ios_version}` after Flutter configuration generation."
        )

print(
    "iOS release contract ok "
    f"({bundle_id}, project {project_id}, minimum iOS {required_ios_version})"
)
PY
