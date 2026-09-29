// Firestore security-rules tests for ../firestore.rules (CommonJS build — the
// ESM entry of rules-unit-testing 5.x deep-imports a firebase path that
// firebase 12.19 no longer ships).
// Run from repo root:
//   firebase emulators:exec --only firestore --project demo-spotifyfy "node rules-tests/run.cjs"
const { readFileSync } = require('node:fs');
const { join } = require('node:path');

const {
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  setDoc,
  getDoc,
  updateDoc,
  deleteDoc,
} = require('firebase/firestore');

const rulesPath = join(__dirname, '..', 'firestore.rules');

const ownDoc = {
  id: 'm1',
  email: 'jane@gmail.com',
  username: 'jane',
  firebaseUid: 'fb-uid-1',
  provider: 'google',
};
const otherDoc = {
  id: 'm2',
  email: 'bob@x.com',
  username: 'bob',
  firebaseUid: 'fb-uid-9',
  provider: 'google',
};

const cases = [];

async function run(name, expectation, fn) {
  try {
    await fn();
    const ok = expectation === 'ALLOW';
    cases.push({ name, ok, detail: ok ? 'allowed as expected' : 'expected DENY but SUCCEEDED' });
  } catch (e) {
    const denied = /permission|denied|false for/i.test(String(e.message || e));
    const ok = expectation === 'DENY' && denied;
    cases.push({
      name,
      ok,
      detail: ok ? 'denied as expected' : `unexpected result (expected ${expectation}): ${String(e.message || e).split('\n')[0]}`,
    });
  }
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId: 'demo-spotifyfy',
    firestore: { rules: readFileSync(rulesPath, 'utf8') },
  });

  // Seed existing docs with rules bypassed (simulates backend admin writes).
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/m1'), ownDoc);
    await setDoc(doc(ctx.firestore(), 'users/m2'), otherDoc);
  });

  const alice = testEnv.authenticatedContext('fb-uid-1', { email: 'jane@gmail.com' });
  const mallory = testEnv.authenticatedContext('fb-uid-2', { email: 'mallory@evil.com' });
  const anon = testEnv.unauthenticatedContext();

  await run('Google user creates own doc (uid match)', 'ALLOW', () =>
    setDoc(doc(alice.firestore(), 'users/m3'), { ...ownDoc, id: 'm3' }),
  );
  await run('Google user updates own doc (uid match)', 'ALLOW', () =>
    updateDoc(doc(alice.firestore(), 'users/m1'), { ...ownDoc, bio: 'hi' }),
  );
  await run('Authed user writes someone else doc', 'DENY', () =>
    setDoc(doc(mallory.firestore(), 'users/m1'), { ...ownDoc, bio: 'hacked' }, { merge: true }),
  );
  await run('Unauthenticated create', 'DENY', () =>
    setDoc(doc(anon.firestore(), 'users/m1'), { ...ownDoc, evil: true }, { merge: true }),
  );
  await run('Google user reads own doc', 'ALLOW', () =>
    getDoc(doc(alice.firestore(), 'users/m1')),
  );
  await run('Authed user reads someone else doc', 'DENY', () =>
    getDoc(doc(mallory.firestore(), 'users/m1')),
  );
  await run('Authed user deletes own doc (backend only)', 'DENY', () =>
    deleteDoc(doc(alice.firestore(), 'users/m1')),
  );

  await testEnv.cleanup();

  let pass = 0;
  for (const c of cases) {
    if (c.ok) pass += 1;
    console.log(`${c.ok ? 'PASS' : 'FAIL'} | ${c.name} | ${c.detail}`);
  }
  console.log(`\n${pass}/${cases.length} rule test cases passed`);
  process.exit(pass === cases.length ? 0 : 1);
}

main().catch((e) => {
  console.error('FATAL', e);
  process.exit(1);
});
