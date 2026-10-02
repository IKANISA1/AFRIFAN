import assert from "node:assert/strict";
import fs from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { parseReleaseScope, validateReleaseScope } from "./validate_release_scope.mjs";

const sourceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const scopePath = "docs/release/full_stack_qa_plan.md";

function fixture(t) {
  const root = fs.mkdtempSync(path.join(tmpdir(), "africlub-release-scope-"));
  t.after(() => fs.rmSync(root, { recursive: true, force: true }));
  const write = (relative, contents) => {
    fs.mkdirSync(path.dirname(path.join(root, relative)), { recursive: true });
    fs.writeFileSync(path.join(root, relative), contents);
  };
  const copy = (relative) => write(relative, fs.readFileSync(path.join(sourceRoot, relative)));
  copy(scopePath);
  copy("pubspec.yaml");
  for (const relative of [
    "packages/app_registry/lib/app_registry.dart",
    "packages/app_registry/lib/src/native_bootstrap.dart",
    "packages/app_registry/lib/src/module_registry.dart",
    "packages/core/core_app/lib/bootstrap.dart",
    "packages/core/core_app/lib/src/bootstrap.dart",
  ]) copy(relative);
  const clubs = parseReleaseScope(fs.readFileSync(path.join(root, scopePath), "utf8"));
  for (const { slug } of clubs) {
    const app = `apps/${slug}`;
    const club = `packages/clubs/club_${slug}`;
    for (const relative of ["pubspec.yaml", "lib/main.dart", "android/app/build.gradle.kts",
      "ios/Runner.xcodeproj/project.pbxproj",
      "ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme",
      "ios/Runner.xcodeproj/xcshareddata/xcschemes/qa.xcscheme",
      "ios/Flutter/Debug.xcconfig", "ios/Flutter/Release.xcconfig",
      "ios/Flutter/Debug-qa.xcconfig", "ios/Flutter/Profile-qa.xcconfig",
      "ios/Flutter/AppFrameworkInfo.plist", "ios/Runner/Info.plist",
      "ios/Runner/RunnerQA.entitlements"]) copy(`${app}/${relative}`);
    if (slug === "rayon_sports") copy(`${app}/ios/Runner/Runner.entitlements`);
    if (fs.existsSync(path.join(sourceRoot, app, "ios/Podfile"))) copy(`${app}/ios/Podfile`);
    copy(`${club}/pubspec.yaml`);
    copy(`${club}/lib/src/${slug}_config.dart`);
    // Fixtures retain identity values but never reproduce local backend keys.
    const production = JSON.parse(fs.readFileSync(path.join(sourceRoot, app, "assets/flavors/production.json"), "utf8"));
    production.SUPABASE_URL = "https://isolated.test";
    production.SUPABASE_ANON_KEY = "synthetic-test-input-unverified";
    write(`${app}/assets/flavors/production.json`, JSON.stringify(production));
  }
  return { root, write, run: () => validateReleaseScope(root), change(relative, operation) {
    write(relative, operation(fs.readFileSync(path.join(root, relative), "utf8")));
  } };
}

test("matching five-club source identities count ten targets without manufacturing release acceptance", (t) => {
  const result = fixture(t).run();
  assert.equal(result.scope_status, "pass");
  assert.equal(result.club_count, 5);
  assert.equal(result.native_target_count, 10);
  assert.equal(result.production_ready, false);
  assert.ok(result.clubs.every((club) => club.signing === "unverified" && club.releaseRegistration === "unverified"));
});

test("a four-club table cannot silently shrink the release scope", (t) => {
  const f = fixture(t);
  f.change(scopePath, (text) => text.replace(/^\| costa_do_sol \|.*\n/m, ""));
  assert.match(f.run().errors.join("\n"), /five clubs and ten native targets/);
});

test("missing Costa do Sol workspace registration fails even when its files exist", (t) => {
  const f = fixture(t);
  f.change("pubspec.yaml", (text) => text.replace("  - apps/costa_do_sol\n", ""));
  assert.match(f.run().errors.join("\n"), /Workspace app inventory differs/);
});

