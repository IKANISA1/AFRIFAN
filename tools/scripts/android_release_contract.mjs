#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const RAYON_SPORTS_APPLICATION_ID = "rw.gikundiro.app";

const fail = (message) => {
  throw new Error(message);
};

const stripYamlScalar = (rawValue) => {
  const value = rawValue.trim();
  if (value.startsWith('"')) {
    const match = value.match(/^("(?:[^"\\]|\\.)*")(?:\s+#.*)?$/);
    if (!match) {
      fail("pubspec.yaml version has an invalid double-quoted scalar");
    }
    return JSON.parse(match[1]);
  }
  if (value.startsWith("'")) {
    const match = value.match(/^'((?:[^']|'')*)'(?:\s+#.*)?$/);
    if (!match) {
      fail("pubspec.yaml version has an invalid single-quoted scalar");
    }
    return match[1].replaceAll("''", "'");
  }
  return value.replace(/\s+#.*$/, "").trim();
};

export function parseFlutterPubspecVersion(pubspecContents) {
  const declarations = pubspecContents
    .split(/\r?\n/)
    .map((line) => line.match(/^version\s*:\s*(.*?)\s*$/))
    .filter(Boolean);

  if (declarations.length !== 1) {
    fail(
      `pubspec.yaml must contain exactly one top-level version declaration; found ${declarations.length}`,
    );
  }

  const declaredVersion = stripYamlScalar(declarations[0][1]);
  const match = declaredVersion.match(/^([^+\s]+)\+([1-9][0-9]*)$/);
  if (!match) {
    fail(
      "pubspec.yaml version must use <build-name>+<positive-integer-build-number>",
    );
  }

  return {
    declaredVersion,
    buildName: match[1],
    buildNumber: match[2],
  };
}

const readJson = (file, label) => {
  let raw;
  try {
    raw = fs.readFileSync(file, "utf8");
  } catch (error) {
    fail(`${label} is missing or unreadable: ${file} (${error.message})`);
  }
  try {
    return JSON.parse(raw);
  } catch (error) {
    fail(`${label} is not valid JSON: ${file} (${error.message})`);
  }
};

const requireEqual = (actual, expected, label) => {
  if (String(actual) !== String(expected)) {
    fail(`${label} mismatch: expected ${expected}, found ${actual}`);
  }
};

const requireSingleElement = (metadata, label) => {
  if (!Array.isArray(metadata.elements) || metadata.elements.length !== 1) {
    fail(`${label} must describe exactly one release artifact`);
  }
  return metadata.elements[0];
};

const xmlAttribute = (manifestTag, attributeName) => {
  const escapedName = attributeName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = manifestTag.match(
    new RegExp(`(?:^|\\s)${escapedName}\\s*=\\s*(["'])(.*?)\\1`),
  );
  return match?.[2];
};

const realpath = (file, label) => {
  try {
    return fs.realpathSync(file);
  } catch (error) {
    fail(`${label} does not resolve to a file: ${file} (${error.message})`);
  }
};

