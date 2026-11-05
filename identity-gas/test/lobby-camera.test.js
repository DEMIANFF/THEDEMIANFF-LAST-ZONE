const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const htmlPath = path.join(__dirname, '../../app/src/main/assets/index.html');
const html = fs.readFileSync(htmlPath, 'utf8');

test('lobby profile header opens the unified account panel', () => {
  assert.match(html, /id="v18Profile"[^>]*role="button"/);
  assert.ok(html.includes("$('v18Profile').onclick=()=>v18Open('CUENTA DE JUGADOR')"), 'profile header must open the unified account panel');
  assert.match(html, /id="v536LobbyName"/);
  assert.match(html, /id="v536LobbyId"/);
  assert.match(html, /id="v536LobbyAvatar"/);
});

test('identity and statistics are no longer duplicated in the lobby navigation', () => {
  assert.doesNotMatch(html, /data-lobby="CUENTA DE JUGADOR"/);
  assert.doesNotMatch(html, /data-lobby="ESTADÍSTICAS"/);
  assert.match(html, /PROGRESO Y ESTADÍSTICAS/);
  for (const metric of ['NIVEL', 'PARTIDAS', 'VICTORIAS', 'BAJAS', 'BAJAS \/ PARTIDA', 'MEJOR MARCA', 'XP PARA SUBIR']) {
    assert.ok(html.includes(metric), 'missing profile metric: ' + metric);
  }
});

test('V58.1 uses one Free Fire third-person camera with stable shoulder follow and smooth zoom', () => {
  assert.match(html, /id="v26CameraDistance"[^>]*min="6\.5" max="10\.5" step="\.25" value="7\.8"/);
  assert.match(html, /id="v26CameraShoulder"[^>]*min="\.65" max="1\.5" step="\.05" value="1\.05"/);
  assert.match(html, /const v58Camera=\{/);
  assert.match(html, /profile:'FREE_FIRE_THIRD_PERSON'/);
  assert.match(html, /const targetBack=baseBack\*\(1-\.20\*b\),targetShoulder=baseShoulder\*\(1-\.34\*b\)/);
  assert.match(html, /const follow=1-Math\.exp\(-t\*13\.5\)/);
  assert.match(html, /v404SafeCameraTarget\(desired\)/);
  assert.match(html, /v586UpdateBuildingVisibility\(t\)/);
  assert.match(html, /this\.currentFov\+=\(targetFov-this\.currentFov\)/);
  assert.match(html, /c\.gun\.scale\.setScalar\(activeIndex===4\?\.86:activeIndex===0\?\.80:\.78\)/);
});

test('repeated identical gameplay notices are throttled', () => {
  assert.match(html, /v556LastToastAt/);
  assert.match(html, /now-v556LastToastAt<2600/);
});

test('unified account statistics use real JavaScript line breaks', () => {
  assert.equal(
    html.includes('Number(p.xp)||0);\\n  const level='),
    false,
    'profile statistics must not contain literal backslash-n separators'
  );
  assert.match(html, /Number\(p\.xp\)\|\|0\);\n  const level=/);
});

