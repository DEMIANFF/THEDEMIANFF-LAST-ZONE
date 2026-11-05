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
 assert.match(html,/const operatorName=\\$\\('v24OperatorName'\\);if\\(operatorName\\)operatorName\\.textContent=/);
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
test('the single launch banner reflects the selected local AI mode',()=>{
 assert.match(html,/const training=\$\('v18Mode'\)\?\.value==='training'/);
 assert.match(html,/RIVALES IA/);
 assert.match(markup,/id="v588ReadyCount"/);
 assert.doesNotMatch(markup,/v588OpsCard|v588OpponentCount|v588ModeCard/);
});
test('Arsenal is one destination; quick dock and Social keep their original panels',()=>{
 for(const action of ['INVENTARIO','PRESET','SOCIAL','OPERACIONES'])assert.match(markup,new RegExp('data-lobby="'+action+'"'));
 assert.equal((markup.match(/data-lobby="ARMAS"/g)||[]).length,1);
 assert.match(markup,/data-lobby="ARMAS">ABRIR ARSENAL/);
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
test('V58.8.2 lobby runtime guard is enabled in CI; live V59 multiplayer is excluded',()=>{
 assert.match(gradle,/versionCode 166/);
 assert.match(gradle,/versionName '58\.8\.2-lobby-runtime-guard'/);
 assert.match(workflow,/v58-8-2-lobby-runtime-guard/);
 assert.doesNotMatch(gradle,/59\.0\.0/);
});
test('wordmark is reduced to THEDEMIANFF and AURORA EVOLUTION only',()=>{
 assert.match(markup,/<div class="v17Brand"><strong>THEDEMIANFF<\/strong><small>AURORA EVOLUTION<\/small><\/div>/);
 assert.doesNotMatch(markup,/v502BrandSubtitle|LAST ZONE 3D|BATALLA REAL 3D/);
 assert.match(html,/#menu \.v17Brand\{[^}]*left:50%!important/);
});
test('technical labels and model caption are no longer visible in the lobby',()=>{
 assert.ok(html.includes("#menu #v22Edition,#menu #v494ModelStatus,#menu .v24HeroCaption,#menu .v502BrandSubtitle{display:none!important"));
 assert.doesNotMatch(markup,/v24HeroCaption/);
});
test('the lobby no longer layers an operation card behind the launch button',()=>{
 assert.doesNotMatch(markup,/v588OpsCard|v588OpponentCount|v588ModeCard/);
 assert.match(markup,/id="v588ReadyCount"/);
 assert.match(html,/#menu \.v17Bottom\{[^}]*justify-content:space-between!important/);
});
test('the lower dock contains only inventory and loadouts; Arsenal is in the right rail',()=>{
 const dock=markup.slice(markup.indexOf('<nav class="v588Dock"'),markup.indexOf('</nav>',markup.indexOf('<nav class="v588Dock"')));
 assert.match(dock,/data-lobby="INVENTARIO"/);
 assert.match(dock,/data-lobby="PRESET"/);
 assert.doesNotMatch(dock,/data-lobby="ARMAS"/);
 assert.equal((markup.match(/data-lobby="ARMAS"/g)||[]).length,1);
});
