#!/usr/bin/env python3
"""Regression guards for the V22 touch-controller contracts.

Static integration assertions plus independent camera-space vector tests.
These are not a substitute for Android multitouch testing.
"""
from pathlib import Path
import math

html = Path("app/src/main/assets/index.html").read_text(encoding="utf-8")
checks = {
    "camera free-look does not turn an idle player": "if(adsHeld||fireHeld)player.rotation.y+=" in html,
    "movement uses joystick X": "+joyX,mz=" in html,
    "movement uses joystick Y": "-joyY,mag=" in html,
    "camera-relative right vector": "(-mx*Math.cos(camYaw)+mz*Math.sin(camYaw))" in html,
    "camera-relative forward vector": "(mx*Math.sin(camYaw)+mz*Math.cos(camYaw))" in html,
    "camera drag uses pointer delta, not residual filter": "if(Math.abs(dx)+Math.abs(dy)>.25)aim(dx,dy,'free')" in html,
    "fire drag has independent pointer": "fireTouch=e.pointerId;fireHeld=true" in html,
    "fire drag moves reticle": "aim(dx,dy,'fire')" in html,
    "fire releases on pointer up": "document.addEventListener('pointerup',v123Release,true)" in html,
    "fire releases on cancellation": "document.addEventListener('pointercancel',v123Release,true)" in html,
    "joystick releases on lost capture": "stickBase.addEventListener('lostpointercapture',endJoy)" in html,
    "shoot uses updated camera": "camera.lookAt(camera.position.clone().addScaledVector(aimForward,100));" in html and "if(fireHeld)shoot();" in html,
    "no zoom pulses while firing": "const targetFov=adsHeld?58:68;" in html,
    "terrain camera smoothing": "camera.position.y+=(target.y-camera.position.y)" in html,
    "configurable shoulder camera": "const shoulder=-Number(" in html and "back=Number(" in html,
    "full horizontal yaw without clamping": "camYaw-=dx*.003*Number" in html,
    "vertical look range stabilized": "-.62,.98" in html,
    "camera gestures consumed once": "const dx=cameraDX,dy=cameraDY;" in html and "cameraDX=0;cameraDY=0;" in html,
    "aim assist yields to manual swipe": "cameraPointers.size>0||v22FireDragging" in html,
    "V23 single touch router enabled": "const v23ControlsEnabled=true;" in html,
    "V23 independent pointer roles": "const v23Touches=new Map();" in html and "role='joystick'" in html and "role='look'" in html and "role=id" in html and "else if(role==='fire')" in html,
    "V23 pointer cancellation cleanup": "document.addEventListener('pointercancel',v23PointerEnd,true)" in html,
    "V23 fire drag uses camera aim": "if(Math.abs(dx)+Math.abs(dy)>.12)aim(dx,dy,mode)" in html,
    "pause exit to lobby": 'id="leaveMatch"' in html and "function v23LeaveMatch()" in html and "$('leaveMatch').onclick=v23LeaveMatch" in html,
    "V24 3D lobby preview": 'id="v24LobbyStage"' in html and "function v24InitLobby()" in html,
    "V24 skin selection updates preview": "if(type==='skin')v24RefreshLobbyCharacter()" in html,
    "V24 render loop": "v24LobbyTick();" in html,
    "V25 terrain anchor stabilization": "v22ShoulderRig.anchorY+=(anchorGoal-v22ShoulderRig.anchorY)" in html,
    "V26 adaptive FPS resolution": "function v26TunePerformance(fps)" in html and "v26ApplyPixelRatio()" in html,
    "V26 six finger independent look": "let v26LookOwner=null;" in html and "now-v26LastLookMove>85" in html,
    "V26 no look pointer exclusivity": "role==='fire'||role==='look')&&" not in html,
    "V26 lost capture cleanup": "document.addEventListener('lostpointercapture',v23PointerEnd,true)" in html,
    "V26 browser touch action disabled": "$('controls').style.touchAction='none'" in html,
    "Aurora V27 named regions": "window.v27AuroraPOI=auroraPoi" in html and "BOSQUE LUMÍNICO" in html and "PUERTO VÓRTEX" in html,
    "Aurora V27 minimap markers": "window.v27AuroraPOI||[]" in html,
    "Aurora V27 arctic weather": "scene.background.setRGB(.065+mist*.025" in html,
    "Aurora glacial visual terrain": "color:'#c5e5f3'" in html and "const crater=2.8" in html,
    "Aurora glacial crater beacon": "const beacon=new THREE.Mesh" in html,
    "Aurora glacial named lobby": "AURORA GLACIAL" in html,
    "V26 camera controls": 'id="v26CameraDistance"' in html and 'id="v26CameraShoulder"' in html,
    "V26 touch curve": "const shape=d=>" in html and 'id="v26TouchDeadzone"' in html,
    "V26 HUD profiles": "function v26HudPreset(fingers)" in html and "function v26HudSaveProfile()" in html,
    "V26 lobby independent startup": "requestAnimationFrame(v26LobbyLoop);" in html and "function v26LobbyLoop()" in html,
    "V26 lobby tick independent of match loop": "requestAnimationFrame(frame);\n v24LobbyTick();" not in html,
    "V26 camera smoothing setting used": "const v26CameraSmooth=clamp(Number($('cameraSmooth').value)" in html,
    "V26 pointer jump clamp": "const dx=clamp(e.clientX-t.x,-55,55)" in html,
    "V26 minimap north compass": "c.fillText('N',w/2-5,17)" in html,
    "V24 Lila GLB loads into lobby": "v24Lobby.skin===4)v22ApplyLilaModel(v24Lobby.operator)" in html,
}
for name, ok in checks.items():
    assert ok, f"V22 control regression: {name}"
for yaw in [0, .3, 1.1, 2.4, -1.5]:
    right = (-math.cos(yaw), math.sin(yaw))
    forward = (math.sin(yaw), math.cos(yaw))
    assert abs(right[0]*forward[0]+right[1]*forward[1]) < 1e-12
    assert abs(math.hypot(*right)-1) < 1e-12
    assert abs(math.hypot(*forward)-1) < 1e-12
    for x in [-1, 1]:
        movement = (x*right[0], x*right[1])
        assert movement[0]*right[0]+movement[1]*right[1] == x or abs(movement[0]*right[0]+movement[1]*right[1]-x)<1e-12
print(f"OK: {len(checks)} controller guards + camera-space direction tests")
