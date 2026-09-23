#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
function gradleBlock(source, pattern) {
  const declaration = pattern.exec(source);
  assert.ok(declaration, `Gradle block missing: ${pattern}`);
  const start = declaration.index + declaration[0].length;
  const tokens = /"(?:\\.|[^"\\])*"|[{}]/g;
  tokens.lastIndex = start;
  let depth = 1;
  for (let token = tokens.exec(source); token; token = tokens.exec(source)) {
    if (token[0] === "{") depth += 1;
    if (token[0] === "}") depth -= 1;
    if (depth === 0) return source.slice(start, token.index);
  }
  throw new Error(`Unclosed Gradle block: ${pattern}`);
}

export function validateAndroidQaIsolation(androidGradle) {
  androidGradle = androidGradle.replace(/"(?:\\.|[^"\\])*"|\/\*[\s\S]*?\*\/|\/\/[^\r\n]*/g,
    (token) => token.startsWith('"') ? token : "");
  assert.match(androidGradle, /gradleProperty\("africlubDebugApplicationIdSuffix"\)/);
  const buildTypes = gradleBlock(androidGradle, /buildTypes\s*\{/);
  for (const pattern of [/debug\s*\{/, /getByName\("profile"\)\s*\{/]) {
    assert.match(gradleBlock(buildTypes, pattern), /applicationIdSuffix = isolatedNonReleaseApplicationIdSuffix/);
  }
  assert.doesNotMatch(gradleBlock(buildTypes, /release\s*\{/), /applicationIdSuffix/);
  assert.match(androidGradle, /if \(isReleaseBuildRequested && isolatedNonReleaseApplicationIdSuffix != null\) \{\s*error\("africlubDebugApplicationIdSuffix is allowed only for isolated debug\/profile device validation\."\)/);
  assert.match(androidGradle, /gradle\.taskGraph\.whenReady\s*\{\s*if \(allTasks\.any \{ it\.project == project && it\.name\.contains\("release", ignoreCase = true\) \}\) \{\s*error\("africlubDebugApplicationIdSuffix is allowed only for isolated debug\/profile device validation\."\)/);
  assert.match(androidGradle, /require\(Regex\([\s\S]*?\.matches\(isolatedNonReleaseApplicationIdSuffix\)\)/);
}

export function validateMobileQaIsolation(repoRoot = root) {
  const apps = fs.readdirSync(path.join(repoRoot, "apps"))
    .filter((slug) => fs.existsSync(path.join(repoRoot, "apps", slug, "assets/flavors/production.json")));
  for (const slug of apps) validateAndroidQaIsolation(fs.readFileSync(path.join(repoRoot, "apps", slug, "android/app/build.gradle.kts"), "utf8"));
  const performanceTest = fs.readFileSync(
    path.join(repoRoot, "apps/rayon_sports/integration_test/profile_performance_test.dart"),
    "utf8",
  );
  const smokeTest = fs.readFileSync(
    path.join(
      repoRoot,
      "apps/rayon_sports/integration_test/release_readiness_smoke_test.dart",
    ),
    "utf8",
  );
  const androidManifest = fs.readFileSync(
    path.join(
      repoRoot,
      "apps/rayon_sports/android/app/src/main/AndroidManifest.xml",
    ),
    "utf8",
  );

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

  return { apps: apps.length };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = validateMobileQaIsolation();
  console.log(`Mobile source QA isolation valid for ${result.apps} clubs: Android debug/profile suffixes and release guards, plus the Rayon deep-link, offline and physical-profile test contracts. Native build/device evidence is separate.`);
}
