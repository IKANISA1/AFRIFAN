#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const escaped = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

// Inspect named objects and configuration-list relationships in Xcode's source
// serialization. Resolved build settings still require xcodebuild on macOS.
function projectObjects(source) {
  const objects = new Map();
  const pattern = /^\t\t([A-F0-9]{24})(?: \/\*[^\n]*?\*\/)? = \{([\s\S]*?)(?:\n\t\t\};| \};$)/gm;
  for (const match of source.matchAll(pattern)) objects.set(match[1], match[2]);
  assert.ok(objects.size, "Xcode project objects must be readable");
  return objects;
}

function setting(source, key) {
  const match = source.match(new RegExp(`(?:^|[;\\n])\\s*${escaped(key)} = (?:"([^"\\n]*)"|([^;\\n]+));`));
  return (match?.[1] ?? match?.[2])?.trim();
}

function configurations(objects, owner) {
  const reference = setting(owner, "buildConfigurationList")?.split(" ")[0];
  const list = objects.get(reference);
  assert.ok(list, "Xcode owner must reference a configuration list");
  const ids = [...list.matchAll(/\b([A-F0-9]{24})\b/g)].map((match) => match[1]);
  return new Map(ids.map((id) => {
    const config = objects.get(id);
    assert.ok(config, `Configuration ${id} must exist`);
    return [setting(config, "name"), config];
  }));
}

