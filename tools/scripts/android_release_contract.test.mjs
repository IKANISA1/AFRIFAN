import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  parseFlutterPubspecVersion,
  RAYON_SPORTS_APPLICATION_ID,
  validateAndroidReleaseArtifact,
} from "./android_release_contract.mjs";

const repoRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);

const writeJson = (file, value) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, `${JSON.stringify(value, null, 2)}\n`);
};

const createFixture = (t) => {
  const appDir = fs.mkdtempSync(
    path.join(os.tmpdir(), "africlub-android-release-contract-"),
  );
  t.after(() => fs.rmSync(appDir, { recursive: true, force: true }));

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
    `<?xml version="1.0"?><manifest xmlns:android="http://schemas.android.com/apk/res/android" package="${RAYON_SPORTS_APPLICATION_ID}" android:versionCode="6" android:versionName="1.0.3"><application /></manifest>\n`,
  );
  fs.writeFileSync(artifactPath, Buffer.from([0x50, 0x4b, 0x03, 0x04, 0x01]));
  writeJson(path.join(manifestDirectory, "output-metadata.json"), {
    artifactType: { type: "MERGED_MANIFESTS", kind: "Directory" },
    applicationId: RAYON_SPORTS_APPLICATION_ID,
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
    applicationId: RAYON_SPORTS_APPLICATION_ID,
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
      bytes: 5,
    },
  );
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
