import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { validateIosQaIsolation } from "./validate_ios_qa_isolation.mjs";
import { validateAndroidQaIsolation } from "./validate_mobile_qa_isolation.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const app = path.join(root, "apps/as_vita");
const projectPath = "Runner.xcodeproj/project.pbxproj";
const fixtureFiles = [projectPath, "Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme",
  "Runner.xcodeproj/xcshareddata/xcschemes/qa.xcscheme", "Podfile", "Runner/Info.plist",
  "Runner/RunnerQA.entitlements", "Flutter/Debug.xcconfig", "Flutter/Release.xcconfig",
  "Flutter/AppFrameworkInfo.plist", "Flutter/Debug-qa.xcconfig", "Flutter/Profile-qa.xcconfig"];

function fixture(t) {
  const ios = fs.mkdtempSync(path.join(os.tmpdir(), "africlub-native-qa-"));
  t.after(() => fs.rmSync(ios, { recursive: true, force: true }));
  for (const relative of fixtureFiles) {
    const destination = path.join(ios, relative);
    fs.mkdirSync(path.dirname(destination), { recursive: true });
    fs.copyFileSync(path.join(app, "ios", relative), destination);
  }
  return ios;
}
function change(ios, relative, from, to) {
  const file = path.join(ios, relative);
  const before = fs.readFileSync(file, "utf8");
  const after = before.replace(from, to);
  assert.notEqual(after, before, "Mutation must change the intended source");
  fs.writeFileSync(file, after);
}
const gradle = fs.readFileSync(path.join(app, "android/app/build.gradle.kts"), "utf8");

test("workspace and club packages contain the five supported products", () => {
  const expected = ["as_vita", "costa_do_sol", "nkana", "rayon_sports", "vitalo"];
  const workspace = fs.readFileSync(path.join(root, "pubspec.yaml"), "utf8");
  const appEntries = [...workspace.matchAll(/^  - apps\/([^\s]+)$/gm)].map((match) => match[1]);
  const clubEntries = [...workspace.matchAll(/^  - packages\/clubs\/club_([^\s]+)$/gm)].map((match) => match[1]);
  assert.deepEqual(fs.readdirSync(path.join(root, "apps")).filter((slug) => fs.statSync(path.join(root, "apps", slug)).isDirectory()).sort(), expected);
  assert.deepEqual(appEntries.sort(), expected);
  assert.deepEqual(clubEntries.sort(), expected);
  assert.deepEqual(fs.readdirSync(path.join(root, "packages/clubs")).filter((slug) => fs.statSync(path.join(root, "packages/clubs", slug)).isDirectory()).sort(), expected.map((slug) => `club_${slug}`));
  const ids = { as_vita: "6", costa_do_sol: "1001", nkana: "26", rayon_sports: "24", vitalo: "44" };
  const countries = { as_vita: "CD", costa_do_sol: "MZ", nkana: "ZM", rayon_sports: "RW", vitalo: "BI" };
  for (const slug of expected) {
    const flavor = JSON.parse(fs.readFileSync(path.join(root, "apps", slug, "assets/flavors/production.json"), "utf8"));
    assert.equal(String(flavor.CLUB_ID), ids[slug], `${slug} retains its tenant identity`);
    const config = fs.readFileSync(path.join(root, "packages/clubs", `club_${slug}`, "lib/src", `${slug}_config.dart`), "utf8");
    assert.match(config, new RegExp(`String get countryCode => '${countries[slug]}'`));
  }
});

test("all configured clubs have unique iOS QA IDs and Android debug/profile isolation", () => {
  const clubs = fs.readdirSync(path.join(root, "apps")).filter((slug) =>
    fs.existsSync(path.join(root, "apps", slug, "assets/flavors/production.json")) ||
    fs.existsSync(path.join(root, "apps", slug, "assets/flavors/production.example.json")));
  assert.deepEqual(clubs.sort(), ["as_vita", "costa_do_sol", "nkana", "rayon_sports", "vitalo"]);
  const identities = clubs.map((slug) => {
    const directory = path.join(root, "apps", slug);
    validateAndroidQaIsolation(fs.readFileSync(path.join(directory, "android/app/build.gradle.kts"), "utf8"));
    return validateIosQaIsolation(path.join(directory, "ios"));
  });
  assert.equal(new Set(identities.map((entry) => entry.qaId)).size, clubs.length);
});

