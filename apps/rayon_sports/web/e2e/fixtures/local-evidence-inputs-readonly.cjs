// Ignored test-execution fence. The production installed tree stays read only.
const fs = require('node:fs');
const path = require('node:path');
const { fileURLToPath } = require('node:url');
const { syncBuiltinESMExports } = require('node:module');
const originalRealpath = fs.realpathSync.bind(fs);
const originalWriteFile = fs.writeFileSync.bind(fs);
const originalRename = fs.renameSync.bind(fs);
const originalMkdir = fs.mkdirSync.bind(fs);
const installed = process.env.AFRICLUB_HTTP_INSTALLED_READONLY;
const proofDir = process.env.AFRICLUB_HTTP_INSTALLED_GUARD_OUTPUT;
if (!installed || !proofDir) throw new Error('http_installed_guard_missing_scope');
const protectedRoot = originalRealpath(path.resolve(installed));
const additionalRoots = JSON.parse(process.env.AFRICLUB_HTTP_ADDITIONAL_READONLY || '[]').map(p => originalRealpath(path.resolve(p)));
const writableExceptions = JSON.parse(process.env.AFRICLUB_HTTP_READONLY_EXCEPTIONS || '[]').map(p => normalized(p));
const protectedRoots = [protectedRoot, ...additionalRoots];
const within = (target, root) => target === root || target?.startsWith(root + path.sep);
Object.defineProperty(globalThis, Symbol.for('africlub.immutable-evidence-inputs'), { value: Object.freeze({ protectedRoots: Object.freeze(protectedRoots), writableExceptions: Object.freeze(writableExceptions), installedRoot: protectedRoot }), writable: false, configurable: false });
const proofRoot = originalRealpath(path.resolve(proofDir));
if (protectedRoot === proofRoot || proofRoot.startsWith(protectedRoot + path.sep)) {
  throw new Error('http_installed_guard_invalid_scope');
}
let attempts = 0;
const operations = {};
function normalized(value) {
  if (typeof value === 'number') return null;
  if (value instanceof URL) value = fileURLToPath(value);
  if (Buffer.isBuffer(value)) value = value.toString();
  if (typeof value !== 'string') throw new Error('http_installed_guard_invalid_path');
  const absolute = path.resolve(value);
  let parent = absolute;
  for (;;) {
    try { return path.join(originalRealpath(parent), path.relative(parent, absolute)); }
    catch (error) {
      if (!['ENOENT', 'ENOTDIR'].includes(error.code)) throw error;
      const next = path.dirname(parent);
      if (next === parent) throw new Error('http_installed_guard_unresolved_path');
      parent = next;
    }
  }
}
function deny(operation, value) {
  const target = normalized(value);
  const ancestorMutation = /(?:rm|rmdir|rename|cp|copyFile)(?:Sync)?$/.test(operation) &&
    target && protectedRoots.some(root => root.startsWith(target + path.sep));
  const installedMutation = within(target, protectedRoot);
  const additionalMutation = additionalRoots.some(root => within(target, root)) && !writableExceptions.some(root => within(target, root));
  if (installedMutation || additionalMutation || ancestorMutation) {
    attempts++;
    operations[operation] = (operations[operation] || 0) + 1;
    const error = new Error('http_installed_write_rejected');
    error.code = 'AFRICLUB_INSTALLED_WRITE_REJECTED';
    throw error;
  }
}
function mutatingFlags(flags) {
  if (typeof flags === 'string') return /[wax+]/.test(flags);
  return typeof flags === 'number' && (flags & (fs.constants.O_WRONLY | fs.constants.O_RDWR | fs.constants.O_CREAT | fs.constants.O_TRUNC | fs.constants.O_APPEND)) !== 0;
}
const paths = {
  appendFile: [0], writeFile: [0], truncate: [0], unlink: [0], rm: [0],
  rmdir: [0], mkdir: [0], chmod: [0], chown: [0], lchmod: [0], lchown: [0],
  utimes: [0], lutimes: [0], rename: [0, 1], copyFile: [1], cp: [1],
  symlink: [1], link: [0, 1], mkdtemp: [0],
};
for (const [operation, indexes] of Object.entries(paths)) {
  for (const key of [operation, operation + 'Sync']) {
    const original = fs[key];
    if (typeof original !== 'function') continue;
    fs[key] = function (...args) {
      for (const index of indexes) deny(key, args[index]);
      return Reflect.apply(original, this, args);
    };
  }
  const original = fs.promises[operation];
  if (typeof original === 'function') {
    fs.promises[operation] = async function (...args) {
      for (const index of indexes) deny('promises.' + operation, args[index]);
      return Reflect.apply(original, this, args);
    };
  }
}
for (const key of ['open', 'openSync']) {
  const original = fs[key];
  fs[key] = function (...args) {
    if (mutatingFlags(args[1])) deny(key, args[0]);
    return Reflect.apply(original, this, args);
  };
}
const originalOpen = fs.promises.open;
fs.promises.open = async function (...args) {
  if (mutatingFlags(args[1])) deny('promises.open', args[0]);
  return Reflect.apply(originalOpen, this, args);
};
const originalStream = fs.createWriteStream;
fs.createWriteStream = function (...args) {
  deny('createWriteStream', args[0]);
  return Reflect.apply(originalStream, this, args);
};
syncBuiltinESMExports();
originalWriteFile(path.join(proofRoot, `installed-guard-${process.pid}.started`), JSON.stringify({schemaVersion:1,pid:process.pid,readonlyScopeInstalled:true,additionalReadonlyRoots:additionalRoots,writableExceptions})+'\n', {flag:'wx'});
let finalized = false;
function finalize(terminationSignal = null) {
  if (finalized) return;
  originalMkdir(proofRoot, { recursive: true });
  const pending = path.join(proofRoot, `installed-guard-${process.pid}.pending`);
  originalWriteFile(pending, JSON.stringify({
    schemaVersion: 1, pid: process.pid, installedTreeWriteAttempts: attempts,
    operations, readonlyScopeInstalled: true, terminalReceipt: true, terminationSignal,
  }) + '\n', { flag: 'wx' });
  originalRename(pending, path.join(proofRoot, `installed-guard-${process.pid}.json`));
  finalized = true;
}
process.once('exit', () => finalize());
for (const signal of ['SIGTERM','SIGINT']) {
  function terminalSignal() {
    finalize(signal);
    process.removeListener(signal, terminalSignal);
    process.kill(process.pid, signal);
  }
  process.once(signal, terminalSignal);
}
