#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const androidGradle = fs.readFileSync(
  path.join(root, "apps/rayon_sports/android/app/build.gradle.kts"),
  "utf8",
);
const performanceTest = fs.readFileSync(
  path.join(root, "apps/rayon_sports/integration_test/profile_performance_test.dart"),
  "utf8",
);
const smokeTest = fs.readFileSync(
  path.join(
    root,
    "apps/rayon_sports/integration_test/release_readiness_smoke_test.dart",
  ),
  "utf8",
);
const androidManifest = fs.readFileSync(
  path.join(
    root,
    "apps/rayon_sports/android/app/src/main/AndroidManifest.xml",
  ),
  "utf8",
);

assert.match(androidGradle, /gradleProperty\("africlubDebugApplicationIdSuffix"\)/);
assert.match(androidGradle, /debug\s*\{[\s\S]*applicationIdSuffix = isolatedNonReleaseApplicationIdSuffix/);
assert.match(androidGradle, /getByName\("profile"\)\s*\{[\s\S]*applicationIdSuffix = isolatedNonReleaseApplicationIdSuffix/);
assert.match(androidGradle, /isReleaseBuildRequested[\s\S]*error\("africlubDebugApplicationIdSuffix is allowed only for isolated debug\/profile device validation\."\)/);
assert.match(performanceTest, /AFRICLUB_PHYSICAL_DEVICE_PROFILE/);
assert.match(performanceTest, /'physical_device_claimed': physicalDeviceProfile/);
assert.match(performanceTest, /_scrollHomeUntilVisible\(tester, find\.byType\(QuickActionsGrid\)\)/);
assert.match(
  performanceTest,
  /storeReleasePolicyProvider\.overrideWithValue\([\s\S]*StoreReleasePolicy\.unenforced\(\)/,
);
assert.match(smokeTest, /DeepLinkParser\(customScheme: 'gikundiro'\)/);
assert.match(smokeTest, /FakeDeepLinkService\(stream: links\.stream\)/);
assert.match(smokeTest, /links\.add\(Uri\.parse\('gikundiro:\/\/settings'\)\)/);
assert.match(smokeTest, /ConnectivityService\.setOnlineForTest\(false\)/);
assert.match(smokeTest, /find\.text\('Offline settings'\)/);
assert.match(smokeTest, /find\.text\('Sign out\?'\)/);
assert.match(smokeTest, /tester\.tap\(find\.text\('Stay'\)\)/);
assert.match(androidManifest, /android:scheme="gikundiro"/);
assert.match(androidManifest, /android:scheme="africlub"/);
assert.match(androidManifest, /android\.intent\.category\.BROWSABLE/);

console.log(
  "Mobile QA isolation valid: Android debug/profile suffixes, release rejection, physical-profile attestation, custom-scheme manifests, and controlled deep-link/offline/destructive-cancel smoke contracts are guarded",
);
