const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

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
  assert.match(html, /id="v26CameraDistance"[^>]*value="8\.5"/);
  assert.ok(html.includes('const tacticalBack=mobile?clamp(baseBack*1.05,8.5,14):baseBack;'));
  assert.ok(html.includes('const height=(mobile?2.85:2.9)-(mobile?.34:.28)*b;'));
  assert.ok(html.includes('const v432Camera={'));
  assert.ok(html.includes('const back=tacticalBack*(1-b)+Math.max(7.5,baseBack*.96)*b;'));
  assert.ok(html.includes('const shoulder=baseShoulder*(1-b)+baseShoulder*.90*b;'));
  assert.ok(html.includes('c.gun.scale.setScalar(activeIndex===4?1.0:activeIndex===0?.88:.86);'));
  assert.ok(html.includes("clamp(value,8.5,14)"));
  assert.ok(html.includes("clamp(value,1.6,2.4)"));
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

test('V57.4 right-shoulder framing places the operator left of the centered aim ray', () => {
  assert.match(html, /const baseShoulder=-clamp\(Number\(\$\('v26CameraShoulder'\)\.value\)\|\|2\.1,1\.6,2\.4\);/);
  assert.doesNotMatch(html, /const baseShoulder=clamp/);
  assert.match(html, /const shoulder=baseShoulder\*\(1-b\)\+baseShoulder\*\.90\*b;/);
  assert.match(html, /player\.position\.x\+Math\.cos\(camYaw\)\*this\.shoulder-Math\.sin\(camYaw\)\*this\.back/);
  assert.match(html, /const start=camera\.position\.clone\(\),direction=new THREE\.Vector3\(\);camera\.getWorldDirection\(direction\)/);
  assert.match(html, /reticle\.dataset\.scope=this\.active\(\)\.name/);
  assert.match(html, /cross\.dataset\.scope=this\.active\(\)\.name/);
  for (const scope of ['PUNTO', '2x', '4x', '8x']) {
    assert.ok(html.includes('#v10Reticle[data-scope="' + scope + '"]'), 'missing calibrated reticle: ' + scope);
  }
  assert.match(html, /#cross,#v10Reticle\{[^}]*z-index:140!important/);
});

test('V57.4 keeps every aiming indicator hidden outside a match and restores the center reticle in combat', () => {
  assert.match(html, /body:not\(\.v475InMatch\) #v10Reticle/);
  assert.match(html, /body:not\(\.v475InMatch\) #v434ScopeButton/);
  assert.match(html, /body:not\(\.v475InMatch\) #v434ScopeLabel/);
  assert.match(html, /body:not\(\.v475InMatch\) #v13AimMode/);
  assert.match(html, /body\.v475InMatch #v10Reticle\{display:block!important\}/);
  assert.match(html, /document\.body\.classList\.contains\('v475InMatch'\) && isADS && running/);
  assert.match(html, /camera\.getWorldDirection\(direction\)/);
});
test('V57.4 migrates old shoulder preferences to the wider right-hand framing range', () => {
  assert.match(html, /value="2\.1"/);
  assert.match(html, /clamp\(value,1\.6,2\.4\):2\.1/);
  assert.match(html, /const baseShoulder=-clamp/);
  assert.match(html, /baseShoulder\*\.90\*b/);
});