export function validateIosQaIsolation(ios) {
  const read = (relative) => fs.readFileSync(path.join(ios, relative), "utf8");
  const project = read("Runner.xcodeproj/project.pbxproj");
  const objects = projectObjects(project);
  const runner = [...objects.values()].find((body) => setting(body, "isa") === "PBXNativeTarget" && setting(body, "name") === "Runner");
  const projectOwner = [...objects.values()].find((body) => setting(body, "isa") === "PBXProject");
  assert.ok(runner && projectOwner, "Runner and project owners must exist");
  const runnerConfigs = configurations(objects, runner);
  const projectConfigs = configurations(objects, projectOwner);
  const productionId = setting(runnerConfigs.get("Release") ?? "", "PRODUCT_BUNDLE_IDENTIFIER");
  assert.match(productionId ?? "", /^[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)+$/);
  assert.doesNotMatch(productionId, /\.qa\./, "Release must keep a production identity");
  const qaId = `${productionId}.qa.codex`;
  const usesPods = fs.existsSync(path.join(ios, "Podfile"));
  const productionScheme = read("Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme");
  const qaScheme = read("Runner.xcodeproj/xcshareddata/xcschemes/qa.xcscheme");

  for (const mode of ["Debug", "Profile", "Release"]) {
    assert.equal(setting(runnerConfigs.get(mode) ?? "", "PRODUCT_BUNDLE_IDENTIFIER"), productionId, `${mode} production identity`);
    assert.equal(setting(projectConfigs.get(mode) ?? "", "IPHONEOS_DEPLOYMENT_TARGET"), "15.5", `${mode} minimum iOS`);
  }
  for (const mode of ["Debug", "Release"]) {
    const config = read(`Flutter/${mode}.xcconfig`);
    assert.match(config, /#include "Generated\.xcconfig"/, `${mode} must load Flutter settings`);
    assert.match(config, /^AFRICLUB_DISPLAY_NAME=.+$/m);
    if (usesPods) assert.ok(config.includes(`Pods-Runner.${mode.toLowerCase()}.xcconfig`));
  }
  assert.match(read("Flutter/AppFrameworkInfo.plist"), /<key>MinimumOSVersion<\/key>\s*<string>15\.5<\/string>/);

  for (const mode of ["Debug", "Profile"]) {
    const name = `${mode}-qa`;
    const runnerConfig = runnerConfigs.get(name);
    assert.ok(runnerConfig && projectConfigs.has(name), `${name} must be linked by Runner and the project`);
    assert.equal(setting(runnerConfig, "PRODUCT_BUNDLE_IDENTIFIER"), qaId, `${name} Runner identity`);
    assert.equal(setting(runnerConfig, "CODE_SIGN_ENTITLEMENTS"), "Runner/RunnerQA.entitlements", `${name} entitlements`);
    assert.equal(setting(runnerConfig, "SKIP_INSTALL"), "YES", `${name} must not enter an archive`);
    const baseId = setting(runnerConfig, "baseConfigurationReference")?.split(" ")[0];
    assert.equal(setting(objects.get(baseId) ?? "", "path"), `Flutter/${name}.xcconfig`, `${name} base configuration`);
    const config = read(`Flutter/${name}.xcconfig`);
    assert.match(config, new RegExp(`^PRODUCT_BUNDLE_IDENTIFIER=${escaped(qaId)}$`, "m"));
    assert.match(config, /^AFRICLUB_DISPLAY_NAME=.+ QA$/m);
    assert.match(config, /^CODE_SIGN_ENTITLEMENTS=Runner\/RunnerQA\.entitlements$/m);
    assert.match(config, new RegExp(`^FLUTTER_BUILD_MODE=${mode.toLowerCase()}$`, "m"));
    if (usesPods) {
      assert.ok(config.includes(`Pods-Runner.${name.toLowerCase()}.xcconfig`));
      assert.match(config, /#include "Generated\.xcconfig"/);
      assert.match(read("Podfile"), new RegExp(`'${name}' => :${mode === "Debug" ? "debug" : "release"}`));
    } else {
      assert.ok(config.includes(`#include "${mode === "Debug" ? "Debug" : "Release"}.xcconfig"`));
      assert.doesNotMatch(config, /Pods[/-]/);
    }
  }

  assert.doesNotMatch(productionScheme, /(?:Debug|Profile)-qa/);
  assert.match(productionScheme, /buildConfiguration\s*=\s*"Release"/);
  assert.match(qaScheme, /<LaunchAction\b[^>]*buildConfiguration\s*=\s*"Debug-qa"/);
  assert.match(qaScheme, /<ProfileAction\b[^>]*buildConfiguration\s*=\s*"Profile-qa"/);
  assert.doesNotMatch(qaScheme, /buildForArchiving\s*=\s*"YES"/);
  assert.match(qaScheme, /buildForArchiving\s*=\s*"NO"/);
  assert.match(qaScheme, /xcode_backend\.sh&quot; prepare/);
  assert.match(read("Runner/Info.plist"), /<key>CFBundleDisplayName<\/key>\s*<string>\$\(AFRICLUB_DISPLAY_NAME\)<\/string>/);
  const entitlements = read("Runner/RunnerQA.entitlements");
  assert.match(entitlements, /<dict\s*\/>/);
  assert.doesNotMatch(entitlements, /<key>|aps-environment|associated-domains|appattest/);

  if (path.basename(path.dirname(ios)) === "rayon_sports") {
    assert.equal(productionId, "rw.ikanisa.rayonSports");
    assert.equal(usesPods, false);
    assert.match(project, /XCLocalSwiftPackageReference/);
    assert.match(project, /FlutterGeneratedPluginSwiftPackage/);
    assert.match(read("Runner/Runner.entitlements"), /aps-environment/);
    assert.match(read("Runner/Runner.entitlements"), /com\.apple\.developer\.associated-domains/);
  }
  return { productionId, qaId };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const apps = fs.readdirSync(path.join(root, "apps")).filter((slug) => fs.existsSync(path.join(root, "apps", slug, "assets/flavors/production.json")));
  const identities = apps.map((slug) => validateIosQaIsolation(path.join(root, "apps", slug, "ios")));
  assert.equal(new Set(identities.map((entry) => entry.productionId)).size, apps.length);
  assert.equal(new Set(identities.map((entry) => entry.qaId)).size, apps.length);
  console.log(`iOS source QA isolation valid for ${apps.length} clubs: separate debug/profile identities, empty QA entitlements and non-archive schemes. Native build/device evidence is separate.`);
}