test("unregistered physical native shells fail independently of the workspace", (t) => {
  const f = fixture(t);
  f.write("apps/retired_shell/android/app/build.gradle.kts", "// retired native shell\n");
  assert.match(f.run().errors.join("\n"), /Physical app inventory differs/);
});

test("a symlinked native shell cannot hide from the physical scope inventory", (t) => {
  const f = fixture(t);
  fs.symlinkSync(path.join(f.root, "apps/nkana"), path.join(f.root, "apps/retired_alias"), "dir");
  assert.match(f.run().errors.join("\n"), /Physical app inventory differs/);
});

test("duplicate tenant registrations are rejected", (t) => {
  const f = fixture(t);
  f.change(scopePath, (text) => text.replace("| costa_do_sol | 1001 |", "| costa_do_sol | 24 |"));
  assert.match(f.run().errors.join("\n"), /Duplicate release tenant/);
});

test("a flavor pointed at another club fails tenant and country binding", (t) => {
  const f = fixture(t);
  f.change("apps/costa_do_sol/assets/flavors/production.json", (text) => {
    const config = JSON.parse(text); config.CLUB_ID = "24"; return JSON.stringify(config);
  });
  assert.match(f.run().errors.join("\n"), /Production tenant differs/);
});

test("wrong club config imports fail despite otherwise correct identity files", (t) => {
  const f = fixture(t);
  f.change("apps/costa_do_sol/lib/main.dart", (text) => text.replace("package:club_costa_do_sol/club_costa_do_sol.dart", "package:club_nkana/club_nkana.dart"));
  assert.match(f.run().errors.join("\n"), /imports the wrong club config/);
});

test("instantiating another club cannot reuse correct native identity files", (t) => {
  const f = fixture(t);
  f.change("apps/nkana/lib/main.dart", (text) => text.replace("NkanaConfig()", "RayonSportsConfig()"));
  assert.match(f.run().errors.join("\n"), /does not instantiate its declared club config/);
});

test("an unused shared helper cannot disguise a different core bootstrap config", (t) => {
  const f = fixture(t);
  f.change("apps/nkana/lib/main.dart", (text) => text.replace("    config,\n    options:", "    const RayonSportsConfig(),\n    options:"));
  assert.match(f.run().errors.join("\n"), /pass its selected config/);
});

test("shared bootstrap receiving another config is rejected", (t) => {
  const f = fixture(t);
  f.change("apps/nkana/lib/main.dart", (text) => text.replace("options: clubBootstrapOptions(\n      config,", "options: clubBootstrapOptions(\n      otherConfig,"));
  assert.match(f.run().errors.join("\n"), /pass its selected config/);
});

test("bypassing the validated startup from production main is rejected", (t) => {
  const f = fixture(t);
  f.change("apps/nkana/lib/main.dart", (text) => text.replace("await startNkanaApp();", "await startOtherApp();"));
  assert.match(f.run().errors.join("\n"), /Production main must invoke/);
});

test("a local shadow of the public bootstrap cannot masquerade as registry composition", (t) => {
  const f = fixture(t);
  f.change("apps/nkana/lib/main.dart", (text) => text.replace("import 'package:app_registry/app_registry.dart';", "// import 'package:app_registry/app_registry.dart';"));
  assert.match(f.run().errors.join("\n"), /import the public registry/);
});

test("a locally defined bootstrap helper cannot replace the public registry call", (t) => {
  const f = fixture(t);
  f.change("apps/nkana/lib/main.dart", (text) => text.replace("void main() async {",
    "AfriClubBootstrapOptions clubBootstrapOptions(ClubConfig config) => const AfriClubBootstrapOptions();\n\nvoid main() async {"));
  assert.match(f.run().errors.join("\n"), /pass its selected config/);
});

test("missing shared bootstrap export blocks admission", (t) => {
  const f = fixture(t);
  f.change("packages/app_registry/lib/app_registry.dart", (text) => text.replace("export 'src/native_bootstrap.dart';", ""));
  assert.match(f.run().errors.join("\n"), /public API must export/);
});

