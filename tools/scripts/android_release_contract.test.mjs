import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

import {
  parseDeclaredAndroidApplicationId,
  parseFlutterPubspecVersion,
  readDeclaredAndroidApplicationId,
  RAYON_SPORTS_APPLICATION_ID,
  validateAndroidReleaseArtifact,
  BUNDLETOOL_VERSION,
} from "./android_release_contract.mjs";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

const writeJson = (file, value) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
};

const writeBundle = (artifactPath, applicationId = RAYON_SPORTS_APPLICATION_ID, versionName = "1.0.3", versionCode = "6") => {
  const result = spawnSync("python3", [path.join(repoRoot, "tools/scripts/fixtures/android_bundle.py")], {
    input: JSON.stringify({ artifactPath, applicationId, versionName, versionCode }), encoding: "utf8",
  });
  assert.equal(result.status, 0, result.stderr);
};

const createFixture = (t, applicationId = RAYON_SPORTS_APPLICATION_ID) => {
  const appDir = fs.mkdtempSync(
    path.join(os.tmpdir(), "africlub-android-release-contract-"),
  );
  t.after(() => fs.rmSync(appDir, { recursive: true, force: true }));
  fs.mkdirSync(path.join(appDir, "android/app"), { recursive: true });
  fs.writeFileSync(path.join(appDir, "android/app/build.gradle.kts"),
    `android {\n  defaultConfig {\n    applicationId = "${applicationId}"\n  }\n}\n`);

  const manifestDirectory = path.join(
    appDir,
    "build/app/intermediates/merged_manifests/release/processReleaseManifest",
  );
  const bundleMetadataDirectory = path.join(
    appDir,
    "build/app/intermediates/bundle_ide_model/release/produceReleaseBundleIdeListingFile",
  );
  const artifactPath = path.join(
    appDir,
    "build/app/outputs/bundle/release/app-release.aab",
  );
  fs.mkdirSync(manifestDirectory, { recursive: true });
  fs.mkdirSync(path.dirname(artifactPath), { recursive: true });
  fs.writeFileSync(
    path.join(manifestDirectory, "AndroidManifest.xml"),
    `<?xml version="1.0"?><manifest xmlns:android="http://schemas.android.com/apk/res/android" package="${applicationId}" android:versionCode="6" android:versionName="1.0.3"><application /></manifest>\n`,
  );
  writeBundle(artifactPath, applicationId);
  writeJson(path.join(manifestDirectory, "output-metadata.json"), {
    artifactType: { type: "MERGED_MANIFESTS", kind: "Directory" },
    applicationId,
    variantName: "release",
    elements: [
      {
        type: "SINGLE",
        filters: [],
        versionCode: 6,
        versionName: "1.0.3",
        outputFile: "AndroidManifest.xml",
      },
    ],
  });
  writeJson(path.join(bundleMetadataDirectory, "output-metadata.json"), {
    artifactType: { type: "BUNDLE", kind: "RegularFile" },
    applicationId,
    variantName: "release",
    elements: [
      {
        type: "SINGLE",
        filters: [],
        outputFile: "../../../../outputs/bundle/release/app-release.aab",
      },
    ],
  });

  return { appDir, artifactPath, manifestDirectory, bundleMetadataDirectory };
};

test("parses unquoted and quoted Flutter build versions", () => {
  assert.deepEqual(parseFlutterPubspecVersion("name: app\nversion: 1.0.3+6\n"), {
    declaredVersion: "1.0.3+6",
    buildName: "1.0.3",
    buildNumber: "6",
  });
  assert.deepEqual(
    parseFlutterPubspecVersion('name: app\nversion: "2.0.0-beta.1+17" # release\n'),
    {
      declaredVersion: "2.0.0-beta.1+17",
      buildName: "2.0.0-beta.1",
      buildNumber: "17",
    },
  );
});

