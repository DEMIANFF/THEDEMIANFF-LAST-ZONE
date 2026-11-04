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

test('switching accounts replaces the active in-memory profile instead of merging old stats', () => {
  const start = html.indexOf('function v504SetLocalProgress(data){');
  const end = html.indexOf('\nfunction v504StartCloudRestore', start);
  assert.ok(start >= 0 && end > start, 'account-switch progress setter must exist');
  const values = {};
  const context = {
    localStorage: {
      setItem(key, value) { values[key] = String(value); },
      getItem(key) { return Object.prototype.hasOwnProperty.call(values, key) ? values[key] : null; },
    },
    progressKey: 'thedemianff_progress_v18',
    v443ValidateProgress(data) { return { ...data }; },
    v443Native: null,
    v446GoogleEmail: 'second@example.com',
    v504AccountKey: 'thedemianff_v504_account',
    v18Progress: {
      credits: 9000, xp: 12000, matches: 80, wins: 30, kills: 210, best: 18,
      skin: 2, unlocked: [0, 2], weapon: 3, claimed: ['old'], playerId: '00001',
      playerName: 'FIRST_ACCOUNT', staleField: 'must disappear',
    },
    refreshed: false,
    v18Refresh() { this.refreshed = true; },
  };
  const fresh = { credits: 0, xp: 0, matches: 0, wins: 0, kills: 0, best: 0,
    skin: 0, unlocked: [0], weapon: 0, claimed: [] };
  vm.runInNewContext(html.slice(start, end) +
    '\nv504SetLocalProgress(' + JSON.stringify(fresh) + '); result={...v18Progress};', context);
  assert.equal(context.result.xp, 0);
  assert.equal(context.result.credits, 0);
  assert.equal(context.result.playerId, undefined);
  assert.equal(context.result.playerName, undefined);
  assert.equal(context.result.staleField, undefined);
  assert.equal(context.refreshed, true);
  assert.deepEqual(JSON.parse(values.thedemianff_progress_v18), fresh);
});

test('guest and Firestore restores replace, rather than merge, active account state', () => {
  assert.ok(html.includes('v18Progress=guestProgress;'));
  assert.ok(html.includes('v18Progress=saved;'));
  assert.ok(!html.includes('Object.assign(v18Progress,guestProgress)'));
  assert.ok(!html.includes('Object.assign(v18Progress,saved)'));
});


test('detects a previously copied cloud profile by stats even after its public ID changes', () => {
  const start = html.indexOf('function v504FindDuplicateAccountSnapshot(');
  const end = html.indexOf('\nconst v504PendingGuest=', start);
  assert.ok(start >= 0 && end > start, 'duplicate account snapshot detector must exist');
  const firstKey = 'thedemianff_v504_progress_first%40example.com';
  const values = {
    [firstKey]: JSON.stringify({
      credits: 9000, xp: 12000, matches: 80, wins: 30, kills: 210, best: 18,
      skin: 2, unlocked: [0, 2], weapon: 3, claimed: ['old'], playerId: '00001',
    }),
  };
  const context = {
    localStorage: {
      get length() { return Object.keys(values).length; },
      getItem(key) { return Object.prototype.hasOwnProperty.call(values, key) ? values[key] : null; },
      key(index) { return Object.keys(values)[index] ?? null; },
    },
    v504AccountProgress(email) {
      return 'thedemianff_v504_progress_' + encodeURIComponent(email.toLowerCase());
    },
    v443ValidateProgress(data) { return { ...data }; },
  };
  const candidate = {
    credits: 9000, xp: 12000, matches: 80, wins: 30, kills: 210, best: 18,
    skin: 2, unlocked: [0, 2], weapon: 3, claimed: ['old'], playerId: '00002',
  };
  vm.runInNewContext(html.slice(start, end) +
    '\nresult=v504FindDuplicateAccountSnapshot("second@example.com",' +
    JSON.stringify(candidate) + ');', context);
  assert.equal(context.result, firstKey);
});

test('does not flag a profile as duplicated against its own account cache', () => {
  const start = html.indexOf('function v504FindDuplicateAccountSnapshot(');
  const end = html.indexOf('\nconst v504PendingGuest=', start);
  const ownKey = 'thedemianff_v504_progress_second%40example.com';
  const profile = { credits: 0, xp: 0, matches: 0, wins: 0, kills: 0, best: 0,
    skin: 0, unlocked: [0], weapon: 0, claimed: [] };
  const values = { [ownKey]: JSON.stringify(profile) };
  const context = {
    localStorage: {
      get length() { return Object.keys(values).length; },
      getItem(key) { return Object.prototype.hasOwnProperty.call(values, key) ? values[key] : null; },
      key(index) { return Object.keys(values)[index] ?? null; },
    },
    v504AccountProgress(email) {
      return 'thedemianff_v504_progress_' + encodeURIComponent(email.toLowerCase());
    },
    v443ValidateProgress(data) { return { ...data }; },
  };
  vm.runInNewContext(html.slice(start, end) +
    '\nresult=v504FindDuplicateAccountSnapshot("second@example.com",' +
    JSON.stringify(profile) + ');', context);
  assert.equal(context.result, '');
});

test('duplicate cloud profile is archived before a fresh profile is saved', () => {
  assert.ok(html.includes('v504FindDuplicateAccountSnapshot(v446GoogleEmail,saved)'));
  assert.ok(html.includes('const archiveKey=\\'thedemianff_duplicate_backup_\\''));
  assert.ok(html.includes('localStorage.setItem(archiveKey,JSON.stringify(saved))'));
  assert.ok(html.includes('v504SetLocalProgress(fresh)'));
  assert.ok(html.includes('v495CloudSave(JSON.stringify(fresh))'));
});
