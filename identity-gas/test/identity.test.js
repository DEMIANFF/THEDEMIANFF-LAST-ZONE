'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync(require('node:path').join(__dirname, '..', 'Code.gs'), 'utf8');

class Properties {
  constructor(values) { this.values = { ...values }; }
  getProperty(key) { return Object.prototype.hasOwnProperty.call(this.values, key) ? this.values[key] : null; }
  setProperty(key, value) { this.values[key] = String(value); return this; }
  setProperties(values) { Object.entries(values).forEach(([key, value]) => this.setProperty(key, value)); }
  deleteProperty(key) { delete this.values[key]; }
}
class Range {
  constructor(sheet, row, col, rows = 1, cols = 1) { Object.assign(this, { sheet, row, col, rows, cols }); }
  getValues() {
    return Array.from({ length: this.rows }, (_, r) =>
      Array.from({ length: this.cols }, (_, c) => this.sheet.data[this.row - 1 + r]?.[this.col - 1 + c] ?? ''));
  }
  getValue() { return this.getValues()[0][0]; }
  setValues(values) {
    values.forEach((line, r) => {
      const index = this.row - 1 + r;
      while (this.sheet.data.length <= index) this.sheet.data.push([]);
      line.forEach((value, c) => { this.sheet.data[index][this.col - 1 + c] = value; });
    });
    return this;
  }
  createTextFinder(query) {
    const range = this;
    let exact = false;
    return {
      matchEntireCell(value) { exact = Boolean(value); return this; },
      findAll() {
        const found = [];
        for (let offset = 0; offset < range.rows; offset += 1) {
          const value = range.sheet.data[range.row - 1 + offset]?.[range.col - 1] ?? '';
          if (exact ? value === query : String(value).includes(String(query))) {
            found.push({ getRow: () => range.row + offset });
          }
        }
        return found;
      },
    };
  }
}
class Sheet {
  constructor(rows = [['firebaseUid', 'playerNumber', 'createdAt']]) { this.data = rows.map(row => [...row]); }
  getRange(row, col, rows = 1, cols = 1) { return new Range(this, row, col, rows, cols); }
  getLastRow() { return this.data.length; }
  setName(name) { this.name = name; }
  setFrozenRows(value) { this.frozenRows = value; }
}
class Spreadsheet {
  constructor(sheet = new Sheet()) { this.sheet = sheet; }
  getSheetByName(name) { return name === 'players' ? this.sheet : null; }
  getId() { return 'private-sheet-id'; }
  getUrl() { return 'https://docs.google.com/spreadsheets/d/private-sheet-id/edit'; }
  getSheets() { return [this.sheet]; }
}
function createEnv(options = {}) {
  const props = new Properties({
    FIREBASE_WEB_API_KEY: 'AIzaSy-test-api-key-0123456789',
    THEDEMIANFF_PLAYER_REGISTRY_SHEET_ID: 'private-sheet-id',
    THEDEMIANFF_PLAYER_ID_COUNTER: '0',
    ...(options.properties || {}),
  });
  const spreadsheet = options.spreadsheet || new Spreadsheet();
  const users = options.users || {};
  const calls = { lookup: 0, locks: 0, releases: 0, flushes: 0 };
  const context = {
    PropertiesService: { getScriptProperties: () => props },
    SpreadsheetApp: {
      openById: id => { assert.equal(id, 'private-sheet-id'); return spreadsheet; },
      create: () => spreadsheet,
      flush: () => { calls.flushes += 1; },
    },
    LockService: {
      getScriptLock: () => ({
        waitLock: () => { calls.locks += 1; if (options.lockFails) throw new Error('locked'); },
        releaseLock: () => { calls.releases += 1; },
      }),
    },
    UrlFetchApp: {
      fetch: (url, request) => {
        calls.lookup += 1;
        calls.url = url;
        const { idToken } = JSON.parse(request.payload);
        const result = users[idToken];
        return {
          getResponseCode: () => result ? (result.status || 200) : 400,
          getContentText: () => JSON.stringify(result?.body || { error: 'INVALID_ID_TOKEN' }),
        };
      },
    },
    ContentService: {
      MimeType: { JSON: 'application/json' },
      createTextOutput: content => ({
        content,
        setMimeType(type) { this.mimeType = type; return this; },
        getContent() { return this.content; },
      }),
    },
  };
  vm.runInNewContext(source, context, { filename: 'Code.gs' });
  const googleUser = uid => ({
    status: 200,
    body: { users: [{ localId: uid, disabled: false, emailVerified: true,
      providerUserInfo: [{ providerId: 'google.com' }] }] },
  });
  return {
    context, props, spreadsheet, calls, users, googleUser,
    post: body => context.doPost({ postData: { contents: JSON.stringify(body) } }),
    parse: output => JSON.parse(output.getContent()),
  };
}
const token = char => char.repeat(120);