test("resolves all configured club identities from their own Android sources", () => {
  const apps = fs.readdirSync(path.join(repoRoot, "apps"))
    .filter((slug) => fs.existsSync(path.join(repoRoot, "apps", slug, "assets/flavors/production.json")));
  const identities = apps.map((slug) => readDeclaredAndroidApplicationId(path.join(repoRoot, "apps", slug)));
  assert.equal(new Set(identities).size, apps.length);
  assert.equal(identities[apps.indexOf("rayon_sports")], RAYON_SPORTS_APPLICATION_ID);
  assert.equal(identities[apps.indexOf("as_vita")], "cd.ikanisa.as_vita");
});

test("comments cannot replace an ID and ambiguous or computed IDs fail closed", () => {
  assert.equal(parseDeclaredAndroidApplicationId('// applicationId = "wrong.id"\napplicationId = "cd.ikanisa.as_vita" // actual'), "cd.ikanisa.as_vita");
  for (const source of [
    '/*\n applicationId = "wrong.id"\n*/',
    'applicationId = "one.id"\napplicationId = "two.id"',
    'applicationId = providers.gradleProperty("package").get()',
    'applicationId = "${rootProject.name}.app"',
  ]) assert.throws(() => parseDeclaredAndroidApplicationId(source));
});

test("another club's release metadata does not require the Rayon ID", (t) => {
  const fixture = createFixture(t, "cd.ikanisa.as_vita");
  const result = validateAndroidReleaseArtifact({
    ...fixture, expectedVersionName: "1.0.3", expectedVersionCode: "6",
  });
  assert.equal(result.applicationId, "cd.ikanisa.as_vita");
  assert.throws(() => validateAndroidReleaseArtifact({
    ...fixture, expectedApplicationId: RAYON_SPORTS_APPLICATION_ID,
    expectedVersionName: "1.0.3", expectedVersionCode: "6",
  }), /applicationId mismatch/);
});

test("the all-club dry-run resolves identity before building", () => {
  const script = fs.readFileSync(path.join(repoRoot, "tools/scripts/dry_run_android_release.sh"), "utf8");
  assert.match(script, /application-id --app-dir "\$APP_DIR"/);
  assert.doesNotMatch(script, /EXPECTED_APPLICATION_ID="rw\.gikundiro\.app"/);
  assert.ok(script.indexOf('application-id --app-dir "$APP_DIR"') < script.indexOf("flutter build appbundle"));
});

test("rejects missing, duplicate, and non-numeric build numbers", () => {
  assert.throws(
    () => parseFlutterPubspecVersion("name: app\n"),
    /exactly one top-level version declaration/,
  );
  assert.throws(
    () => parseFlutterPubspecVersion("version: 1.0.0+1\nversion: 1.0.1+2\n"),
    /exactly one top-level version declaration/,
  );
  assert.throws(
    () => parseFlutterPubspecVersion("version: 1.0.0+candidate\n"),
    /positive-integer-build-number/,
  );
});

test("accepts one AAB tied to the exact release manifest and bundle metadata", (t) => {
  const fixture = createFixture(t);
  assert.deepEqual(
    validateAndroidReleaseArtifact({
      ...fixture,
      expectedVersionName: "1.0.3",
      expectedVersionCode: "6",
    }),
    {
      applicationId: RAYON_SPORTS_APPLICATION_ID,
      versionName: "1.0.3",
      versionCode: "6",
      artifactPath: fs.realpathSync(fixture.artifactPath),
      bytes: fs.statSync(fixture.artifactPath).size,
      sha256: createHash("sha256").update(fs.readFileSync(fixture.artifactPath)).digest("hex"),
      archiveValidated: true,
      bundletoolVersion: BUNDLETOOL_VERSION,
    },
  );
});

