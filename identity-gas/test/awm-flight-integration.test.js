const test=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../../app/src/main/assets/index.html'),'utf8');
const gradle=fs.readFileSync(path.join(__dirname,'../../app/build.gradle'),'utf8');
const workflow=fs.readFileSync(path.join(__dirname,'../../.github/workflows/build-apk.yml'),'utf8');

test('AWM is the sixth weapon with sniper-class handling and dedicated 8x scope',()=>{
 assert.ok(html.includes("{name:'AWM · FRANCOTIRADOR',type:'sniper',scope:'8x',damage:118,rate:1.28,mag:5,ammo:5,reserve:30,reserveMax:30,reload:3.45,spread:.0018,range:260}"));
 assert.equal((html.match(/scope:'8x'/g)||[]).length,1);
 assert.ok(html.includes("isSniper(){return weaponIndex===5&&weapons[weaponIndex]?.scope==='8x';}"));
 assert.ok(html.includes("weaponIndex===5?.94"));
});

test('generic weapons expose only point, 2x and 4x; 8x is outside the cycle',()=>{
 const sightStart=html.indexOf('const v58Sights=');
 const profileStart=html.indexOf('profiles:[',sightStart);
 const sniperStart=html.indexOf('sniperProfile:',profileStart);
 assert.ok(sightStart>=0&&profileStart>sightStart&&sniperStart>profileStart);
 const genericProfiles=html.slice(profileStart,sniperStart);
 assert.ok(genericProfiles.includes("{name:'PUNTO',zoom:1"));
 assert.ok(genericProfiles.includes("{name:'2x',zoom:2"));
 assert.ok(genericProfiles.includes("{name:'4x',zoom:4"));
 assert.doesNotMatch(genericProfiles,/zoom:8|name:'8x'/);
 assert.ok(html.includes("sniperProfile:{name:'8x',zoom:8,sensitivity:.22,yawRate:.72,pitchRate:.54}"));
 assert.ok(html.includes("if(this.isSniper()){this.index=0;toast('AWM · MIRA FIJA 8X')"));
});

test('AWM has its own 3D scope tube, rings, lens, bolt and bipod',()=>{
 const start=html.indexOf('}else if(i===5){');
 const end=html.indexOf('}else if(i===3){',start);
 assert.ok(start>=0&&end>start);
 const model=html.slice(start,end);
 for(const token of ['scopeBody','TorusGeometry','opticLens','boltHandle','v40GunMetal'])assert.ok(model.includes(token),token);
});

test('optical overlay is a single circular element with centered reticle and per-sight aperture',()=>{
 assert.equal((html.match(/id="v58OpticOverlay"/g)||[]).length,1);
 assert.ok(html.includes("#v58OpticOverlay{display:none;position:fixed;inset:0"));
 assert.ok(html.includes("border-radius:50%;border:8px solid"));
 assert.ok(html.includes("body.v58OpticActive #v58OpticOverlay{display:block}"));
 assert.ok(html.includes("active.zoom===8?'31vmin':active.zoom===4?'34vmin':'37vmin'"));
 assert.ok(html.includes("body.v58OpticActive #v10Reticle"));
});

test('camera zoom scales sight image and first-person weapon separately from free camera',()=>{
 assert.ok(html.includes("weaponScale(){const zoom=clamp(Number(this.active().zoom)||1,1,8);return Math.pow(zoom,-.82);}"));
 assert.ok(html.includes("const sightScale=aiming?v58Sights.weaponScale():1"));
 assert.ok(html.includes("v58Sights.updateHud(aiming)"));
 assert.ok(html.includes("camera.fov=this.currentFov;camera.updateProjectionMatrix()"));
});

test('AWM and flight diagnostics expose values for device acceptance tests',()=>{
 assert.ok(html.includes("window.THEDEMIANFF_AWM_TEST=()=>"));
 assert.ok(html.includes("window.THEDEMIANFF_FLIGHT_CAMERA_TEST=()=>"));
 assert.ok(html.includes("awmExclusiveX8:v58Sights.isSniper()"));
});

test('flight camera pointer input remains active during aircraft and descent',()=>{
 assert.ok(html.includes("function htmlFlightModeSupportsCamera(){return window.v36FlightMode==='aircraft'||window.v36FlightMode==='descending';}"));
 assert.ok(html.includes("function v58FlightPointerDown(e)"));
 assert.ok(html.includes("function v58FlightPointerMove(e)"));
 assert.ok(html.includes("v58Camera.input(dx,dy,'flight',elapsedMs)"));
 assert.ok(html.includes("document.addEventListener('pointermove',v58FlightPointerMove,true)"));
 assert.ok(html.includes("return e.clientX>=window.innerWidth*.42"));
});

test('aircraft sequence starts, updates camera and exposes map and jump actions',()=>{
 assert.ok(html.includes("function v36Begin()"));
 assert.ok(html.includes("v58SetFlightMode('aircraft')"));
 assert.ok(html.includes("function v36TickAircraft(dt)"));
 assert.ok(html.includes("function v372FlightMap()"));
 assert.ok(html.includes("function v36Jump()"));
 assert.ok(html.includes("$('v37FlightJump').addEventListener"));
 assert.ok(html.includes("camera.lookAt(look.x,look.y+1.25,look.z)"));
});

test('deployment map retains route, POIs, destination selection and zoom controls',()=>{
 assert.ok(html.includes("function v36DrawMap(id)"));
 assert.ok(html.includes("c.setLineDash([11,8])"));
 assert.ok(html.includes("window.v27AuroraPOI"));
 assert.ok(html.includes("function v36ChoosePoint(e,id)"));
 assert.ok(html.includes("function v36InstallMapZoom(panelId,canvasId,suffix)"));
 assert.ok(html.includes("v36InstallMapZoom('v36DropPanel','v36DropCanvas','Drop')"));
 assert.ok(html.includes("v36InstallMapZoom('v36MapPanel','v36MapCanvas','Tactical')"));
 assert.ok(html.includes("v36MapZoom=clamp(Math.round(v36MapZoom*10)/10,.75,2.1)"));
});

test('parachute uses a timed canopy deployment blend and steerable glide',()=>{
 assert.ok(html.includes("v398ChuteOpen=true;v398DeployBlend=0"));
 assert.ok(html.includes("v398DeployBlend=Math.min(1,v398DeployBlend+dt/.62)"));
 assert.ok(html.includes("const glideSpeed=v398ChuteOpen?13.5:21"));
 assert.ok(html.includes("player.position.y-=(v398ChuteOpen?"));
 assert.ok(html.includes("v36Chute.rotation.z"));
 assert.ok(html.includes("playerModel.left.rotation.x"));
});

test('airborne mode suppresses ADS and combat reticle until landing',()=>{
 assert.ok(html.includes("document.body.classList.toggle('v58FlightMode',airborne)"));
 assert.ok(html.includes("adsHeld=false;cameraDX=0;cameraDY=0"));
 assert.ok(html.includes("v58Sights.updateHud(false)"));
});

test('V60.0.0 integrated release preserves the offline AI gameplay scope',()=>{
 assert.ok(gradle.includes('versionCode 168'));
 assert.ok(gradle.includes("versionName '60.0.0-aurora-royale-integration'"));
 assert.ok(workflow.includes('codex/v60-v65-integration'));
 assert.ok(!gradle.includes("59.0.0"));
});

test('the AWM is reachable as weapon six from desktop controls',()=>{
 assert.match(html,/if\(e\.code==='Digit6'\)swap\(5\)/);
 assert.ok(html.includes('1-6 armas'));
});
