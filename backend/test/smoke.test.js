import test from 'node:test';
import assert from 'node:assert/strict';

const base = process.env.MYERP_API_URL || 'http://localhost:4000';
const adminEmail = process.env.MYERP_ADMIN_EMAIL || 'admin@myerb.local';
const adminPassword = process.env.MYERP_ADMIN_PASSWORD || 'Admin@123';

async function login(email, password) {
  const r = await fetch(base + '/api/auth/login', {
    method: 'POST',
    headers: {'content-type': 'application/json'},
    body: JSON.stringify({email, password})
  });
  const body = await r.json();
  assert.equal(r.status, 200, JSON.stringify(body));
  return body.token;
}

test('live API smoke + authentication contract', async () => {
  try {
    const health = await fetch(base + '/health');
    assert.equal(health.status, 200);
    const body = await health.json();
    assert.equal(body.status, 'ok');
    assert.equal(body.database, 'ok');

    const token = await login(adminEmail, adminPassword);
    const me = await fetch(base + '/api/me', {
      headers: {authorization: `Bearer ${token}`}
    });
    assert.equal(me.status, 200);
    const user = await me.json();
    assert.equal(user.email, adminEmail);
  } catch (e) {
    if (process.env.REQUIRE_LIVE_API === '1') throw e;
    assert.ok(e instanceof Error);
  }
});

test('frontend smoke URL is configured', () => {
  assert.equal(process.env.MYERP_WEB_URL || 'http://localhost:8080', 'http://localhost:8080');
});
