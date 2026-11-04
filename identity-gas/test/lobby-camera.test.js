import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const htmlPath = fileURLToPath(new URL('../../app/src/main/assets/index.html', import.meta.url));
const html = readFileSync(htmlPath, 'utf8');

test('lobby profile header opens the unified account panel', () => {
  assert.match(html, /id="v18Profile"[^>]*role="button"/);
  assert.match(html, /\$\('v18Profile'\)\.onclick=\(\)=>v18Open\('CUENTA DE JUGADOR'\)/);
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

test('hybrid third-person camera keeps a moderate mobile distance and higher framing', () => {
  assert.match(html, /id="v26CameraDistance"[^>]*value="7\.0"/);
  assert.ok(html.includes('const tacticalBack=mobile?clamp(baseBack*1.10,3,12):baseBack;'));
  assert.ok(html.includes('const height=(mobile?3.75:3.45)-(mobile?.62:.35)*b;'));
  assert.ok(html.includes('const v432Camera={'));
  assert.ok(html.includes('aimFromFire(dx,dy)'));
});

test('repeated identical gameplay notices are throttled', () => {
  assert.match(html, /v556LastToastAt/);
  assert.match(html, /now-v556LastToastAt<2600/);
});
