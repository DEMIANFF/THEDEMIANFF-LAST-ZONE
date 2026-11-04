const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '../..');
const html = fs.readFileSync(path.join(root, 'app/src/main/assets/index.html'), 'utf8');
const gradle = fs.readFileSync(path.join(root, 'app/build.gradle'), 'utf8');
const menuStart = html.indexOf('<div id="menu"');
const menuEnd = html.indexOf('</div><div id="end"', menuStart);
const menu = html.slice(menuStart, menuEnd > menuStart ? menuEnd : undefined);

test('V57.1 uses one clean lobby navigation and removes cloud shortcuts from the lobby', () => {
  assert.match(menu, /V57.1 · CENTRO DE OPERACIONES/);
  for (const section of ['TIENDA', 'PASE AURORA', 'OPERADORES', 'EVENTOS Y OBJETIVOS', 'ARSENAL', 'INVENTARIO', 'EQUIPAMIENTOS', 'SOCIAL']) {
    assert.ok(menu.includes(section), 'missing lobby section: ' + section);
  }
  assert.doesNotMatch(menu, /id="v500CloudBadge"/);
  assert.doesNotMatch(menu, /id="v533AccountShortcut"/);
  assert.doesNotMatch(menu, /id="v502CloudAccess"/);
  assert.doesNotMatch(menu, /data-lobby="MISIONES"|data-lobby="LOGROS"|data-lobby="EVENTOS"/);
  assert.doesNotMatch(menu, /class="v17Friends"/);
  assert.match(html, /#menu \.v17Friends,\#menu \.v17Quick\{display:none!important\}/);
});

test('Google account and cloud status remain accessible inside Settings > Account', () => {
  const accountStart = html.indexOf('<div class="settingsSection" data-section="account">');
  const accountEnd = html.indexOf('</div>', accountStart);
  const account = html.slice(accountStart, accountEnd);
  assert.match(account, /id="v443Google"/);
  assert.match(account, /id="v445SettingsLogout"/);
  assert.match(account, /id="v494CloudStatus"/);
  assert.match(html, /settingsSection\[data-section="account"\] #v443Google\{display:block!important/);
});

test('events, missions and achievements share a single three-tab operations hub', () => {
  assert.match(html, /id="v38Operations"/);
  for (const id of ['v38TabEvents', 'v38TabMissions', 'v38TabAchievements', 'v38EventsView', 'v38MissionsView', 'v38AchievementsView']) {
    assert.ok(html.includes('id="' + id + '"'), 'missing operations hub component: ' + id);
  }
  assert.match(html, /function v38RenderAchievements\(\)/);
  assert.match(html, /function v38SelectTab\(tab\)/);
  assert.match(html, /'OPERACIONES'\)v38OpenHub\('events'\)/);
  for (const id of ['scout', 'predator', 'champion', 'expert', 'ace', 'season']) {
    assert.ok(html.includes("id:'" + id + "'"), 'missing mission: ' + id);
  }
});

test('shop uses illustrated operator cards and all purchasable styles are real selectable skins', () => {
  assert.match(html, /v56StoreGrid/);
  assert.match(html, /v56StoreArt/);
  assert.match(html, /v56ArtFigure/);
  for (const skin of ['GUARDIÁN AURORA', 'SOMBRA PÚRPURA', 'NÓMADA ÁRTICO', 'ASALTO CARMESÍ', 'CENTINELA JADE', 'ÉLITE DORADA']) {
    assert.ok(html.includes(skin), 'missing new store operator: ' + skin);
  }
  assert.match(html, /data-v18="skin:'\+i\+'"/);
});

test('Aurora pass has 30 persistent free and Elite reward tiers without real-money billing', () => {
  assert.match(html, /Array\.from\(\{length:30\}/);
  assert.match(html, /data-v18="passbuy"/);
  assert.match(html, /pass_free_/);
  assert.match(html, /pass_elite_/);
  assert.match(html, /result\.passElite=p\.passElite===true/);
  assert.match(html, /result\.eventCompletions=eventCompletions/);
  assert.match(html, /p\.credits-=2400;p\.passElite=true/);
  assert.match(html, /No utiliza Google Play ni dinero real/);
  assert.match(html, /p\.claimed\.push\(key\)/);
});

test('combat camera follows vertically and the mobile shoulder framing is lower', () => {
  assert.match(html, /const height=\(mobile\?2\.85:2\.9\)-\(mobile\?\.34:\.28\)\*b;/);
  assert.match(html, /Smooth vertical tracking is essential: keep the shoulder camera attached to the player\.\n  if\(!Number\.isFinite\(camera\.position\.y\)/);
  assert.doesNotMatch(html, /thereafter\.\\n  if\(!Number\.isFinite\(camera\.position\.y\)/);
});

test('ADS optics provide calibrated 2x, 4x and 8x magnification with progressive sensitivity', () => {
  assert.match(html, /\{name:'2x',zoom:2,fov:39\.5,sensitivity:\.62\}/);
  assert.match(html, /\{name:'4x',zoom:4,fov:19\.75,sensitivity:\.36\}/);
  assert.match(html, /\{name:'8x',zoom:8,fov:9\.875,sensitivity:\.18\}/);
  assert.match(html, /targetFov=baseFov\/v434Optics\.active\(\)\.zoom/);
});

test('parachute camera is pulled back and Lila preview supports touch rotation at smoother frame pacing', () => {
  assert.match(html, /const d=clamp\(baseDistance\*2\.0,16,20\)/);
  assert.match(html, /const aerialHeight=v398ChuteOpen\?15:17/);
  assert.match(html, /#menu #v24LobbyStage\{pointer-events:auto!important;touch-action:pan-y!important/);
  assert.match(html, /if\(l\.renderer&&now-l\.last>\(mobile\?40:33\)\)/);
  assert.match(html, /l\.camera\.position\.set\(0,1\.92,7\.9\)/);
});

test('Android release is V57.1 with a monotonic version code', () => {
  assert.match(gradle, /versionCode 145/);
  assert.match(gradle, /versionName '57.1-camera-lobby-ux'/);
});

test('V57 Android package metadata is monotonic and matches the lobby release', () => {
  assert.match(gradle, /versionCode 145/);
  assert.match(gradle, /versionName '57.1-camera-lobby-ux'/);
  assert.match(html, /V57.1 · CENTRO DE OPERACIONES/);
});
