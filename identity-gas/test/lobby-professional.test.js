const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../../app/src/main/assets/index.html'),'utf8');
const gradle=fs.readFileSync(path.join(__dirname,'../../app/build.gradle'),'utf8');
const workflow=fs.readFileSync(path.join(__dirname,'../../.github/workflows/build-apk.yml'),'utf8');
const start=html.indexOf('<div id="menu"'),end=html.indexOf('</div><div id="end"',start);
const markup=html.slice(start,end);
test('V58.8 professional lobby preserves exactly one real match start control',()=>{
 assert.equal((html.match(/id="start"/g)||[]).length,1);
 assert.match(markup,/id="start" type="button">▶ INICIAR PARTIDA/);
 assert.match(html,/function start\(\)/);
});
test('all primary lobby destinations are wired to existing data-lobby routing',()=>{
 for(const action of ['TIENDA','PASE','PERSONAJE','OPERACIONES','INVENTARIO','ARMAS','PRESET','SOCIAL'])assert.match(markup,new RegExp('data-lobby="'+action+'"'));
 assert.match(html,/document\.querySelectorAll\('\[data-lobby\]'\)/);
 assert.match(html,/document\.querySelectorAll\('#menu \[data-lobby\]'\)/);
});
test('operator showcase is the existing live Three.js character preview',()=>{
 assert.match(markup,/id="v24LobbyStage"/);
 assert.match(html,/function v24RefreshLobbyCharacter\(\)/);
 assert.match(html,/function v24LobbyTick\(\)/);
 assert.match(html,/#menu #v24LobbyStage\{[^}]*pointer-events:auto!important/);
});
test('drag-to-rotate remains interactive after lobby restyling',()=>{
 assert.match(html,/v38LobbyTouch\.addEventListener\('pointerdown'/);
 assert.match(html,/v38LobbyTouch\.addEventListener\('pointermove'/);
 assert.match(html,/#menu #v24LobbyStage\{[^}]*touch-action:none!important/);
});
test('weapon showcase follows the actual equipped weapon and statistics',()=>{
 assert.match(html,/function v588RefreshLobbyHud\(\)/);
 assert.match(html,/const index=clamp\(Number\(v18Progress\.weapon\)\|\|0,0,weapons\.length-1\)/);
 for(const id of ['v588WeaponName','v588WeaponDamage','v588WeaponMag','v588WeaponRange'])assert.match(markup,new RegExp('id="'+id+'"'));
});
test('operation rail reflects selected mode and labels local AI honestly',()=>{
 assert.match(html,/const training=\$\('v18Mode'\)\?\.value==='training'/);
 assert.match(html,/RIVALES IA/);
 assert.match(markup,/id="v588OpponentCount"/);
 assert.match(markup,/salas online se habilitarán en una etapa futura/);
});
test('quick dock, arsenal, social and operations use existing functional panels',()=>{
 for(const action of ['INVENTARIO','ARMAS','PRESET','SOCIAL','OPERACIONES'])assert.match(markup,new RegExp('data-lobby="'+action+'"'));
 assert.match(html,/else v18Open\(button\.dataset\.lobby\)/);
 assert.match(html,/function v38OpenHub\(/);
});
test('responsive layout rules exist for compact screens and short landscape phones',()=>{
 assert.match(html,/@media\(max-width:740px\)/);
 assert.match(html,/@media\(max-height:520px\)/);
 assert.match(html,/#menu \.v588Dock\{[^}]*display:flex!important/);
});
test('lobby module routing keeps player identity and mode selection intact',()=>{
 assert.match(markup,/id="v536LobbyId"/);
 assert.match(html,/function v18Open\(name\)/);
 assert.match(html,/v588RefreshLobbyHud\(\);/);
 assert.match(html,/v18ModeLabel/);
});
test('one integrated V58.8 release is enabled in CI; live V59 multiplayer is excluded',()=>{
 assert.match(gradle,/versionCode 164/);
 assert.match(gradle,/versionName '58\.8\.0-professional-lobby-suite'/);
 assert.match(workflow,/v58-8-professional-lobby-suite/);
 assert.doesNotMatch(gradle,/59\.0\.0/);
});
