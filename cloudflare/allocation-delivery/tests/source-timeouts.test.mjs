import test from 'node:test';
import assert from 'node:assert/strict';
import {drain} from '../src/dispatcher.mjs';
import {withTransportClock,deferred,expireTransportDeadline} from './transport-clock.mjs';

const stalled = () => new Promise(() => {});
const use = withTransportClock;
const completesDrain = (t, env, entered) =>
  expireTransportDeadline(t, drain(env), entered, Number(env.DELIVERY_TIMEOUT_MS));
function financialState(f) {
  return ['pa_ledger', 'pa_memberships', 'pa_external_claims', 'pa_receipts', 'pa_outbox']
    .map(table => [table, f.count(table)]);
}

test('stalled take is unknown and the next club is examined without issuing a second claim', t => use(t, async f => {
  const visited = [], entered = deferred();
  f.runner.SOURCE = {
    take: x => {
      visited.push(x.clubId);
      if (x.clubId === 24) { entered.resolve(); return stalled(); }
      return f.source.take(x);
    },
    readForDispatch: () => assert.fail('no known lease'),
    finish: () => assert.fail('no known lease'),
  };
  const result = await completesDrain(t, f.runner, entered.promise);
  assert.deepEqual(visited, [24, 25]);
  assert.equal(result.unavailableClubs, 1);
  assert.equal(result.examined, 0);
  assert.equal(f.count('pa_delivery_jobs'), 0);
}));

test('stalled read leaves the original lease unknown, without inventing a sink failure', t => use(t, async f => {
  const visited = [], before = financialState(f), entered = deferred();
  f.runner.SOURCE = {
    take: x => { visited.push(x.clubId); return f.source.take(x); },
    readForDispatch: () => { entered.resolve(); return stalled(); },
    finish: () => assert.fail('uncertain read must leave its lease to expire'),
  };
  f.runner.INBOX = {accept: () => assert.fail('no prepared event')};
  const result = await completesDrain(t, f.runner, entered.promise);
  assert.deepEqual(visited, [24, 25]);
  assert.equal(result.unknown, 1);
  assert.equal(result.retryRecorded, 0);
  assert.equal(f.db.sql.prepare('SELECT state FROM pa_delivery_jobs').get().state, 'leased');
  assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n, 0);
  assert.deepEqual(financialState(f), before);
}));

test('stalled finish cannot block later clubs or generate a replacement acknowledgement', t => use(t, async f => {
  let release;
  const gate = new Promise(resolve => { release = resolve; });
  const visited = [], commands = [], before = financialState(f), entered = deferred();
  let lateFinish;
  f.runner.SOURCE = {
    take: x => { visited.push(x.clubId); return f.source.take(x); },
    readForDispatch: x => f.source.readForDispatch(x),
    finish: x => {
      commands.push({...x});
      entered.resolve();
      lateFinish = gate.then(() => f.source.finish(x));
      return lateFinish;
    },
  };
  const result = await completesDrain(t, f.runner, entered.promise);
  assert.deepEqual(visited, [24, 25]);
  assert.equal(result.unknown, 1);
  assert.equal(result.stored, 0);
  assert.equal(commands.length, 1);
  assert.equal(commands[0].eventId, f.receipt.allocationId);
  assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n, 1);
  assert.equal(f.db.sql.prepare('SELECT state FROM pa_delivery_jobs').get().state, 'leased');
  release();
  const receipt = await lateFinish;
  assert.equal(receipt.operationId, commands[0].requestId);
  f.runner.SOURCE = f.source;
  assert.equal((await drain(f.runner)).examined, 0);
  assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n, 1);
  assert.deepEqual(financialState(f), before);
}));

test('late take may commit after timeout and recovers the same event through lease expiry', t => use(t, async f => {
  let release, lateTake;
  const gate = new Promise(resolve => { release = resolve; });
  const visited = [], before = financialState(f), entered = deferred();
  f.runner.SOURCE = {
    take: x => {
      visited.push(x.clubId);
      if (x.clubId === 24) {
        entered.resolve();
        return (lateTake = gate.then(() => f.source.take(x)));
      }
      return f.source.take(x);
    },
    readForDispatch: () => assert.fail('no acknowledged lease'),
    finish: () => assert.fail('no acknowledged lease'),
  };
  assert.equal((await completesDrain(t, f.runner, entered.promise)).unavailableClubs, 1);
  assert.deepEqual(visited, [24, 25]);
  assert.equal(f.count('pa_delivery_jobs'), 0);
  release();
  const claimed = await lateTake;
  assert.equal(claimed.event.eventId, f.receipt.allocationId);
  assert.equal(f.db.sql.prepare('SELECT state FROM pa_delivery_jobs').get().state, 'leased');
  f.runner.SOURCE = f.source;
  f.advance(10000);
  assert.equal((await drain(f.runner)).stored, 0);
  f.advance(1000);
  assert.equal((await drain(f.runner)).stored, 1);
  const job = f.db.sql.prepare('SELECT event_id, attempts, state FROM pa_delivery_jobs').get();
  assert.equal(job.event_id, claimed.event.eventId);
  assert.equal(job.attempts, 2);
  assert.equal(job.state, 'delivered');
  assert.equal(f.sinkDb.sql.prepare('SELECT count(*) n FROM adi_events').get().n, 1);
  assert.deepEqual(financialState(f), before);
}));

test('real minimum transport timer expires a stalled binding and continues without SQLite fixture latency', {timeout: 5000}, async () => {
  const visited = [], started = performance.now();
  const result = await drain({
    DELIVERY_DISPATCH_ENABLED: 'true', DELIVERY_ENVIRONMENT: 'isolated-staging',
    DELIVERY_CLUB_IDS: '[24,25]', DELIVERY_TIMEOUT_MS: '100',
    SOURCE: {
      take: ({clubId}) => {
        visited.push(clubId);
        return clubId === 24 ? stalled() : {schemaVersion: 1, clubId, event: null};
      },
      readForDispatch: () => assert.fail('no acknowledged lease'),
      finish: () => assert.fail('no acknowledged lease'),
    },
    INBOX: {accept: () => assert.fail('no prepared event')},
  });
  assert.ok(performance.now() - started >= 90, 'real 100 ms deadline was not exercised');
  assert.deepEqual(visited, [24, 25]);
  assert.equal(result.unavailableClubs, 1);
  assert.equal(result.examined, 0);
});
