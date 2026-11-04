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

test('hybrid third-person camera keeps a moderate mobile distance and lower shoulder framing', () => {
  assert.match(html, /id="v26CameraDistance"[^>]*min="9\.5" max="16" step="\.25" value="10"/);
  assert.ok(html.includes('const tacticalBack=mobile?clamp(baseBack*1.06,10,16):baseBack;'));
  assert.ok(html.includes('const height=(mobile?2.68:2.78)-(mobile?.20:.18)*b;'));
  assert.ok(html.includes('const v432Camera={'));
  assert.ok(html.includes('const back=tacticalBack*(1-b)+Math.max(7.5,baseBack*.96)*b;'));
  assert.ok(html.includes('const shoulder=baseShoulder*(1-b)+baseShoulder*.92*b;'));
  assert.ok(html.includes('c.gun.scale.setScalar(activeIndex===4?1.0:activeIndex===0?.88:.86);'));
  assert.ok(html.includes("clamp(value,9.5,16)"));
  assert.ok(html.includes("clamp(value,2.0,2.7)"));
  assert.ok(html.includes('aimFromFire(dx,dy)'));
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

test('V57.6 right-shoulder framing places the operator left of the centered aim ray', () => {
  assert.match(html, /const baseShoulder=-clamp\(Number\(\$\('v26CameraShoulder'\)\.value\)\|\|2\.35,2\.0,2\.7\);/);
  assert.doesNotMatch(html, /const baseShoulder=clamp/);
  assert.match(html, /const shoulder=baseShoulder\*\(1-b\)\+baseShoulder\*\.92\*b;/);
  assert.match(html, /player\.position\.x\+Math\.cos\(camYaw\)\*this\.shoulder-Math\.sin\(camYaw\)\*this\.back/);
  assert.match(html, /const start=camera\.position\.clone\(\),direction=new THREE\.Vector3\(\);camera\.getWorldDirection\(direction\)/);
  assert.match(html, /reticle\.dataset\.scope=this\.active\(\)\.name/);
  assert.match(html, /cross\.dataset\.scope=this\.active\(\)\.name/);
  for (const scope of ['PUNTO', '2x', '4x', '8x']) {
    assert.ok(html.includes('#v10Reticle[data-scope="' + scope + '"]'), 'missing calibrated reticle: ' + scope);
  }
  assert.match(html, /#cross,#v10Reticle\{[^}]*z-index:140!important/);
});

test('V57.6 keeps every aiming indicator hidden outside a match and restores the center reticle in combat', () => {
  assert.match(html, /body:not\(\.v475InMatch\) #v10Reticle/);
  assert.match(html, /body:not\(\.v475InMatch\) #v434ScopeButton/);
  assert.match(html, /body:not\(\.v475InMatch\) #v434ScopeLabel/);
  assert.match(html, /body:not\(\.v475InMatch\) #v13AimMode/);
  assert.match(html, /body\.v475InMatch #v10Reticle\{display:block!important\}/);
  assert.match(html, /document\.body\.classList\.contains\('v475InMatch'\) && isADS && running/);
  assert.match(html, /camera\.getWorldDirection\(direction\)/);
});
test('V57.6 migrates the previous shoulder default while preserving newer custom preferences', () => {
  assert.match(html, /value="2\.35"/);
  assert.match(html, /const calibrated=Number\.isFinite\(value\)&&value>2\.1\?clamp\(value,2\.0,2\.7\):2\.35;/);
  assert.match(html, /localStorage\.setItem\('v26-pref-'\+id,String\(calibrated\)\)/);
  assert.match(html, /const baseShoulder=-clamp\(Number\(\$\('v26CameraShoulder'\)\.value\)\|\|2\.35,2\.0,2\.7\);/);
  assert.match(html, /baseShoulder\*\.92\*b/);
});

test('V57.6 adds a little more shoulder clearance and smooths camera follow naturally', () => {
  assert.match(html, /min="2\.0" max="2\.7" step="\.05" value="2\.35"/);
  assert.match(html, /const baseShoulder=-clamp\(Number\(\$\('v26CameraShoulder'\)\.value\)\|\|2\.35,2\.0,2\.7\);/);
  assert.match(html, /const shoulder=baseShoulder\*\(1-b\)\+baseShoulder\*\.92\*b;/);
  assert.match(html, /const follow=1-Math\.exp\(-t\*13\);/);
  assert.match(html, /const followXZ=1-Math\.exp\(-t\*12\.5\);/);
  assert.match(html, /this\.mode==='ADS'\?10:6\.5/);
});
test('V57.6 restores the normal aiming point and keeps the ADS crosshair visible', () => {
  assert.match(html, /id="v586ReticleRestored"/);
  assert.match(html, /#v10Reticle:not\(\.v382ADS\)\{[^}]*border-color:#9cf9de!important/);
  assert.match(html, /#v10Reticle:not\(\.v382ADS\)\{[^}]*opacity:\.72!important/);
  assert.match(html, /#v10Reticle\.v382ADS\{[^}]*border-color:#aaf9dd!important/);
  assert.match(html, /body\.v475InMatch #cross\{[^}]*display:block!important/);
  assert.match(html, /body\.v475InMatch #v10Reticle\{visibility:visible!important\}/);
  assert.match(html, /#v10Reticle\.v382ADS::before/);
  assert.match(html, /#v10Reticle\.v382ADS::after/);
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

test('V57.8 keeps the 360-degree camera wrapped, calibrates X2/X4/X8 and widens aerial framing', () => {
  assert.match(html, /camYaw=Math\.atan2\(Math\.sin\(camYaw-dx\*\.003\),Math\.cos\(camYaw-dx\*\.003\)\)/);
  assert.ok(html.includes("{name:'2x',zoom:2,fov:39.5,sensitivity:.60}"));
  assert.ok(html.includes("{name:'4x',zoom:4,fov:19.75,sensitivity:.34}"));
  assert.ok(html.includes("{name:'8x',zoom:8,fov:9.875,sensitivity:.20}"));
  assert.ok(html.includes('const d=clamp(baseDistance*2.05,22,28);'));
  assert.ok(html.includes('const aerialHeight=v398ChuteOpen?18:20;'));
});