export function validateAndroidReleaseArtifact({
  appDir,
  artifactPath,
  expectedApplicationId = RAYON_SPORTS_APPLICATION_ID,
  expectedVersionName,
  expectedVersionCode,
}) {
  if (!appDir || !artifactPath || !expectedVersionName || !expectedVersionCode) {
    fail(
      "appDir, artifactPath, expectedVersionName, and expectedVersionCode are required",
    );
  }

  const resolvedAppDir = realpath(appDir, "Flutter app directory");
  const resolvedArtifact = realpath(artifactPath, "Android App Bundle");
  const artifactStat = fs.statSync(resolvedArtifact);
  if (!artifactStat.isFile() || artifactStat.size === 0) {
    fail(`Android App Bundle is empty or not a regular file: ${resolvedArtifact}`);
  }
  const zipMagic = Buffer.alloc(4);
  const artifactHandle = fs.openSync(resolvedArtifact, "r");
  try {
    fs.readSync(artifactHandle, zipMagic, 0, zipMagic.length, 0);
  } finally {
    fs.closeSync(artifactHandle);
  }
  if (zipMagic.length < 4 || zipMagic[0] !== 0x50 || zipMagic[1] !== 0x4b) {
    fail(`Android App Bundle is not a ZIP/JAR artifact: ${resolvedArtifact}`);
  }

  const mergedMetadataPath = path.join(
    resolvedAppDir,
    "build/app/intermediates/merged_manifests/release/processReleaseManifest/output-metadata.json",
  );
  const mergedMetadata = readJson(
    mergedMetadataPath,
    "release merged-manifest output metadata",
  );
  requireEqual(
    mergedMetadata.artifactType?.type,
    "MERGED_MANIFESTS",
    "release merged-manifest artifact type",
  );
  requireEqual(mergedMetadata.variantName, "release", "merged-manifest variant");
  requireEqual(
    mergedMetadata.applicationId,
    expectedApplicationId,
    "merged-manifest applicationId",
  );

  const mergedElement = requireSingleElement(
    mergedMetadata,
    "release merged-manifest output metadata",
  );
  if (typeof mergedElement.outputFile !== "string" || !mergedElement.outputFile) {
    fail("release merged-manifest output metadata has no outputFile");
  }
  requireEqual(
    mergedElement.versionName,
    expectedVersionName,
    "merged-manifest versionName",
  );
  requireEqual(
    mergedElement.versionCode,
    expectedVersionCode,
    "merged-manifest versionCode",
  );

  const mergedManifestPath = path.resolve(
    path.dirname(mergedMetadataPath),
    mergedElement.outputFile,
  );
  const mergedManifest = fs.readFileSync(mergedManifestPath, "utf8");
  const manifestTag = mergedManifest.match(/<manifest\b[^>]*>/)?.[0];
  if (!manifestTag) {
    fail(`release merged manifest has no <manifest> element: ${mergedManifestPath}`);
  }
  requireEqual(
    xmlAttribute(manifestTag, "package"),
    expectedApplicationId,
    "release manifest package",
  );
  requireEqual(
    xmlAttribute(manifestTag, "android:versionName"),
    expectedVersionName,
    "release manifest android:versionName",
  );
  requireEqual(
    xmlAttribute(manifestTag, "android:versionCode"),
    expectedVersionCode,
    "release manifest android:versionCode",
  );

  const bundleMetadataPath = path.join(
    resolvedAppDir,
    "build/app/intermediates/bundle_ide_model/release/produceReleaseBundleIdeListingFile/output-metadata.json",
  );
  const bundleMetadata = readJson(bundleMetadataPath, "release bundle output metadata");
  requireEqual(
    bundleMetadata.artifactType?.type,
    "BUNDLE",
    "release bundle artifact type",
  );
  requireEqual(bundleMetadata.variantName, "release", "release bundle variant");
  requireEqual(
    bundleMetadata.applicationId,
    expectedApplicationId,
    "release bundle applicationId",
  );
  const bundleElement = requireSingleElement(
    bundleMetadata,
    "release bundle output metadata",
  );
  if (typeof bundleElement.outputFile !== "string" || !bundleElement.outputFile) {
    fail("release bundle output metadata has no outputFile");
  }
  const metadataArtifact = realpath(
    path.resolve(path.dirname(bundleMetadataPath), bundleElement.outputFile),
    "release bundle metadata artifact",
  );
  requireEqual(metadataArtifact, resolvedArtifact, "release bundle artifact path");

  return {
    applicationId: expectedApplicationId,
    versionName: expectedVersionName,
    versionCode: String(expectedVersionCode),
    artifactPath: resolvedArtifact,
    bytes: artifactStat.size,
  };
}

const parseArguments = (argumentsList) => {
  const values = {};
  for (let index = 0; index < argumentsList.length; index += 2) {
    const option = argumentsList[index];
    const value = argumentsList[index + 1];
    if (!option?.startsWith("--") || value === undefined) {
      fail(`invalid command-line arguments near ${option ?? "<end>"}`);
    }
    values[option.slice(2)] = value;
  }
  return values;
};

export function runCli(argumentsList = process.argv.slice(2)) {
  const [command, ...rest] = argumentsList;
  const options = parseArguments(rest);

  if (command === "version") {
    if (!options.pubspec) {
      fail("version requires --pubspec <path>");
    }
    const version = parseFlutterPubspecVersion(
      fs.readFileSync(options.pubspec, "utf8"),
    );
    process.stdout.write(`${version.buildName}\t${version.buildNumber}\n`);
    return;
  }

  if (command === "validate") {
    const result = validateAndroidReleaseArtifact({
      appDir: options["app-dir"],
      artifactPath: options.artifact,
      expectedApplicationId:
        options["expected-application-id"] ?? RAYON_SPORTS_APPLICATION_ID,
      expectedVersionName: options["expected-version-name"],
      expectedVersionCode: options["expected-version-code"],
    });
    process.stdout.write(
      `Android release artifact contract valid: ${result.applicationId} ${result.versionName}+${result.versionCode} (${result.bytes} bytes)\n`,
    );
    return;
  }

  fail("usage: android_release_contract.mjs <version|validate> [options]");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
