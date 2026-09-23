import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const root = resolve(process.cwd());
const isOpenNext = process.argv.includes("--open-next");

// Determine the base directories for manifests
const bases = isOpenNext
  ? [
      resolve(root, ".open-next/server-functions/default/.next/server/app"),
      resolve(root, ".next/server/app"),
    ]
  : [resolve(root, ".next/server/app")];

const copies = [
  {
    from: "page_client-reference-manifest.js",
    to: "(site)/page_client-reference-manifest.js",
    routeKeyFrom: '["/page"]',
    routeKeyTo: '["/(site)/page"]',
  },
];

for (const base of bases) {
  for (const entry of copies) {
    const source = resolve(base, entry.from);
    const target = resolve(base, entry.to);

    if (!existsSync(source)) {
      console.log(`[skip] Source not found: ${source.replace(`${root}/`, "")}`);
      continue;
    }

    mkdirSync(dirname(target), { recursive: true });
    let content = readFileSync(source, "utf8");

    if (entry.routeKeyFrom) {
      content = content.replace(entry.routeKeyFrom, entry.routeKeyTo);
    }

    writeFileSync(target, content);
    console.log(`[copy] Synced ${target.replace(`${root}/`, "")}`);
  }
}
