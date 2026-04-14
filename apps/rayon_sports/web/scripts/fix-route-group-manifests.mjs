import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const root = resolve(process.cwd());
const copies = [
  [
    resolve(root, ".next/server/app/page_client-reference-manifest.js"),
    resolve(root, ".next/server/app/(site)/page_client-reference-manifest.js"),
    {
      routeKeyFrom: '["/page"]',
      routeKeyTo: '["/(site)/page"]',
    },
  ],
];

for (const [source, target, transform] of copies) {
  if (!existsSync(source)) {
    continue;
  }

  mkdirSync(dirname(target), { recursive: true });
  let content = readFileSync(source, "utf8");

  if (transform) {
    content = content.replace(transform.routeKeyFrom, transform.routeKeyTo);
  }

  writeFileSync(target, content);
  console.log(`Synced ${target.replace(`${root}/`, "")}`);
}
