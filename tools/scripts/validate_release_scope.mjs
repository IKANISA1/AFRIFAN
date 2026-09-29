#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { validateAndroidQaIsolation } from "./validate_mobile_qa_isolation.mjs";
import { validateIosQaIsolation } from "./validate_ios_qa_isolation.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const scopeFile = "docs/release/full_stack_qa_plan.md";
const escaped = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const sorted = (values) => [...values].sort();

function requireContract(condition, message) {
  if (!condition) throw new Error(message);
}

// The reviewed table is the scope contract. Counts alone cannot establish that
// the correct club, tenant and native identities are present.
export function parseReleaseScope(document) {
  const sections = [...document.matchAll(/<!-- release-scope:start -->([\s\S]*?)<!-- release-scope:end -->/g)];
  requireContract(sections.length === 1, "QA plan must contain exactly one native release scope table.");
  const rows = sections[0][1].split("\n").filter((line) => line.trim().startsWith("|"))
    .map((line) => line.trim().slice(1, -1).split("|").map((value) => value.trim()));
  requireContract(JSON.stringify(rows[0]) === JSON.stringify([
    "App slug", "Tenant ID", "Country code", "Config class", "Android application ID", "iOS bundle ID",
  ]), "Native release scope table headers changed or are incomplete.");
  const clubs = rows.slice(2).map((row) => {
    requireContract(row.length === 6, "Every release scope row requires six fields.");
    const [slug, tenant, country, configClass, androidId, iosId] = row;
    requireContract(/^[a-z][a-z0-9_]*$/.test(slug) && /^[1-9][0-9]*$/.test(tenant)
      && /^[A-Z]{2}$/.test(country) && /^[A-Z][A-Za-z0-9]*Config$/.test(configClass)
      && /^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$/.test(androidId)
      && /^[A-Za-z][A-Za-z0-9]*(?:\.[A-Za-z][A-Za-z0-9]*)+$/.test(iosId),
    `Invalid release scope identity: ${slug || "unnamed row"}.`);
    return { slug, tenant, country, configClass, androidId, iosId };
  });
  requireContract(clubs.length === 5, "Current release requires five clubs and ten native targets.");
  for (const key of ["slug", "tenant", "androidId", "iosId"]) {
    requireContract(new Set(clubs.map((club) => club[key])).size === clubs.length, `Duplicate release ${key}.`);
  }
  return clubs;
}

