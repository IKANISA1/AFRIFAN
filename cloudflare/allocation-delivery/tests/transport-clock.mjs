import assert from 'node:assert/strict';
import {setImmediate as nextTurn} from 'node:timers/promises';
import {fixture} from './fixture.mjs';

// Keep real SQLite, WebCrypto and independent workers. Per-test setTimeout
// scheduling (transport and detached metrics) is controlled; local fixture
// latency is not a service SLA result. Dedicated timer tests remain real.
// Capture a separate real watchdog before Node installs the per-test clock.
const scheduleWatchdog = globalThis.setTimeout;
const cancelWatchdog = globalThis.clearTimeout;
export async function withTransportClock(t, work, makeFixture = fixture) {
  t.mock.timers.enable({apis: ['setTimeout']});
  const f = await makeFixture();
  t.after(() => f.close());
  let watchdog;
  try {
    return await Promise.race([
      Promise.resolve().then(() => work(f)),
      new Promise((_, reject) => {
        watchdog = scheduleWatchdog(() => reject(Error('synthetic_fixture_watchdog')), 10000);
      }),
    ]);
  } finally {
    cancelWatchdog(watchdog);
  }
}

export function deferred() {
  let resolve;
  const promise = new Promise(done => { resolve = done; });
  return {promise, resolve};
}

// Enter the selected real binding before expiring its original deadline.
// Verify that the drain stays pending at 99 ms and changes only at 100 ms.
export async function expireTransportDeadline(t, operation, entered, milliseconds) {
  let settled = false;
  operation.then(() => { settled = true; }, () => { settled = true; });
  await entered;
  t.mock.timers.tick(milliseconds - 1);
  await nextTurn();
  assert.equal(settled, false, 'transport completed before its configured deadline');
  t.mock.timers.tick(1);
  return operation;
}

export {nextTurn};
