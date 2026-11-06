const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../../app/src/main/assets/index.html'),'utf8');

const styleStart=html.indexOf('<style id="v592HudStateIsolation">');
const styleEnd=html.indexOf('</style>',styleStart);
const stateCss=html.slice(styleStart,styleEnd);

test('match HUD is hidden outside the active match and isolated while the tactical map is open',()=>{
 assert.ok(styleStart>=0&&styleEnd>styleStart,'HUD state isolation stylesheet exists');
 for(const id of ['.top','#minimap','#zoneInfo','#health','#weapon','#controls','#v36MapPanel','#v36DropPanel'])
  assert.ok(stateCss.includes('body:not(.v475InMatch) #ui > '+id),'lobby hides '+id);
 for(const id of ['.top','#minimap','#zoneInfo','#health','#weapon','#controls'])
  assert.ok(stateCss.includes('body.v36MapOpen #ui > '+id),'map hides '+id);
 assert.ok(html.includes("document.body.classList.add('v36MapOpen')"));
 assert.ok(html.includes("document.body.classList.remove('v36MapOpen')"));
});

test('the in-match status is a single compact row without the old brand header',()=>{
 const top=html.slice(html.indexOf('<div class="top">'),html.indexOf('<canvas id="minimap"'));
 assert.ok(top.includes('id="matchStatus"'));
 assert.ok(top.includes('id="alive"')&&top.includes('id="kills"'));
 assert.ok(top.includes('id="round"')&&top.includes('id="timer"')&&top.includes('id="zoneText"'));
 assert.doesNotMatch(top,/THEDEMIANFF \/\/ LAST ZONE|id="rightTop"/);
 assert.ok(stateCss.includes('body.v58FlightMode #ui>#health,body.v58FlightMode #ui>#weapon{display:none!important}'));
 assert.ok(stateCss.includes('body.v58OpticActive #ui>#minimap,body.v58OpticActive #ui>#zoneInfo{display:none!important}'));
 assert.ok(stateCss.includes('body:has(#pausePanel:not(.hidden)) #ui>#controls'));
});

test('HUD profile is version resilient and stored in Android private preferences',()=>{
 const java=fs.readFileSync(path.join(__dirname,'../../app/src/main/java/com/thedemianff/lastzone/MainActivity.java'),'utf8');
 assert.ok(html.includes('function hudNormalizeLayout(value)'));
 assert.ok(html.includes('native.saveHudProfile(payload)||saved'));
 assert.ok(html.includes("native.readHudProfile():''"));
 assert.ok(java.includes('readHudProfile()'));
 assert.ok(java.includes('saveHudProfile(String json)'));
 assert.ok(java.includes('thedemianff_hud_profile_v1'));
});

test('aim and crouch controls stay round and renderer diagnostics require an explicit debug flag',()=>{
 assert.ok(stateCss.includes('#controls #mobileBtns #aimBtn,#controls #mobileBtns #crouchBtn{width:54px;height:54px;padding:0!important;border-radius:50%!important'));
 assert.ok(html.includes("new URLSearchParams(location.search).get('debug')!=='1'"));
});

test('optic vignette leaves the entire touch HUD above it and passes pointer input through',()=>{
 assert.ok(stateCss.includes('#v58OpticOverlay{z-index:10!important;pointer-events:none!important}'));
 assert.ok(stateCss.includes('#v58OpticOverlay::before,#v58OpticOverlay::after{pointer-events:none!important}'));
 assert.ok(stateCss.includes('#ui{z-index:20!important}'));
 assert.ok(stateCss.includes('body:not(.v475InMatch) #v58OpticOverlay'));
});

test('2x, 4x and 8x scoped ADS use a clear eye-level view without the operator blocking the lens',()=>{
 assert.ok(html.includes("scoped=aiming&&v58Sights.active().zoom>1"));
 assert.ok(html.includes('if(player)player.visible=!scoped;'));
 assert.ok(html.includes('targetHeight=scoped ? 2.02 :'));
 assert.ok(html.includes('targetFov=2*Math.atan(Math.tan(baseFov*Math.PI/360)/zoom)*180/Math.PI'));
 assert.ok(html.includes("profile:'FREE_FIRE_HYBRID_TPS'"));
 assert.doesNotMatch(html,/name:'PUNTO'|MIRA PUNTO/);
 assert.ok(html.includes("{name:'2x',zoom:2"));
 assert.ok(html.includes("{name:'4x',zoom:4"));
});

test('Android always loads the current bundled screen and release verifies the packaged HTML',()=>{
 const java=fs.readFileSync(path.join(__dirname,'../../app/src/main/java/com/thedemianff/lastzone/MainActivity.java'),'utf8');
 const gradle=fs.readFileSync(path.join(__dirname,'../../app/build.gradle'),'utf8');
 const workflow=fs.readFileSync(path.join(__dirname,'../../.github/workflows/build-apk.yml'),'utf8');
 assert.ok(gradle.includes('versionCode 172'));
 assert.ok(gradle.includes("versionName '59.5.0-hud-cache-refresh'"));
 assert.ok(java.includes('GAME_BUILD="59.5.0-hud-cache-refresh"'));
 assert.ok(java.includes('index.html?build="+GAME_BUILD'));
 assert.ok(java.includes('Cache-Control","no-store, no-cache, must-revalidate'));
 assert.ok(java.includes('"UTF-8",200,"OK",headers,body'));
 assert.ok(workflow.includes("bundled=apk.read('assets/index.html')"));
 assert.ok(workflow.includes('if bundled != source:'));
});
