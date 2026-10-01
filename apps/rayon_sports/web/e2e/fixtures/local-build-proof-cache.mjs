import fs from 'node:fs';
import path from 'node:path';
import { createHash } from 'node:crypto';

const cache = new Map();
const within = (target, root) => target === root || target.startsWith(root + path.sep);

/** Reuse a full build check only inside an actual read-only input interval. */
export function checkedProductionBuild(web, check) {
  const guard = globalThis[Symbol.for('africlub.immutable-evidence-inputs')];
  if (!guard) return check();
  const root = fs.realpathSync(web);
  const sealPath = path.join(root, '.next/africlub-build-provenance.json');
  const sealBytes = fs.readFileSync(sealPath);
  const seal = JSON.parse(sealBytes.toString('utf8'));
  const covered = file => {
    const actual = fs.realpathSync(file);
    return guard.protectedRoots.some(base => within(actual, base)) &&
      !guard.writableExceptions.some(base => within(actual, base));
  };
  if (!covered(path.join(root, 'node_modules')) ||
      !covered(sealPath) || !covered(path.join(root, '.next/BUILD_ID')) ||
      !Array.isArray(seal.source?.files) || !Array.isArray(seal.artifacts?.files) ||
      !seal.source.files.every(row => covered(path.resolve(root, row.file))) ||
      !seal.artifacts.files.every(row => covered(path.resolve(root, '.next', row.file)))) {
    throw new Error('Immutable interval does not cover every sealed build input and artifact');
  }
  const key = createHash('sha256').update(sealBytes)
    .update(fs.readFileSync(path.join(root, '.next/BUILD_ID')))
    .update(JSON.stringify(guard)).digest('hex');
  const prior = cache.get(root);
  if (prior?.key === key) return prior.result;
  const result = Object.freeze(check());
  if (result.provenance_sha256 !== createHash('sha256').update(sealBytes).digest('hex') ||
      result.build_id !== seal.build_id) {
    throw new Error('Full build check differs from immutable interval seal');
  }
  cache.set(root, { key, result });
  return result;
}