test('verifies Google/Firebase token and assigns 00001 as integer 1', () => {
  const t = token('a');
  const env = createEnv({ users: { [t]: null } });
  env.users[t] = env.googleUser('uid-first');
  assert.deepEqual(env.parse(env.post({ idToken: t })), { ok: true, number: 1 });
  assert.equal(env.spreadsheet.sheet.data[1][0], 'uid-first');
  assert.equal(env.props.getProperty('THEDEMIANFF_PLAYER_ID_COUNTER'), '1');
  assert.equal(env.calls.locks, 1);
  assert.equal(env.calls.releases, 1);
});

test('same Firebase UID always receives the same number', () => {
  const t = token('b');
  const env = createEnv({ users: { [t]: null } });
  env.users[t] = env.googleUser('uid-same');
  assert.equal(env.parse(env.post({ idToken: t })).number, 1);
  assert.equal(env.parse(env.post({ idToken: t })).number, 1);
  assert.equal(env.spreadsheet.sheet.getLastRow(), 2);
});

test('different accounts receive consecutive unique numbers', () => {
  const tokens = [token('c'), token('d'), token('e')];
  const env = createEnv({ users: Object.fromEntries(tokens.map(t => [t, null])) });
  tokens.forEach((t, i) => { env.users[t] = env.googleUser('uid-' + i); });
  assert.deepEqual(tokens.map(t => env.parse(env.post({ idToken: t })).number), [1, 2, 3]);
});

test('rejects client-supplied UID and extra payload fields', () => {
  const env = createEnv();
  const result = env.parse(env.post({ idToken: token('f'), uid: 'victim' }));
  assert.equal(result.code, 'INVALID_ARGUMENT');
  assert.equal(env.calls.lookup, 0);
  assert.equal(env.spreadsheet.sheet.getLastRow(), 1);
});

test('rejects invalid Firebase ID tokens', () => {
  const env = createEnv();
  assert.equal(env.parse(env.post({ idToken: token('g') })).code, 'UNAUTHENTICATED');
  assert.equal(env.spreadsheet.sheet.getLastRow(), 1);
});

test('requires a linked Google provider and verified email', () => {
  const t1 = token('h'), t2 = token('i');
  const env = createEnv({ users: { [t1]: null, [t2]: null } });
  env.users[t1] = { status: 200, body: { users: [{ localId: 'uid-pass', emailVerified: true,
    providerUserInfo: [{ providerId: 'password' }] }] } };
  env.users[t2] = { status: 200, body: { users: [{ localId: 'uid-unverified', emailVerified: false,
    providerUserInfo: [{ providerId: 'google.com' }] }] } };
  assert.equal(env.parse(env.post({ idToken: t1 })).code, 'GOOGLE_REQUIRED');
  assert.equal(env.parse(env.post({ idToken: t2 })).code, 'GOOGLE_REQUIRED');
  assert.equal(env.spreadsheet.sheet.getLastRow(), 1);
});

test('fails closed when persistent counter and registry row count disagree', () => {
  const t = token('j');
  const env = createEnv({ properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '1' }, users: { [t]: null } });
  env.users[t] = env.googleUser('uid-new');
  assert.equal(env.parse(env.post({ idToken: t })).code, 'REGISTRY_CORRUPT');
  assert.equal(env.spreadsheet.sheet.getLastRow(), 1);
});

test('detects duplicate UID rows rather than returning an ambiguous identity', () => {
  const sheet = new Sheet([
    ['firebaseUid', 'playerNumber', 'createdAt'],
    ['uid-duplicate', 1, 'date'],
    ['uid-duplicate', 2, 'date'],
  ]);
  const t = token('k');
  const env = createEnv({ spreadsheet: new Spreadsheet(sheet),
    properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '2' }, users: { [t]: null } });
  env.users[t] = env.googleUser('uid-duplicate');
  assert.equal(env.parse(env.post({ idToken: t })).code, 'REGISTRY_CORRUPT');
  assert.equal(sheet.getLastRow(), 3);
});

test('rejects duplicate, skipped, reordered or text-formatted IDs anywhere in the registry', () => {
  const brokenRegistries = [
    [['uid-1', 1, 'date-1'], ['uid-2', 1, 'date-2']],
    [['uid-1', 1, 'date-1'], ['uid-2', 3, 'date-2']],
    [['uid-1', 2, 'date-1'], ['uid-2', 1, 'date-2']],
    [['uid-1', 1, 'date-1'], ['uid-2', '2', 'date-2']],
  ];

  brokenRegistries.forEach((records, index) => {
    const t = token(String.fromCharCode(110 + index));
    const sheet = new Sheet([['firebaseUid', 'playerNumber', 'createdAt'], ...records]);
    const env = createEnv({
      spreadsheet: new Spreadsheet(sheet),
      properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '2' },
      users: { [t]: null },
    });
    env.users[t] = env.googleUser('uid-new');
    assert.equal(env.parse(env.post({ idToken: t })).code, 'REGISTRY_CORRUPT');
    assert.equal(sheet.getLastRow(), 3);
  });
});