test("missing iOS base configuration fails even when the project still references it", (t) => {
  const ios = fixture(t);
  fs.unlinkSync(path.join(ios, "Flutter/Debug.xcconfig"));
  assert.throws(() => validateIosQaIsolation(ios), /Debug.xcconfig/);
});

test("project QA ID cannot override a correct xcconfig with the production ID", (t) => {
  const ios = fixture(t);
  change(ios, projectPath, "PRODUCT_BUNDLE_IDENTIFIER = cd.ikanisa.asVita.qa.codex;", "PRODUCT_BUNDLE_IDENTIFIER = cd.ikanisa.asVita;");
  assert.throws(() => validateIosQaIsolation(ios), /Runner identity/);
});

test("an unlinked QA configuration does not count as an available Runner configuration", (t) => {
  const ios = fixture(t);
  change(ios, projectPath, /\t\t[A-F0-9]{24} \/\* Build configuration list for PBXNativeTarget "Runner" \*\/ = \{[\s\S]*?^\t\t\};/m,
    (block) => block.replace(/^.*\/\* Debug-qa \*\/,\n/m, ""));
  assert.throws(() => validateIosQaIsolation(ios), /Debug-qa must be linked/);
});

test("QA entitlements reject production capabilities", (t) => {
  const ios = fixture(t);
  change(ios, "Runner/RunnerQA.entitlements", "<dict/>", "<dict><key>aps-environment</key><string>production</string></dict>");
  assert.throws(() => validateIosQaIsolation(ios));
});

test("iOS profiling cannot silently launch a debug configuration", (t) => {
  const ios = fixture(t);
  change(ios, "Runner.xcodeproj/xcshareddata/xcschemes/qa.xcscheme", '<ProfileAction buildConfiguration="Profile-qa"', '<ProfileAction buildConfiguration="Debug-qa"');
  assert.throws(() => validateIosQaIsolation(ios), /Profile-qa/);
});

test("QA cannot be added to the archive build action", (t) => {
  const ios = fixture(t);
  change(ios, "Runner.xcodeproj/xcshareddata/xcschemes/qa.xcscheme", 'buildForArchiving="NO"', 'buildForArchiving="YES"');
  assert.throws(() => validateIosQaIsolation(ios), /buildForArchiving/);
});

test("the profile Flutter mode must agree with the native QA configuration", (t) => {
  const ios = fixture(t);
  change(ios, "Flutter/Profile-qa.xcconfig", "FLUTTER_BUILD_MODE=profile", "FLUTTER_BUILD_MODE=debug");
  assert.throws(() => validateIosQaIsolation(ios), /FLUTTER_BUILD_MODE/);
});

test("debug suffix removal cannot be hidden by the profile suffix", () => {
  const removed = gradle.replace("applicationIdSuffix = isolatedNonReleaseApplicationIdSuffix", "// debug isolation removed");
  assert.throws(() => validateAndroidQaIsolation(removed), /applicationIdSuffix/);
});

test("aggregate Android tasks must reject QA suffixes when they include release work", () => {
  assert.throws(() => validateAndroidQaIsolation(gradle.replace("gradle.taskGraph.whenReady", "gradle.taskGraph.noGuard")), /taskGraph/);
});

test("an explicit Android release request must reject QA suffixes before configuration", () => {
  const removed = gradle.replace("isReleaseBuildRequested && isolatedNonReleaseApplicationIdSuffix != null", "false");
  assert.throws(() => validateAndroidQaIsolation(removed), /isReleaseBuildRequested/);
});

test("all clubs honor the dry-run signing environment before local production properties", () => {
  for (const slug of fs.readdirSync(path.join(root, "apps"))) {
    const file = path.join(root, "apps", slug, "android/app/build.gradle.kts");
    if (!fs.existsSync(file)) continue;
    const source = fs.readFileSync(file, "utf8");
    const body = source.match(/fun signingValue\([\s\S]*?^}/m)?.[0];
    assert.ok(body, `${slug} must have an explicit signing source resolver`);
    assert.ok(body.indexOf("System.getenv(envName)") < body.indexOf("keystoreProperties.getProperty"), slug);
  }
});