test("matching sidecars cannot make a truncated ZIP into an accepted AAB", (t) => {
  const fixture = createFixture(t);
  fs.writeFileSync(fixture.artifactPath, Buffer.from([0x50, 0x4b, 0x03, 0x04, 0x01]));
  assert.throws(() => validateAndroidReleaseArtifact({ ...fixture,
    expectedVersionName: "1.0.3", expectedVersionCode: "6",
  }), /bundletool validate failed/);
});

test("matching sidecars cannot conceal another package inside the AAB", (t) => {
  const fixture = createFixture(t);
  writeBundle(fixture.artifactPath, "cd.ikanisa.as_vita");
  assert.throws(() => validateAndroidReleaseArtifact({ ...fixture,
    expectedVersionName: "1.0.3", expectedVersionCode: "6",
  }), /AAB manifest package mismatch/);
});

test("matching sidecars cannot conceal a stale version inside the AAB", (t) => {
  const fixture = createFixture(t);
  writeBundle(fixture.artifactPath, RAYON_SPORTS_APPLICATION_ID, "1.0.2", "5");
  assert.throws(() => validateAndroidReleaseArtifact({ ...fixture,
    expectedVersionName: "1.0.3", expectedVersionCode: "6",
  }), /AAB manifest versionName mismatch/);
});

test("rejects stale version metadata and an unexpected applicationId", (t) => {
  const fixture = createFixture(t);
  assert.throws(
    () =>
      validateAndroidReleaseArtifact({
        ...fixture,
        expectedVersionName: "1.0.3",
        expectedVersionCode: "7",
      }),
    /merged-manifest versionCode mismatch: expected 7, found 6/,
  );
  assert.throws(
    () =>
      validateAndroidReleaseArtifact({
        ...fixture,
        expectedApplicationId: "rw.example.wrong",
        expectedVersionName: "1.0.3",
        expectedVersionCode: "6",
      }),
    /merged-manifest applicationId mismatch/,
  );
});

test("rejects a final artifact that is not the bundle metadata output", (t) => {
  const fixture = createFixture(t);
  const metadataPath = path.join(
    fixture.bundleMetadataDirectory,
    "output-metadata.json",
  );
  const metadata = JSON.parse(fs.readFileSync(metadataPath, "utf8"));
  metadata.elements[0].outputFile = "different.aab";
  fs.writeFileSync(path.join(fixture.bundleMetadataDirectory, "different.aab"), "PKx");
  writeJson(metadataPath, metadata);

  assert.throws(
    () =>
      validateAndroidReleaseArtifact({
        ...fixture,
        expectedVersionName: "1.0.3",
        expectedVersionCode: "6",
      }),
    /release bundle artifact path mismatch/,
  );
});

test("both Android release entrypoints pin the parsed build name and number", () => {
  let dryRunScript;
  for (const scriptName of [
    "build_signed_aab.sh",
    "dry_run_android_release.sh",
  ]) {
    const script = fs.readFileSync(
      path.join(repoRoot, "tools/scripts", scriptName),
      "utf8",
    );
    assert.match(script, /android_release_contract\.mjs/);
    assert.match(script, /version --pubspec "\$PUBSPEC_FILE"/);
    assert.match(script, /--build-name "\$BUILD_NAME"/);
    assert.match(script, /--build-number "\$BUILD_NUMBER"/);
    assert.match(script, /--expected-application-id "\$EXPECTED_APPLICATION_ID"/);
    assert.match(script, /--expected-version-name "\$BUILD_NAME"/);
    assert.match(script, /--expected-version-code "\$BUILD_NUMBER"/);
    assert.ok(script.indexOf('node "$RELEASE_CONTRACT" toolchain') < script.indexOf('version --pubspec'));
    if (scriptName === "dry_run_android_release.sh") {
      dryRunScript = script;
    }
  }

  assert.match(dryRunScript, /keytool -list -v/);
  assert.match(dryRunScript, /keytool -printcert -jarfile "\$ARTIFACT_PATH"/);
  assert.match(
    dryRunScript,
    /"\$actual_signer_sha256" != "\$expected_signer_sha256"/,
  );
});
