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

test('V57.6 uses one clean lobby navigation and removes cloud shortcuts from the lobby', () => {
  assert.match(menu, /V58.1 · CENTRO DE OPERACIONES/);
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

test('V58.1 landed camera follows the Free Fire TPS shoulder rig vertically', () => {
  assert.match(html, /const targetHeight=\(mobile\?2\.46:2\.58\)-\.14\*b/);
  assert.match(html, /this\.anchorY\+\(player\.position\.y-this\.anchorY\)\*\(1-Math\.exp\(-t\*\(aiming\?11:8\)/);
  assert.match(html, /v58Camera\.update\(dt\)/);
  assert.match(html, /profile:'FREE_FIRE_THIRD_PERSON'/);
});

test('V58.1 ADS keeps third-person camera and uses Blood Strike-inspired sight magnification', () => {
  assert.match(html, /\{name:'2x',zoom:2,sensitivity:\.62\}/);
  assert.match(html, /\{name:'4x',zoom:4,sensitivity:\.36\}/);
  assert.match(html, /\{name:'8x',zoom:8,sensitivity:\.23\}/);
  assert.match(html, /targetFov=baseFov\/\(aiming\?v58Sights\.active\(\)\.zoom:1\)/);
  assert.match(html, /fireStability=channel==='fire'\?clamp/);
  assert.match(html, /sightFactor=this\.mode==='ADS'&&window\.v36FlightMode==='landed'\?v58Sights\.active\(\)\.sensitivity:1/);
});

test('V58.1 aircraft and parachute have their own responsive camera route', () => {
  assert.match(html, /function v58FlightPointerDown\(e\)/);
  assert.match(html, /function v58FlightPointerMove\(e\)/);
  assert.match(html, /const radius=22,look=v36Aircraft\.position/);
  assert.match(html, /const d=v398ChuteOpen\?16\.5:14\.5/);
  assert.match(html, /v58Camera\.updateAngles\(dt\)/);
  assert.match(html, /#menu #v24LobbyStage\{pointer-events:auto!important;touch-action:pan-y!important/);
  assert.match(html, /if\(l\.renderer&&now-l\.last>\(mobile\?40:33\)\)/);
  assert.match(html, /l\.camera\.position\.set\(0,1\.92,7\.9\)/);
});

test('Android release is V58.1 with monotonic version code', () => {
  assert.match(gradle, /versionCode 156/);
  assert.match(gradle, /versionName '58.1-freefire-thirdperson'/);
});

test('V58.1 Android package metadata and lobby label match', () => {
  assert.match(gradle, /versionCode 156/);
  assert.match(gradle, /versionName '58.1-freefire-thirdperson'/);
  assert.match(html, /V58.1 · CENTRO DE OPERACIONES/);
});

test('V57.6 activates the authored Aurora battle royale environment and visual resources', () => {
  const worldStart = html.indexOf('function v428CreateTrainingWorld');
  const worldEnd = html.indexOf('function createWorld', worldStart);
  const builder = html.slice(worldStart, worldEnd);
  assert.match(builder, /addWorldDetails\(\);\s*\/\/ V57\.3: activate the previously authored district architecture and instanced Aurora dressing\.\s*v396ExpandAurora\(\);\s*v397DetailAurora\(\);\s*v583SetupBattleVisuals\(\);/);
  assert.match(html, /function v396ExpandAurora\(\)/);
  assert.match(html, /function v397DetailAurora\(\)/);
  assert.match(html, /function v583SetupBattleVisuals\(\)/);
  assert.match(html, /new THREE\.CanvasTexture\(snowCanvas\)/);
  assert.match(html, /skyContext\.createLinearGradient\(0,0,0,512\)/);
  assert.match(html, /skyTexture\.mapping=THREE\.EquirectangularReflectionMapping/);
  assert.match(html, /scene\.background=assets\.skyTexture\|\|new THREE\.Color/);
  assert.match(html, /skyDome:false/);
  assert.doesNotMatch(html, /new THREE\.SphereGeometry\(560,28,16\)/);
  assert.match(html, /new THREE\.Points\(assets\.snowGeometry,assets\.snowMaterial\)/);
  assert.match(html, /zonePerimeter:!!zoneRing/);
  assert.match(html, /zoneVolume:false/);
  assert.match(html, /v583TickBattleVisuals\(dt\)/);
  assert.match(html, /v583UpdateZoneVisual\(zoneRadius,zoneCenter\.x,zoneCenter\.y,danger\)/);
  assert.match(html, /v583BuildPickupCase\(group,type\)/);
  assert.match(html, /window\.THEDEMIANFF_BATTLE_VISUAL_TEST/);
  assert.match(html, /const detailCounts=\[48,32,32,32,64,48\]/);
});

test('V57.6 visual roots dispose their private materials while shared GPU geometry survives resets', () => {
  assert.match(html, /const v396Root=new THREE\.Group\(\);v396Root\.name='V396_AURORA_DISTRICTS'/);
  assert.match(html, /window\.v396VisualRoot=v396Root/);
  assert.match(html, /const v397Root=new THREE\.Group\(\);v397Root\.name='V397_AURORA_DRESSING'/);
  assert.match(html, /window\.v397VisualRoot=v397Root/);
  assert.match(html, /function v583DisposeVisualRoot\(root\)/);
  assert.match(html, /v583DisposeVisualRoot\(window\.v396VisualRoot\)/);
  assert.match(html, /v583DisposeVisualRoot\(window\.v397VisualRoot\)/);
  assert.match(html, /g\.userData\.v583Shared=true/);
  assert.match(html, /palette\[key\]\.userData\.v583Shared=true/);
  assert.match(html, /obj\.geometry&&!obj\.geometry\.userData\.v583Shared/);
});

test('Android release version remains monotonic after the camera rebuild', () => {
  assert.match(gradle, /versionCode 156/);
  assert.match(gradle, /versionName '58.1-freefire-thirdperson'/);
  assert.match(html, /V58.1 · CENTRO DE OPERACIONES/);
});
test('V57.6 opens the homes and removes free-standing grey block obstacles', () => {
  assert.match(html, /function v576RegisterOpenBuilding/);
  assert.match(html, /doorWidthMeters:3\.0/);
  assert.match(html, /looseFrostStones:false/);
  assert.match(html, /greyDistrictCrates:false/);
  assert.match(html, /valleyRockCliffs:false/);
  assert.match(html, /openBuildings:window\.v576OpenBuildingCount\|\|0/);
  assert.match(html, /zonePerimeterOnGround:!!zoneRing/);
  assert.match(html, /id="v586ReticleRestored"/);
});


test('V57.8.2 keeps doorWidth in scope across both building-construction blocks', () => {
  const placeStart = html.indexOf('function place(x,z,w,h,d,material,kind){');
  const place = html.slice(placeStart, placeStart + 3000);
  assert.ok(placeStart >= 0, 'building placement function is missing');
  assert.ok(place.indexOf('const doorWidth=3.0;') >= 0, 'doorWidth declaration is missing');
  assert.ok(place.indexOf('const doorWidth=3.0;') < place.indexOf("if(kind==='building'){"), 'doorWidth must be declared outside the first building block');
  assert.ok(place.includes('v40BuildingDetails(g,w,h,d,doorWidth);'), 'second building pass must receive the shared doorWidth');
});

test('V57.8.2 binds the start button before later boot code and reports initialization errors', () => {
  assert.ok(html.includes("v578StartButton.addEventListener('click',start)"));
  assert.ok(html.includes("startStage='webgl-renderer'"));
  assert.ok(html.includes("startStage='world-reset';reset();"));
  assert.ok(html.includes("startStage='flight-sequence';v36Begin();"));
  assert.ok(html.includes("window.__THEDEMIANFF_START_DIAGNOSTIC={stage:startStage,message:"));
  assert.ok(html.includes("panel.textContent='NO SE PUDO INICIAR LA PARTIDA"));
  assert.ok(html.includes("launchButton.textContent='REINTENTAR PARTIDA'"));
  assert.ok(html.includes("launchButton.textContent='▶ INICIAR PARTIDA'"));
  assert.doesNotMatch(html, /\$\('start'\)\.onclick=start/);
});

test('V58.1 package and lobby labels identify the Free Fire camera release', () => {
  assert.match(gradle, /versionCode 156/);
  assert.match(gradle, /versionName '58\.1-freefire-thirdperson'/);
  assert.match(html, /V58\.1 · CENTRO DE OPERACIONES/);
});
