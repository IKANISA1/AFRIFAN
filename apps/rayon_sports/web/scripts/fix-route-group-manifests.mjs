import { copyFileSync, existsSync, mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";

const root = resolve(process.cwd());
const copies = [
  [
    resolve(root, ".next/server/app/page_client-reference-manifest.js"),
    resolve(root, ".next/server/app/(site)/page_client-reference-manifest.js"),
  ],
];

for (const [source, target] of copies) {
  if (!existsSync(source)) {
    continue;
  }

  mkdirSync(dirname(target), { recursive: true });
  copyFileSync(source, target);
  console.log(`Synced ${target.replace(`${root}/`, "")}`);
}
