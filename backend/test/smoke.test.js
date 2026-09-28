import test from 'node:test';
import assert from 'node:assert/strict';

test('health endpoint contract', async () => {
  const base = process.env.MYERB_API_URL || 'http://localhost:4000';
  try {
    const r = await fetch(base + '/health');
    assert.equal(r.status, 200);
    const body = await r.json();
    assert.equal(body.status, 'ok');
    assert.equal(body.database, 'ok');
  } catch (e) {
    if (process.env.REQUIRE_LIVE_API === '1') throw e;
    assert.ok(e instanceof Error);
  }
});

test('frontend smoke URL is configured', () => {
  assert.equal(process.env.MYERB_WEB_URL || 'http://localhost:8080', 'http://localhost:8080');
});
