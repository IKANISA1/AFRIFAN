import { readdirSync, readFileSync, existsSync } from 'node:fs';
import { resolve, relative, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const failures = [];
const check = (condition, message) => { if (!condition) failures.push(message); };
const catalogDir = join(root, 'packages/core/core_l10n/lib/l10n');
check(readdirSync(catalogDir).filter(n => n.endsWith('.arb')).join() === 'afri_en.arb',
  'Ship exactly one English ARB catalog.');
check(!readdirSync(catalogDir).some(n => /localizations_(?!en)[a-z]+\.dart$/.test(n)),
  'Remove generated non-English catalogs.');
const catalog = JSON.parse(readFileSync(join(catalogDir, 'afri_en.arb'), 'utf8'));
check(catalog['@@locale'] === 'en', 'The product catalog must declare English.');
function walk(dir) {
  return readdirSync(dir, {withFileTypes: true}).flatMap(entry => {
    if (['node_modules', 'build', '.dart_tool', '.next', 'output', 'desktop-output'].includes(entry.name)) return [];
    const path = join(dir, entry.name);
    return entry.isDirectory() ? walk(path) : [path];
  });
}
const clubConfigs = walk(join(root, 'packages/clubs')).filter(p => p.endsWith('_config.dart'));
for (const path of clubConfigs) {
  const source = readFileSync(path, 'utf8');
  check(/String get language => 'en';/.test(source), `${relative(root, path)}: default language`);
  check(/supportedLanguages => const \['en'\];/.test(source), `${relative(root, path)}: supported languages`);
}
for (const path of walk(join(root, 'apps/rayon_sports/web/src')).filter(p => /\.tsx?$/.test(p) && !p.includes('.test.'))) {
  const source = readFileSync(path, 'utf8');
  check(!/^\s*(?:fr|rw|sw):\s*\{/m.test(source), `${relative(root, path)}: retired translation dictionary`);
  check(!/(?:language|locale)\s*===\s*["'](?:fr|rw|sw)["']/.test(source), `${relative(root, path)}: retired language branch`);
}
for (const directory of ['ios/fastlane/metadata', 'android/fastlane/metadata/android']) {
  const base = join(root, 'apps/rayon_sports', directory);
  for (const entry of readdirSync(base, {withFileTypes: true})) {
    if (entry.isDirectory() && /^[a-z]{2}-[A-Z]{2}$/.test(entry.name)) {
      check(entry.name === 'en-US', `${directory}: non-English listing ${entry.name}`);
    }
  }
}
check(!existsSync(join(root, 'apps/rayon_sports/store_metadata/source_localizations/rw-RW')),
  'Retired source listing still exists.');
const release = JSON.parse(readFileSync(join(root, 'apps/rayon_sports/store_metadata/release_package.json'), 'utf8'));
check(JSON.stringify(release.mobile.supported_app_locales) === '["en"]', 'Release package locales must be English only.');
if (failures.length) {
  process.stderr.write(failures.join('\n') + '\n'); process.exitCode = 1;
} else {
  process.stdout.write(`English-only policy passed: one catalog, ${clubConfigs.length} club configurations, web dictionaries and store listings.\n`);
}