test('V57 bounds rapid mobile camera swipes without adding post-release drift', () => {
  assert.match(html, /function flushCamera\(dt\)/);
  assert.match(html, /const maxStep=Math\.max\(10,Math\.min\(30,frameDt\*900\)\)/);
  assert.match(html, /if\(active\)\{cameraDX-=dx;cameraDY-=dy;\}/);
  assert.match(html, /else\{cameraDX=0;cameraDY=0;\}/);
});
test('V57 lobby gives the operator, Social navigation and launch controls separate space', () => {
  assert.match(html, /id="v57LobbyCameraStability"/);
  assert.match(html, /#menu \.v17Left\{left:1\.2%/);
  assert.match(html, /#menu \.v24Hero\{left:50%/);
  assert.match(html, /#menu \.v18ModePick\{right:1\.5%/);
  assert.match(html, /data-lobby="SOCIAL"/);
  assert.match(html, /id="v581LobbyCameraUX"/);
  assert.match(html, /#v37AdvancedControl\{display:none!important\}/);
  assert.match(html, /class="v581Currency"/);
  assert.match(html, /max-width:min\(34vw,315px\)/);
});

test('V58.1 keeps right-shoulder framing and a centered sight ray', () => {
  assert.match(html, /baseShoulder=-clamp\(Number\(\$\('v26CameraShoulder'\)\.value\)\|\|1\.05,\.65,1\.5\)/);
  assert.match(html, /const targetBack=baseBack\*\(1-\.20\*b\),targetShoulder=baseShoulder\*\(1-\.34\*b\),targetHeight=\(mobile\?2\.46:2\.58\)-\.14\*b/);
  assert.ok(html.includes('player.position.x+Math.cos(camYaw)*this.shoulder-Math.sin(camYaw)*this.back'));
  assert.match(html, /reticle\.dataset\.scope=this\.active\(\)\.name/);
  assert.match(html, /#cross,#v10Reticle\{[^}]*z-index:140!important/);
});

test('V58.1 hides crosshair and all sights in plane and parachute states', () => {
  assert.match(html, /body\.v58FlightMode #cross/);
  assert.match(html, /body\.v58FlightMode #v10Reticle/);
  assert.match(html, /body\.v58FlightMode #v58ScopeButton/);
  assert.match(html, /body\.v58FlightMode #v58ScopeLabel/);
  assert.match(html, /body\.v475InMatch:not\(\.v58FlightMode\) #cross/);
  assert.match(html, /body\.v475InMatch:not\(\.v58FlightMode\) #v10Reticle\.v58ADS/);
  assert.match(html, /function v58SetFlightMode\(mode\)/);
  assert.match(html, /const inAir=mode==='aircraft'\|\|mode==='descending'/);
});
test('V58.1 migrates old camera preferences into the Free Fire distance and shoulder ranges', () => {
  assert.match(html, /value="7\.8"/);
  assert.match(html, /value="1\.05"/);
  assert.match(html, /const migrated=Number\.isFinite\(value\)\?\(value>10\.5\?value\*\.78:value\):7\.8/);
  assert.match(html, /const calibrated=Number\.isFinite\(value\)\?clamp\(value>1\.5\?value\*\.45:value,\.65,1\.5\):1\.05/);
  assert.match(html, /localStorage\.setItem\('v26-pref-'\+id,String\(calibrated\)\)/);
});

test('V58.1 camera follows with damped shoulder, vertical and horizontal smoothing', () => {
  assert.match(html, /targetHeight=\(mobile\?2\.46:2\.58\)-\.14\*b/);
  assert.match(html, /const follow=1-Math\.exp\(-t\*13\.5\)/);
  assert.match(html, /followXZ=1-Math\.exp\(-t\*13\)/);
  assert.match(html, /this\.anchorY\+=\(player\.position\.y-this\.anchorY\)\*\(1-Math\.exp\(-t\*\(aiming\?11:8\)/);
  assert.match(html, /const alpha=obstructed\?1-Math\.exp\(-t\*29\):followXZ/);
});
test('V58.1 provides one clean free-look dot and a separate ADS sight reticle', () => {
  assert.match(html, /<style id="v58FreeFireCamera">/);
  assert.match(html, /body\.v475InMatch:not\(\.v58FlightMode\) #cross/);
  assert.match(html, /body\.v475InMatch:not\(\.v58FlightMode\) #v10Reticle\.v58ADS/);
  assert.match(html, /#v10Reticle:before,#v10Reticle:after/);
  for (const scope of ['PUNTO','2x','4x','8x']) assert.ok(html.includes('#v10Reticle[data-scope="' + scope + '"]'));
});
test('V57.6 removes grey blocks and opens the house and district entrances', () => {
  assert.doesNotMatch(html, /new THREE\.BoxGeometry\(3,3\+j%3\*2,3\),darkIce/);
  assert.doesNotMatch(html, /new THREE\.DodecahedronGeometry\(2\.2\+i%3,0\),metal/);
  assert.doesNotMatch(html, /for\(let i=0;i<62;i\+\+\)/);
  assert.doesNotMatch(html, /place\(x\+dx,z\+dz,w,h,d,dx%2\?steel:frost,'crate'\)/);
  assert.match(html, /function v576RegisterWallRun/);
  assert.match(html, /function v576RegisterOpenBuilding/);
  assert.match(html, /v576RegisterOpenBuilding\(xx-86,zz-82,w,wall,depth,doorWidth,thickness\)/);
  assert.match(html, /v576RegisterOpenBuilding\(x,z,w,h,d,doorWidth,thickness\)/);
  assert.match(html, /window\.THEDEMIANFF_AURORA_ACCESS_TEST/);
  assert.match(html, /doorWidthMeters:3\.0/);
  assert.doesNotMatch(html, /v426Rock:true/);
});

test('V57.6 keeps only the floor-level zone perimeter, not a translucent volume around the operator', () => {
  assert.match(html, /zonePerimeter:!!zoneRing/);
  assert.match(html, /zoneVolume:false/);
  assert.doesNotMatch(html, /new THREE\.CylinderGeometry\(1,1,10,72,1,true\)/);
  assert.doesNotMatch(html, /V583_SAFE_ZONE_WALL/);
  assert.match(html, /zoneRing\.position\.set\(zoneCenter\.x,ground\(zoneCenter\.x,zoneCenter\.y\)\+\.25,zoneCenter\.y\)/);
});



const v577CollisionStart = html.indexOf('function v577ResolveBotWallSlide(');
const v577CollisionEnd = html.indexOf('window.THEDEMIANFF_BOT_COLLISION_TEST=', v577CollisionStart);
assert.ok(v577CollisionStart >= 0 && v577CollisionEnd > v577CollisionStart,
  'V57.7 bot collision resolver must be present');
const v577CollisionSource = html.slice(v577CollisionStart, v577CollisionEnd).trim();
const v577Resolve = vm.runInNewContext('(' + v577CollisionSource + ')');
const v577Move = (...args) => JSON.parse(JSON.stringify(v577Resolve(...args)));

test('V57.7 bot movement keeps full motion when the path is clear', () => {
  assert.deepEqual(v577Move(0, 0, 2, 3, 0.4, () => false),
    { x: 2, z: 3, movedX: true, movedZ: true, blocked: false });
});

test('V57.7 bots slide along a wall instead of freezing on diagonal contact', () => {
  const wallZ = (_x, z, radius) => z + radius > 1;
  assert.deepEqual(v577Move(0, 0, 2, 2, 0.25, wallZ),
    { x: 2, z: 0, movedX: true, movedZ: false, blocked: true });
  const wallX = (x, _z, radius) => x + radius > 1;
  assert.deepEqual(v577Move(0, 0, 2, 1, 0.25, wallX),
    { x: 0, z: 1, movedX: false, movedZ: true, blocked: true });
});

test('V57.7 diagonal corner contact chooses the axis with greater progress', () => {
  const corner = (x, z, radius) => x + radius > 0.5 && z + radius > 0.5;
  assert.deepEqual(v577Move(0, 0, 2, 1, 0.1, corner),
    { x: 2, z: 0, movedX: true, movedZ: false, blocked: true });
  assert.deepEqual(v577Move(0, 0, 1, 2, 0.1, corner),
    { x: 0, z: 2, movedX: false, movedZ: true, blocked: true });
});

test('V57.7 bots stop safely when both slide axes remain blocked', () => {
  const boxedIn = (x, z, radius) => x + radius > 0.5 || z + radius > 0.5;
  assert.deepEqual(v577Move(0, 0, 1, 1, 0.1, boxedIn),
    { x: 0, z: 0, movedX: false, movedZ: false, blocked: true });
});

test('V57.7 wall-slide integration preserves the original bot collision radius', () => {
  assert.ok(html.includes('v577ResolveBotWallSlide(b.x,b.z,bx-b.x,bz-b.z,.7*b.root.scale.x,solid)'));
  assert.ok(html.includes('if(v577Step.movedX){'));
  assert.ok(html.includes('else if(v577Step.movedZ){'));
  assert.ok(html.includes('b.velocityZ*=.28;'));
  assert.ok(html.includes('b.velocityX*=.28;'));
});


test('V57.8 reduces and smooths bot parachute canopies without disabling enemy landing', () => {
  assert.ok(html.includes('new THREE.SphereGeometry(1.55,14,8,0,Math.PI*2,0,Math.PI*.5)'));
  assert.ok(html.includes("chute.name='V578_BOT_PARACHUTE';chute.position.y=4.15"));
  assert.ok(html.includes('canopyRadius:1.55,canopySegments:'));
  assert.ok(html.includes('if(b.v362Chute){b.root.remove(b.v362Chute);'));
});

test('V57.8 enlarges houses and outposts while keeping their entrances and colliders aligned', () => {
  assert.match(html, /const w=10\.5,depth=10,levels=i%3===0\?2:1/);
  assert.match(html, /const wall=levels===2\?8\.2:5\.4,doorWidth=3\.0,thickness=\.38/);
  assert.match(html, /function v576RegisterOpenBuilding\(cx,cz,w,h,d,doorWidth=3\.0,thickness=\.38\)/);
  assert.ok(html.includes('[-14,-10,9,6.8,8],[13,10,10,7.8,8],[14,-12,7,5.8,7]'));
  assert.ok(html.includes('v40BuildingDetails(g,w,h,d,doorWidth)'));
});

test('V58.1 routes camera movement independently in aircraft, parachute and landed gameplay', () => {
  assert.match(html, /function v58FlightPointerDown\\(e\\)/);
  assert.match(html, /function v58FlightPointerMove\\(e\\)/);
  assert.match(html, /const v58FlightPointers=new Map\\(\\)/);
  assert.match(html, /function v36TickAircraft\\(dt\\)[\\s\\S]*?v58Camera\\.updateAngles\\(dt\\)/);
  assert.match(html, /if\\(running&&window\\.v36FlightMode==='aircraft'[^\\n]*v36TickAircraft\\(dt\\)/);
  const start=html.indexOf('function v36StepFlight(dt){'),end=html.indexOf('function v36ChoosePoint(e,id)',start);
  const parachute=html.slice(start,end);
  assert.ok(start>=0&&end>start,'parachute update path must exist');
  assert.ok(parachute.includes('v58Camera.updateAngles(dt);'),'parachute must advance camera target angles');
  assert.match(parachute, /const d=v398ChuteOpen\\?16\\.5:14\\.5/);
  assert.doesNotMatch(html, /let v372PlaneTouch=/);
  const route=html.slice(html.indexOf('function v58FlightPointerAllowed(e)'),html.indexOf('function v58FlightPointerDown(e)'));
  assert.doesNotMatch(route, /#v37FlightHUD|#mobileBtns/,'non-interactive HUD containers must not block camera drag');
  assert.match(route, /#stickBase/,'joystick must remain excluded from camera look');
  assert.match(html, /v58SetFlightMode\\('aircraft'\\)/);
  assert.match(html, /v58SetFlightMode\\('descending'\\)/);
  assert.match(html, /v58SetFlightMode\\('landed'\\)/);
});
