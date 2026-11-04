'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const html = fs.readFileSync(path.join(__dirname, '../../app/src/main/assets/index.html'), 'utf8');
const java = fs.readFileSync(path.join(__dirname, '../../app/src/main/java/com/thedemianff/lastzone/MainActivity.java'), 'utf8');

function guestTransferHelper(storageValues = {}) {
  const start = html.indexOf("const v504GuestTransferOwnerKey='thedemianff_guest_transfer_owner_v1';");
  const end = html.indexOf("const v504AccountProgress=", start);
  assert.ok(start >= 0 && end > start, 'one-time guest-transfer guard must exist');
  const values = { ...storageValues };
  const localStorage = {
    get length() { return Object.keys(values).length; },
    getItem(key) { return Object.prototype.hasOwnProperty.call(values, key) ? values[key] : null; },
    setItem(key, value) { values[key] = String(value); },
    key(index) { return Object.keys(values)[index] ?? null; },
  };
  const context = { localStorage };
  vm.runInNewContext(html.slice(start, end) + '\nresult=v504HasPriorGoogleAccount();', context);
  return context.result;
}

test('fresh guest device may offer its snapshot to its first Google account', () => {
  assert.equal(guestTransferHelper({ thedemianff_progress_v18: '{"xp":20}' }), false);
});

test('once a guest snapshot is claimed, a second Google account cannot inherit it', () => {
  assert.equal(guestTransferHelper({
    thedemianff_guest_transfer_owner_v1: 'first@example.com',
    thedemianff_progress_v18: '{"xp":20}',
  }), true);
});

test('a device with an existing per-account snapshot cannot re-transfer guest progress', () => {
  assert.equal(guestTransferHelper({
    'thedemianff_v504_progress_first%40example.com': '{"xp":20}',
    thedemianff_progress_v18: '{"xp":20}',
  }), true);
});

test('Google account transfer is guarded and owner marker is stored before account switching', () => {
  const guard = html.indexOf('if(incoming&&!previous&&guestId&&!v504HasPriorGoogleAccount())');
  const marker = html.indexOf('localStorage.setItem(v504GuestTransferOwnerKey,incoming)', guard);
  const isolate = html.indexOf('if(incoming&&!sameAccount)', guard);
  assert.ok(guard >= 0 && marker > guard && isolate > marker);
  assert.ok(html.includes('localStorage.setItem(v504PendingGuest(incoming),validated)'));
  assert.ok(html.includes('transferOwner===v446GoogleEmail?localStorage.getItem(v504PendingGuest(v446GoogleEmail)):null'));
  assert.ok(!html.includes('const pending=localStorage.getItem(v504PendingGuest(v446GoogleEmail));'));
});

test('native logout waits for Google sign-out completion before notifying the WebView', () => {
  assert.ok(java.includes('if(googleSignOutPending)'));
  const signOut = java.indexOf('.signOut().addOnCompleteListener(this,task -> {');
  const callback = java.indexOf('authMessage("signed_out"', signOut);
  assert.ok(signOut >= 0 && callback > signOut);
  assert.ok(java.includes('googleSignOutPending=false;'));
});
