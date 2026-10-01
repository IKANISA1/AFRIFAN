// Node loaders run preloads in separate threads sharing the process ID.
// Give each loader its own receipt directory before installing the same fence.
const fs = require('node:fs');
const path = require('node:path');
const { isMainThread, threadId } = require('node:worker_threads');

if (!isMainThread) {
  const root = process.env.AFRICLUB_HTTP_INSTALLED_GUARD_OUTPUT;
  if (!root) throw new Error('http_thread_guard_missing_output');
  const output = path.join(root, 'threads', String(threadId));
  fs.mkdirSync(output, { recursive: true });
  process.env.AFRICLUB_HTTP_INSTALLED_GUARD_OUTPUT = output;
}
