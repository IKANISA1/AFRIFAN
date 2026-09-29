import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readJson, fail } from '../src/http.mjs';

function stalledRequest({cancel = () => {}} = {}) {
  return new Request('https://identity.example.invalid/v1/auth/clubs/24/otp/challenges', {
    method: 'POST', headers: {'content-type': 'application/json'}, duplex: 'half',
    body: new ReadableStream({start(c) {c.enqueue(new TextEncoder().encode('{'));}, cancel}),
  });
}

async function boundedResult(request) {
  let timer;
  try {
    return await Promise.race([
      readJson(request, {timeoutMs: 10}).then(() => ({unexpectedSuccess:true}), error => error),
      new Promise(resolve => {timer = setTimeout(() => resolve({outerTimeout:true}), 200);}),
    ]);
  } finally {clearTimeout(timer);}
}

test('stalled native JSON body ends with a sanitized 408 rather than an unbounded read', async () => {
  let cancelled = false;
  const error = await boundedResult(stalledRequest({cancel() {cancelled = true;}}));
  assert.equal(error.code, 'body_timeout');
  assert.equal(error.status, 408);
  assert.equal(cancelled, true);
  assert.deepEqual(await fail(error).json(), {schemaVersion:1, error:'body_timeout'});
});

test('a non-settling stream cancellation cannot hold the native body deadline open', async () => {
  const error = await boundedResult(stalledRequest({cancel() {return new Promise(() => {});}}));
  assert.equal(error.code, 'body_timeout');
  assert.equal(error.status, 408);
});
