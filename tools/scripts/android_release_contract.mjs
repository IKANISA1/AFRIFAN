#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

export const RAYON_SPORTS_APPLICATION_ID = "rw.gikundiro.app";
export const BUNDLETOOL_VERSION = "1.18.1";

const fail = (message) => {
  throw new Error(message);
};

export function parseDeclaredAndroidApplicationId(gradleContents) {
  // This repository declares one literal production ID per Flutter shell.
  // Preserve quoted strings while removing comments; reject expressions and
  // multiple declarations instead of guessing a Gradle variant's identity.
  const source = gradleContents.replace(
    /"(?:\\.|[^"\\])*"|\/\*[\s\S]*?\*\/|\/\/[^\r\n]*/g,
    (token) => token.startsWith('"') ? token : "",
  );
  const declarations = [...source.matchAll(/^\s*applicationId\s*=\s*(.*?)\s*$/gm)];
  if (declarations.length !== 1) {
    fail(`Android source must declare exactly one production applicationId; found ${declarations.length}`);
  }
  const match = declarations[0][1].match(/^"([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+)"$/);
  if (!match) fail("Android applicationId must be a literal package identifier.");
  return match[1];
}

export function readDeclaredAndroidApplicationId(appDir) {
  if (!appDir) fail("An app directory is required to resolve its applicationId.");
  const applicationId = parseDeclaredAndroidApplicationId(fs.readFileSync(
    path.join(appDir, "android/app/build.gradle.kts"), "utf8",
  ));
  if (path.basename(path.resolve(appDir)) === "rayon_sports"
    && applicationId !== RAYON_SPORTS_APPLICATION_ID) {
    fail(`Rayon release identity must remain ${RAYON_SPORTS_APPLICATION_ID}.`);
  }
  return applicationId;
}

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

function bundletool(argumentsList) {
  const jar = process.env.BUNDLETOOL_JAR;
  const classpath = process.env.BUNDLETOOL_CLASSPATH;
  if (jar && classpath) fail("Set only one of BUNDLETOOL_JAR or BUNDLETOOL_CLASSPATH.");
  const java = process.env.JAVA_HOME ? path.join(process.env.JAVA_HOME, "bin/java") : "java";
  const executable = jar || classpath ? java : "bundletool";
  const argumentsPrefix = jar
    ? ["-Xmx256m", "-jar", realpath(jar, "bundletool JAR")]
    : classpath ? ["-Xmx256m", "-cp", classpath, "com.android.tools.build.bundletool.BundleToolMain"] : [];
  const result = spawnSync(executable, [...argumentsPrefix, ...argumentsList], {
    encoding: "utf8", timeout: 30_000, maxBuffer: 4 * 1024 * 1024,
  });
  if (result.error || result.status !== 0) {
    // Bundle metadata can contain provider values. Do not echo an entire Java
    // stack trace or manifest while reporting a rejected artifact.
    fail(`bundletool ${argumentsList[0]} failed (${result.error?.code ?? result.status ?? "signal"}). `
      + "Use the pinned bundletool JAR and Java, then inspect the bundle locally.");
  }
  return result.stdout.trim();
}

export function validateBundletoolToolchain() {
  const version = bundletool(["version"]);
  requireEqual(version, BUNDLETOOL_VERSION, "bundletool version");
  return version;
}

function hashFile(file) {
  const handle = fs.openSync(file, "r");
  const hash = createHash("sha256");
  const buffer = Buffer.alloc(128 * 1024);
  try {
    let bytes;
    while ((bytes = fs.readSync(handle, buffer, 0, buffer.length, null)) > 0) hash.update(buffer.subarray(0, bytes));
  } finally {
    fs.closeSync(handle);
  }
  return hash.digest("hex");
}

export function validateAndroidReleaseArtifact({
  appDir,
  artifactPath,
  expectedApplicationId,
  expectedVersionName,
  expectedVersionCode,
}) {
  if (!appDir || !artifactPath || !expectedVersionName || !expectedVersionCode) {
    fail(
      "appDir, artifactPath, expectedVersionName, and expectedVersionCode are required",
    );
  }

  const resolvedAppDir = realpath(appDir, "Flutter app directory");
  expectedApplicationId ??= readDeclaredAndroidApplicationId(resolvedAppDir);
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

  const bundletoolVersion = validateBundletoolToolchain();
  const artifactSha256 = hashFile(resolvedArtifact);
  bundletool(["validate", `--bundle=${resolvedArtifact}`]);
  // Read the manifest actually inside the submitted AAB. Gradle sidecars alone
  // cannot detect a truncated file or another app copied over the output path.
  const archiveManifest = bundletool(["dump", "manifest", `--bundle=${resolvedArtifact}`, "--module=base"]);
  const archiveManifestTag = archiveManifest.match(/<manifest\b[^>]*>/)?.[0];
  if (!archiveManifestTag) fail("The Android App Bundle has no base manifest.");
  requireEqual(xmlAttribute(archiveManifestTag, "package"), expectedApplicationId, "AAB manifest package");
  requireEqual(xmlAttribute(archiveManifestTag, "android:versionName"), expectedVersionName, "AAB manifest versionName");
  requireEqual(xmlAttribute(archiveManifestTag, "android:versionCode"), expectedVersionCode, "AAB manifest versionCode");
  requireEqual(hashFile(resolvedArtifact), artifactSha256, "AAB bytes changed during validation");
  const finalStat = fs.statSync(resolvedArtifact);
  requireEqual(finalStat.size, artifactStat.size, "AAB size changed during validation");
  requireEqual(finalStat.mtimeMs, artifactStat.mtimeMs, "AAB modification time changed during validation");

  return {
    applicationId: expectedApplicationId,
    versionName: expectedVersionName,
    versionCode: String(expectedVersionCode),
    artifactPath: resolvedArtifact,
    bytes: artifactStat.size,
    sha256: artifactSha256,
    archiveValidated: true,
    bundletoolVersion,
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

  if (command === "toolchain") {
    process.stdout.write(`${validateBundletoolToolchain()}\n`);
    return;
  }

  if (command === "application-id") {
    if (!options["app-dir"]) fail("application-id requires --app-dir <path>");
    process.stdout.write(`${readDeclaredAndroidApplicationId(options["app-dir"])}\n`);
    return;
  }

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
      expectedApplicationId: options["expected-application-id"],
      expectedVersionName: options["expected-version-name"],
      expectedVersionCode: options["expected-version-code"],
    });
    process.stdout.write(
      `Android release artifact contract valid: ${result.applicationId} ${result.versionName}+${result.versionCode} (${result.bytes} bytes)\n`,
    );
    return;
  }

  fail("usage: android_release_contract.mjs <application-id|version|validate> [options]");
}

if (process.argv[1] && fileURLToPath(import.meta.url) === path.resolve(process.argv[1])) {
  try {
    runCli();
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
