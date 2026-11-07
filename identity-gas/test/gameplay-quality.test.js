const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const root=path.join(__dirname,'../..');
const html=fs.readFileSync(path.join(root,'app/src/main/assets/index.html'),'utf8');
const gradle=fs.readFileSync(path.join(root,'app/build.gradle'),'utf8');
const workflow=fs.readFileSync(path.join(root,'.github/workflows/build-apk.yml'),'utf8');
const audit=fs.readFileSync(path.join(root,'docs/V58.3_AUDITORIA_10_AREAS.md'),'utf8');
function evaluateFunction(name,nextMarker){const start=html.indexOf('function '+name+'('),end=nextMarker?html.indexOf(nextMarker,start):-1;assert.ok(start>=0&&end>start,'missing function source: '+name);const sandbox={};vm.runInNewContext(html.slice(start,end)+'\nthis.result='+name+';',sandbox);return sandbox.result;}
test('safe spawn selector ignores blocked/non-finite candidates and respects spacing',()=>{const select=evaluateFunction('v583SelectSafeSpawn','function v583FindNearbyClearPoint');const chosen=select([{x:NaN,z:0},{x:2,z:0},{x:6,z:0},{x:18,z:0}],x=>x<10,{x:0,z:0},12,2.2);assert.equal(chosen.x,18);const relaxed=select([{x:3,z:0},{x:7,z:0}],()=>false,{x:0,z:0},20,2.2);assert.equal(relaxed.x,7);});
test('world spawn fallback scans and fails closed instead of choosing blocked ground',()=>{assert.match(html,/for\(let i=0;i<180;i\+\+\)randomCandidates\.push/);assert.match(html,/for\(let x=-HALF\+9;x<=HALF-9;x\+=8\)for\(let z=-HALF\+9;z<=HALF-9;z\+=8\)/);assert.match(html,/No hay una posición de aparición libre en el mapa/);assert.doesNotMatch(html,/return\{x:rand\(-35,35\),z:rand\(-35,35\)\}/);});
test('AI enemy spawns reserve space from player, terrain and living bots',()=>{assert.match(html,/function v583SafeBotSpawn\(minR=17\)/);assert.match(html,/Math\.hypot\(x-b\.x,z-b\.z\)<5\.2/);assert.match(html,/const p=v583SafeBotSpawn\(minR\)/);});
test('landing recovery has a full fallback after local relocation attempts',()=>{const landing=html.slice(html.indexOf('function v404ResolveLanding'),html.indexOf('function v404SafeCameraTarget'));assert.match(landing,/radius<=24/);assert.match(landing,/const fallback=safePos\(0\)/);assert.match(landing,/!solid\(fallback\.x,fallback\.z,\.65\)/);});
test('loot spawns only in clear ground, is bounded and supply links only actual spawned pickups',()=>{const pickup=html.slice(html.indexOf('function spawnPickup'),html.indexOf('function reset'));assert.match(pickup,/pickups\.length>=96/);assert.match(pickup,/v583FindNearbyClearPoint\(x,z,\.9,12\)/);assert.match(pickup,/return pickup/);assert.match(html,/if\(spawned\)\{spawned\.v476Cache=cache;cache\.remaining\+\+;\}/);});
test('ammo loot replenishes the selected caliber pool with the AWM sniper pickup amount',()=>{const loop=html.slice(html.indexOf('for(let i=pickups.length-1'),html.indexOf('for(let i=effects.length-1'));assert.match(loop,/const weapon=weapons\[weaponIndex\],portion=/);assert.match(loop,/v63Inventory\.addAmmo\(weapon,portion,meds,armor\)/);assert.match(loop,/weapon\.caliber/);assert.doesNotMatch(loop,/for\(let j=0;j<weapons\.length;j\+\+\)/);});
test('safe-zone damage interrupts healing and refreshes HUD at bounded cadence',()=>{const amount=evaluateFunction('v583ZoneDamageAmount','function v583ApplyZoneDamage');assert.equal(amount(1,0),2.5);assert.equal(amount(2,3),10.4);assert.equal(amount(-1,2),0);assert.match(html,/BOTIQUÍN INTERRUMPIDO POR LA ZONA/);assert.match(html,/v583ZoneHudClock=\.40;updateHud\(\)/);assert.match(html,/v583ApplyZoneDamage\(dt\)\)return/);});
test('stored progression is bounded, deduplicated and internally consistent',()=>{const normalize=evaluateFunction('v583NormalizeProgress','let v18Progress=');const v=normalize({credits:150,xp:900,matches:4,wins:9,kills:7,best:12,skin:2,unlocked:[0,2,2,40],weapon:99,claimed:['a','a',4],passElite:true,eventCompletions:3,playerId:'00042',playerName:'Operador Aurora'});assert.equal(v.credits,150);assert.equal(v.wins,4);assert.equal(v.best,7);assert.deepEqual(Array.from(v.unlocked),[0,2]);assert.equal(v.skin,2);assert.equal(v.weapon,0);assert.deepEqual(Array.from(v.claimed),['a']);assert.equal(v.playerId,'00042');assert.equal(v.playerName,'Operador Aurora');const bad=normalize({credits:-5,xp:1e12,matches:1,wins:3,kills:2,best:9,skin:4,unlocked:[0],weapon:20,playerName:'<script>'});assert.equal(bad.credits,0);assert.equal(bad.xp,0);assert.equal(bad.wins,1);assert.equal(bad.best,2);assert.equal(bad.skin,0);assert.equal(bad.weapon,0);assert.equal(bad.playerName,undefined);});
test('Lila locomotion blends pace on touch start and stop',()=>{assert.match(html,/c\.v583AnimPace=Number\.isFinite\(c\.v583AnimPace\)\?c\.v583AnimPace:rawPace/);assert.match(html,/Math\.exp\(-dt\*14\)/);assert.match(html,/const pace=clamp\(c\.v583AnimPace,0,1\)/);});
test('mobile render settings guard invalid values and expose QA telemetry',()=>{assert.match(html,/const quality=Number\.isFinite\(rawQuality\)\?clamp\(rawQuality,\.45,1\.25\):\.8/);assert.match(html,/if\(!Number\.isFinite\(fps\)\|\|!renderer\|\|!running/);assert.match(html,/window\.THEDEMIANFF_V583_QUALITY=\(\)=>\(/);for(const field of ['activeBots','pickups','effects','worldObjects','contextLost','contextRestores','flightMode'])assert.ok(html.includes(field));});
test('V65 package and workflow identify the quality-pass release',()=>{assert.ok(gradle.includes("versionCode 174"));assert.ok(gradle.includes("versionName '65.0.0-aurora-royale-quality-pass'"));assert.ok(workflow.includes("v58-9-0-awm-camera-airdrop-release"));assert.ok(html.includes("AWM · FRANCOTIRADOR"));});
test('live multiplayer scope is documented honestly',()=>{assert.match(audit,/Not implemented as live networking/);assert.match(audit,/authoritative server tick/);assert.match(audit,/not a live 100-player online match client/);});

test('V60 ammunition pickups feed only the selected caliber pool and respect the backpack',()=>{
 const loop=html.slice(html.indexOf('for(let i=pickups.length-1'),html.indexOf('for(let i=effects.length-1'));
 assert.match(loop,/const weapon=weapons\[weaponIndex\],portion=/);
 assert.match(loop,/v63Inventory\.addAmmo\(weapon,portion,meds,armor\)/);
 assert.match(loop,/weapon\.caliber/);
 assert.doesNotMatch(loop,/for\(let j=0;j<weapons\.length;j\+\+\)/);
});

test('V60 reserves are shared by caliber and expand with backpack tiers',()=>{
 const create=evaluateFunction('v63CreateInventoryModel','const v63WeaponCalibers=');
 const defs=[
  {name:'DMR',caliber:'7.62 mm',reserve:60,reserveMax:60},
  {name:'LMG',caliber:'7.62 mm',reserve:180,reserveMax:180},
  {name:'SMG',caliber:'9 mm',reserve:210,reserveMax:210},
  {name:'Shotgun',caliber:'12 Gauge',reserve:36,reserveMax:36},
  {name:'Rifle',caliber:'5.56 mm',reserve:180,reserveMax:180},
  {name:'AWM',caliber:'.300 Magnum',reserve:5,reserveMax:30}
 ];
 const inventory=create(defs);
 assert.equal(inventory.getReserve(defs[0]),180);
 assert.equal(inventory.status(2,50),'MOCHILA LIGERA · 13/14 ESPACIOS');
 inventory.setReserve(defs[0],45);
 assert.equal(inventory.getReserve(defs[1]),45);
 assert.equal(inventory.addAmmo(defs[1],15,2,50),15);
 assert.equal(inventory.getReserve(defs[0]),60);
 assert.equal(inventory.getReserve(defs[2]),210);
 inventory.setReserve(defs[5],0);
 assert.equal(inventory.addAmmo(defs[5],50,2,50),30);
 assert.equal(inventory.upgradeBackpack(),true);
 assert.equal(inventory.medLimit(),8);
 inventory.setReserve(defs[5],0);
 assert.equal(inventory.addAmmo(defs[5],50,2,50),45);
 assert.equal(inventory.getReserve(defs[5]),45);
 assert.equal(inventory.upgradeBackpack(),true);
 assert.equal(inventory.medLimit(),12);
 assert.equal(inventory.upgradeBackpack(),false);
 assert.equal(inventory.snapshot(2,50).ammo.length,5);
 assert.equal(inventory.rarity('backpack'),'ÉPICO');
});

test('V63 backpack returns actual occupied slots and empty spaces',()=>{
 const create=evaluateFunction('v63CreateInventoryModel','const v63WeaponCalibers=');
 const defs=[
  {name:'AR',caliber:'5.56 mm',reserve:180,reserveMax:180},
  {name:'DMR',caliber:'7.62 mm',reserve:180,reserveMax:180},
  {name:'SMG',caliber:'9 mm',reserve:210,reserveMax:210},
  {name:'Shotgun',caliber:'12 Gauge',reserve:36,reserveMax:36},
  {name:'LMG',caliber:'7.62 mm',reserve:180,reserveMax:180},
  {name:'AWM',caliber:'.300 Magnum',reserve:30,reserveMax:30}
 ];
 const inventory=create(defs),snapshot=inventory.snapshot(2,50);
 assert.equal(snapshot.slots.length,14);assert.equal(snapshot.usedSlots,13);
 assert.equal(snapshot.slots[0].type,'weapon');assert.equal(snapshot.slots[13].type,'empty');
 assert.equal(snapshot.slots[13].slot,14);assert.equal(snapshot.items.filter(item=>item.type==='ammo').length,5);
 assert.equal(inventory.canAddStack(2,50),true);
 assert.equal(inventory.status(2,50),'MOCHILA LIGERA · 13/14 ESPACIOS');
 inventory.upgradeBackpack();assert.equal(inventory.snapshot(2,50).slots.length,18);
});

test('inventory screen renders safely and only opens on landed mode',()=>{
 assert.ok(html.includes('id="v63InventoryPanel"'));assert.ok(html.includes('id="v63InventoryGrid"'));
 assert.match(html,/function v63RenderInventory\(\)/);
 assert.match(html,/function v63OpenInventory\(\)[\s\S]{0,180}v36FlightMode!=='landed'/);
});

test('terrain collision height follows the rendered height map',()=>{
 assert.ok(html.includes('function ground(x,z){return h(x,z)}'));
});

test('V60 supply crates and enemy drops include upgrade loot and preserve rarity cues',()=>{
 assert.match(html,/backpack:\{shell:'#493965'.*label:'MOCHILA'/s);
 assert.ok(html.includes("['backpack',0,5]"));
 assert.match(html,/rarity:v63Inventory\.rarity\(type\)/);
 assert.ok(html.includes("type==='backpack'?'ÉPICO'"));
});
