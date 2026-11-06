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
});