test('does not return an existing ID while another registry row is corrupt', () => {
  const sheet = new Sheet([
    ['firebaseUid', 'playerNumber', 'createdAt'],
    ['uid-existing', 1, 'date-1'],
    ['uid-corrupt', 4, 'date-2'],
  ]);
  const t = token('w');
  const env = createEnv({
    spreadsheet: new Spreadsheet(sheet),
    properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '2' },
    users: { [t]: null },
  });
  env.users[t] = env.googleUser('uid-existing');
  assert.equal(env.parse(env.post({ idToken: t })).code, 'REGISTRY_CORRUPT');
  assert.equal(sheet.getLastRow(), 3);
});

test('rejects non-canonical counter values instead of interpreting them as integers', () => {
  const t = token('x');
  const env = createEnv({
    properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '01' },
    users: { [t]: null },
  });
  env.users[t] = env.googleUser('uid-new');
  assert.equal(env.parse(env.post({ idToken: t })).code, 'REGISTRY_CORRUPT');
  assert.equal(env.spreadsheet.sheet.getLastRow(), 1);
});

test('enforces the maximum five-digit ID without writing another row', () => {
  const rows = [['firebaseUid', 'playerNumber', 'createdAt']];
  for (let i = 1; i <= 99999; i += 1) rows.push(['uid-' + i, i, 'date']);
  const t = token('l');
  const env = createEnv({ spreadsheet: new Spreadsheet(new Sheet(rows)),
    properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '99999' }, users: { [t]: null } });
  env.users[t] = env.googleUser('uid-last');
  assert.equal(env.parse(env.post({ idToken: t })).code, 'RESOURCE_EXHAUSTED');
  assert.equal(env.spreadsheet.sheet.getLastRow(), 100000);
});

test('does not repair or reset a partially configured registry', () => {
  const env = createEnv();
  env.props.deleteProperty('THEDEMIANFF_PLAYER_ID_COUNTER');
  assert.throws(() => env.context.setupRegistry(), /Configuración parcial/);
});


test('recovers one complete append interrupted before the counter update', () => {
  const sheet = new Sheet([
    ['firebaseUid', 'playerNumber', 'createdAt'],
    ['uid-committed-before-counter', 1, 'date-1'],
  ]);
  const env = createEnv({
    spreadsheet: new Spreadsheet(sheet),
    properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '0' },
  });
  const nextToken = 'r'.repeat(120);
  const oldToken = 's'.repeat(120);
  env.users[nextToken] = env.googleUser('uid-next');
  env.users[oldToken] = env.googleUser('uid-committed-before-counter');

  assert.equal(env.parse(env.post({ idToken: nextToken })).number, 2);
  assert.equal(env.props.getProperty('THEDEMIANFF_PLAYER_ID_COUNTER'), '2');
  assert.equal(sheet.getLastRow(), 3);
  assert.equal(env.parse(env.post({ idToken: oldToken })).number, 1);
  assert.equal(sheet.getLastRow(), 3);
});

test('refuses crash recovery when the uncommitted tail row is malformed', () => {
  const sheet = new Sheet([
    ['firebaseUid', 'playerNumber', 'createdAt'],
    ['uid-partial', 9, 'date-1'],
  ]);
  const env = createEnv({
    spreadsheet: new Spreadsheet(sheet),
    properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '0' },
  });
  const token = 'q'.repeat(120);
  env.users[token] = env.googleUser('uid-next');
  assert.equal(env.parse(env.post({ idToken: token })).code, 'REGISTRY_CORRUPT');
  assert.equal(env.props.getProperty('THEDEMIANFF_PLAYER_ID_COUNTER'), '0');
  assert.equal(sheet.getLastRow(), 2);
});


test('rejects an interrupted tail row above the five-digit ceiling', () => {
  const sheet = new Sheet([
    ['firebaseUid', 'playerNumber', 'createdAt'],
    ['uid-invalid-tail', 100000, 'date-1'],
  ]);
  const t = token('m');
  const env = createEnv({
    spreadsheet: new Spreadsheet(sheet),
    properties: { THEDEMIANFF_PLAYER_ID_COUNTER: '0' },
    users: { [t]: null },
  });
  env.users[t] = env.googleUser('uid-new');
  assert.equal(env.parse(env.post({ idToken: t })).code, 'REGISTRY_CORRUPT');
  assert.equal(env.props.getProperty('THEDEMIANFF_PLAYER_ID_COUNTER'), '0');
  assert.equal(sheet.getLastRow(), 2);
});