test("a missing registry module builder cannot hide behind valid app calls", (t) => {
  const f = fixture(t);
  f.change("packages/app_registry/lib/src/native_bootstrap.dart", (text) => text.replace("AppModuleRegistry.build(", "OtherRegistry.build("));
  assert.match(f.run().errors.join("\n"), /compose the selected config/);
});

test("wrong snapshot wiring in the shared bootstrap fails admission", (t) => {
  const f = fixture(t);
  f.change("packages/app_registry/lib/src/native_bootstrap.dart", (text) => text.replace("configSnapshot: snapshot", "configSnapshot: null"));
  assert.match(f.run().errors.join("\n"), /compose the selected config/);
});

test("core bootstrap must actually consume the selected module builder", (t) => {
  const f = fixture(t);
  f.change("packages/core/core_app/lib/src/bootstrap.dart", (text) => text.replace("options.moduleBuilder!(platformConfigSnapshot)", "const <FeatureModule>[]"));
  assert.match(f.run().errors.join("\n"), /invoke the selected module builder/);
});

test("release Android identity overrides fail rather than trusting the first declaration", (t) => {
  const f = fixture(t);
  f.change("apps/nkana/android/app/build.gradle.kts", (text) => text.replace("        release {", '        release {\n            applicationId = "zm.other.club"'));
  assert.match(f.run().errors.join("\n"), /Android application ID differs or is overridden/);
});

test("iOS identity checks inspect Runner configuration relationships rather than test bundle IDs", (t) => {
  const f = fixture(t);
  for (const relative of ["ios/Runner.xcodeproj/project.pbxproj", "ios/Flutter/Debug-qa.xcconfig", "ios/Flutter/Profile-qa.xcconfig"]) {
    f.change(`apps/nkana/${relative}`, (text) => text.replaceAll("zm.ikanisa.nkana", "zm.ikanisa.other"));
  }
  assert.match(f.run().errors.join("\n"), /iOS Runner Release identity differs/);
});

test("missing native project roots prevent complete target coverage", (t) => {
  const f = fixture(t);
  fs.rmSync(path.join(f.root, "apps/costa_do_sol/ios"), { recursive: true });
  const result = f.run();
  assert.equal(result.scope_status, "fail");
  assert.equal(result.native_target_count, 8);
});

test("blank release bootstrap inputs stay blocked while matching scope remains visible", (t) => {
  const f = fixture(t);
  f.change("apps/costa_do_sol/assets/flavors/production.json", (text) => {
    const config = JSON.parse(text); config.SUPABASE_URL = ""; config.SUPABASE_ANON_KEY = "";
    return JSON.stringify(config);
  });
  const result = f.run();
  assert.equal(result.status, "blocked");
  assert.equal(result.scope_status, "pass");
  assert.equal(result.release_input_blockers.length, 2);
  assert.equal(result.production_ready, false);
  assert.doesNotMatch(JSON.stringify(result), /synthetic-test-input-unverified/);
});

test("placeholder release inputs cannot be treated as supplied credentials", (t) => {
  const f = fixture(t);
  f.change("apps/costa_do_sol/assets/flavors/production.json", (text) => {
    const config = JSON.parse(text); config.SUPABASE_URL = "https://your-project.supabase.co";
    config.SUPABASE_ANON_KEY = "REPLACE_WITH_REAL_KEY"; return JSON.stringify(config);
  });
  assert.equal(f.run().status, "blocked");
});

test("production inputs cannot point at a different country or environment", (t) => {
  const f = fixture(t);
  f.change("apps/nkana/assets/flavors/production.json", (text) => {
    const config = JSON.parse(text); config.COUNTRY_CODE = "RW"; return JSON.stringify(config);
  });
  assert.match(f.run().errors.join("\n"), /Production country differs/);
  f.change("apps/nkana/assets/flavors/production.json", (text) => {
    const config = JSON.parse(text); config.COUNTRY_CODE = "ZM"; config.ENVIRONMENT = "qa"; return JSON.stringify(config);
  });
  assert.match(f.run().errors.join("\n"), /Production flavor does not declare production environment/);
});