function workspacePaths(source) {
  const match = source.match(/^workspace:\s*\n((?:[ \t].*\n|\s*\n)*)/m);
  requireContract(match, "Root pubspec must declare workspace registrations.");
  return [...match[1].matchAll(/^\s+- ([a-z0-9_/]+)\s*(?:#.*)?$/gm)].map((entry) => entry[1]);
}

function sameInventory(actual, expected, label) {
  requireContract(actual.length === new Set(actual).size, `Duplicate ${label} registration.`);
  requireContract(JSON.stringify(sorted(actual)) === JSON.stringify(sorted(expected)),
    `${label} inventory differs: expected ${sorted(expected).join(", ")}; found ${sorted(actual).join(", ")}.`);
}

function stripComments(source) {
  return source.replace(/"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\/\*[\s\S]*?\*\/|\/\/[^\r\n]*/g,
    (token) => token.startsWith("\"") || token.startsWith("'") ? token : "");
}

function isMissingInput(value) {
  return typeof value !== "string" || !value.trim()
    || /replace|placeholder|your[_-]|example\.(?:com|supabase)/i.test(value);
}

export function validateReleaseScope(repoRoot = root) {
  const errors = [];
  const releaseInputBlockers = [];
  const clubs = [];
  const read = (relative) => fs.readFileSync(path.join(repoRoot, relative), "utf8");
  const record = (label, operation) => {
    try { return operation(); } catch (error) { errors.push(`${label}: ${error.message}`); return undefined; }
  };
  const expected = record("Release scope contract", () => parseReleaseScope(read(scopeFile)));
  if (expected) {
    const appPaths = expected.map((club) => `apps/${club.slug}`);
    const configPaths = expected.map((club) => `packages/clubs/club_${club.slug}`);
    record("Workspace", () => {
      const registrations = workspacePaths(read("pubspec.yaml"));
      sameInventory(registrations.filter((name) => name.startsWith("apps/")), appPaths, "Workspace app");
      sameInventory(registrations.filter((name) => name.startsWith("packages/clubs/")), configPaths, "Workspace club config");
    });
    record("Physical apps", () => {
      const physical = fs.readdirSync(path.join(repoRoot, "apps"), { withFileTypes: true })
        .filter((entry) => (entry.isDirectory() || entry.isSymbolicLink()) && (
          fs.existsSync(path.join(repoRoot, "apps", entry.name, "pubspec.yaml"))
          || fs.existsSync(path.join(repoRoot, "apps", entry.name, "android"))
          || fs.existsSync(path.join(repoRoot, "apps", entry.name, "ios"))))
        .map((entry) => `apps/${entry.name}`);
      sameInventory(physical, appPaths, "Physical app");
    });
    record("Physical club configs", () => {
      const physical = fs.readdirSync(path.join(repoRoot, "packages/clubs"), { withFileTypes: true })
        .filter((entry) => (entry.isDirectory() || entry.isSymbolicLink()) && fs.existsSync(path.join(repoRoot, "packages/clubs", entry.name, "pubspec.yaml")))
        .map((entry) => `packages/clubs/${entry.name}`);
      sameInventory(physical, configPaths, "Physical club config");
    });
    for (const club of expected) {
      record(club.slug, () => {
        const app = `apps/${club.slug}`;
        const configPackage = `club_${club.slug}`;
        const configDirectory = `packages/clubs/${configPackage}`;
        requireContract(new RegExp(`^name: ${escaped(club.slug)}$`, "m").test(read(`${app}/pubspec.yaml`)), "App package name differs from release slug.");
        requireContract(new RegExp(`^  ${escaped(configPackage)}:\\s*\\n    path: \\.\\./\\.\\./packages/clubs/${escaped(configPackage)}\\s*$`, "m").test(read(`${app}/pubspec.yaml`)), "App must depend on its own registered club config package.");
        requireContract(new RegExp(`^name: ${escaped(configPackage)}$`, "m").test(read(`${configDirectory}/pubspec.yaml`)), "Club config package name differs from registration.");
        const main = stripComments(read(`${app}/lib/main.dart`));
        requireContract(main.includes(`import 'package:${configPackage}/${configPackage}.dart';`), "App entrypoint imports the wrong club config.");
        requireContract(new RegExp(`const config = ${escaped(club.configClass)}\\(\\);`).test(main), "App entrypoint does not instantiate its declared club config.");
        requireContract(main.includes("AppModuleRegistry.build(config, configSnapshot: snapshot)"), "App entrypoint must use the shared feature registry.");
        const config = stripComments(read(`${configDirectory}/lib/src/${club.slug}_config.dart`));
        requireContract(new RegExp(`class ${escaped(club.configClass)} implements ClubConfig`).test(config), "Config class does not match release registration.");
        requireContract(new RegExp(`String get countryCode => '${escaped(club.country)}';`).test(config), "Config country does not match release registration.");
        const production = JSON.parse(read(`${app}/assets/flavors/production.json`));
        requireContract(String(production.CLUB_ID) === club.tenant, "Production tenant differs from release registration.");
        requireContract(production.COUNTRY_CODE === club.country, "Production country differs from release registration.");
        requireContract(production.ENVIRONMENT === "production", "Production flavor does not declare production environment.");
        for (const key of ["SUPABASE_URL", "SUPABASE_ANON_KEY"]) {
          if (isMissingInput(production[key])) releaseInputBlockers.push(`${club.slug}: ${key} missing or placeholder; release bootstrap unverified.`);
        }
        const androidRoot = path.join(repoRoot, app, "android");
        const iosRoot = path.join(repoRoot, app, "ios");
        requireContract(fs.statSync(androidRoot).isDirectory() && fs.statSync(iosRoot).isDirectory(), "Both Android and iOS project roots are required.");
        const gradle = stripComments(read(`${app}/android/app/build.gradle.kts`));
        const applications = [...gradle.matchAll(/\bapplicationId\s*=\s*"([^"]+)"/g)].map((entry) => entry[1]);
        const namespaces = [...gradle.matchAll(/\bnamespace\s*=\s*"([^"]+)"/g)].map((entry) => entry[1]);
        requireContract(applications.length === 1 && applications[0] === club.androidId, "Android application ID differs or is overridden outside the declared default.");
        requireContract(namespaces.length === 1 && namespaces[0] === club.androidId, "Android namespace differs from release registration.");
        validateAndroidQaIsolation(gradle);
        // Reuse the existing relationship-aware Xcode/QA contract rather than
        // finding an arbitrary PRODUCT_BUNDLE_IDENTIFIER (e.g. RunnerTests).
        const ios = validateIosQaIsolation(iosRoot);
        requireContract(ios.productionId === club.iosId, "iOS Runner Release identity differs from release registration.");
        clubs.push({ ...club, nativeTargets: ["android", "ios"], releaseRegistration: "unverified", signing: "unverified" });
      });
    }
  }
  return {
    scope: "native_release_inventory_and_source_identity_only",
    status: errors.length ? "fail" : releaseInputBlockers.length ? "blocked" : "pass",
    scope_status: errors.length ? "fail" : "pass",
    production_ready: false,
    club_count: clubs.length,
    native_target_count: clubs.length * 2,
    clubs,
    errors,
    release_input_blockers: releaseInputBlockers,
    remaining_evidence: ["registered release identities", "release signing", "provider authenticity", "native builds and installed journeys", "owner and release acceptance"],
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const result = validateReleaseScope();
  console.log(JSON.stringify(result, null, 2));
  process.exitCode = process.argv.includes("--scope-only")
    ? result.scope_status === "pass" ? 0 : 1
    : result.status === "pass" ? 0 : 1;
}
