#!/usr/bin/env node

import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const ios = path.join(root, "apps/rayon_sports/ios");
const read = (relative) => fs.readFileSync(path.join(ios, relative), "utf8");

const project = read("Runner.xcodeproj/project.pbxproj");
const qaScheme = read("Runner.xcodeproj/xcshareddata/xcschemes/qa.xcscheme");
const productionScheme = read(
  "Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme",
);
const qaConfig = read("Flutter/Debug-qa.xcconfig");
const debugConfig = read("Flutter/Debug.xcconfig");
const releaseConfig = read("Flutter/Release.xcconfig");
const infoPlist = read("Runner/Info.plist");
const qaEntitlements = read("Runner/RunnerQA.entitlements");
const productionEntitlements = read("Runner/Runner.entitlements");

const productionId = "rw.ikanisa.rayonSports";
const qaId = "rw.ikanisa.rayonSports.qa.codex";

assert.match(project, /name = "Debug-qa";/);
assert.match(project, new RegExp(`PRODUCT_BUNDLE_IDENTIFIER = ${qaId.replaceAll(".", "\\.")};`));
assert.match(project, /CODE_SIGN_ENTITLEMENTS = Runner\/RunnerQA\.entitlements;/);
assert.match(project, new RegExp(`PRODUCT_BUNDLE_IDENTIFIER = ${productionId.replaceAll(".", "\\.")};`));

assert.match(qaScheme, /buildConfiguration="Debug-qa"/);
assert.doesNotMatch(qaScheme, /buildForArchiving="YES"/);
assert.match(productionScheme, /buildConfiguration = "Debug"/);
assert.doesNotMatch(productionScheme, /Debug-qa/);

assert.match(qaConfig, /PRODUCT_BUNDLE_IDENTIFIER=rw\.ikanisa\.rayonSports\.qa\.codex/);
assert.match(qaConfig, /AFRICLUB_DISPLAY_NAME=Gikundiro QA/);
assert.match(qaConfig, /CODE_SIGN_ENTITLEMENTS=Runner\/RunnerQA\.entitlements/);
assert.match(qaConfig, /#include "Debug\.xcconfig"/);
assert.doesNotMatch(qaConfig, /Pods[/-]/);
assert.match(project, /FlutterGeneratedPluginSwiftPackage/);
assert.match(project, /XCLocalSwiftPackageReference/);
assert.match(qaScheme, /xcode_backend\.sh&quot; prepare/);
assert.equal(fs.existsSync(path.join(ios, "Podfile")), false);
assert.match(debugConfig, /AFRICLUB_DISPLAY_NAME=Gikundiro/);
assert.match(releaseConfig, /AFRICLUB_DISPLAY_NAME=Gikundiro/);

assert.match(infoPlist, /<string>\$\(PRODUCT_BUNDLE_IDENTIFIER\)<\/string>/);
assert.match(infoPlist, /<string>\$\(AFRICLUB_DISPLAY_NAME\)<\/string>/);
assert.doesNotMatch(infoPlist, /<string>Gikundiro QA<\/string>/);

assert.match(qaEntitlements, /<dict\s*\/>/);
assert.doesNotMatch(qaEntitlements, /aps-environment|associated-domains|appattest/);
assert.match(productionEntitlements, /aps-environment/);
assert.match(productionEntitlements, /com\.apple\.developer\.associated-domains/);

console.log(
  `iOS QA isolation valid: ${qaId}, empty QA entitlements, production identity preserved`,
);
