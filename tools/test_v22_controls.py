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
    "camera-relative right vector": "mx*Math.cos(camYaw)+mz*Math.sin(camYaw)" in html,
    "camera-relative forward vector": "-mx*Math.sin(camYaw)+mz*Math.cos(camYaw)" in html,
    "camera drag uses pointer delta, not residual filter": "if(Math.abs(dx)+Math.abs(dy)>.25)aim(dx,dy,'free')" in html,
    "fire drag has independent pointer": "fireTouch=e.pointerId;fireHeld=true" in html,
    "fire drag moves reticle": "aim(dx,dy,'fire')" in html,
    "fire releases on pointer up": "document.addEventListener('pointerup',v123Release,true)" in html,
    "fire releases on cancellation": "document.addEventListener('pointercancel',v123Release,true)" in html,
    "joystick releases on lost capture": "stickBase.addEventListener('lostpointercapture',endJoy)" in html,
    "shoot uses updated camera": "camera.lookAt(camera.position.clone().addScaledVector(aimForward,100));" in html and "if(fireHeld)shoot();" in html,
    "no zoom pulses while firing": "const targetFov=adsHeld?58:68;" in html,
    "terrain camera smoothing": "camera.position.y+=(target.y-camera.position.y)" in html,
    "no fire-induced shoulder camera jump": "const shoulder=adsHeld?1.25:1.9,back=adsHeld?3.65:6.1,height=adsHeld?2.15:2.85;" in html,
    "full horizontal yaw without clamping": "camYaw+=dx*.003*Number" in html,
    "vertical look range extended": "-1.30,1.30" in html,
    "camera gestures consumed once": "const dx=cameraDX,dy=cameraDY;" in html and "cameraDX=0;cameraDY=0;" in html,
    "aim assist yields to manual swipe": "cameraPointers.size>0||v22FireDragging" in html,
}
for name, ok in checks.items():
    assert ok, f"V22 control regression: {name}"
for yaw in [0, .3, 1.1, 2.4, -1.5]:
    right = (math.cos(yaw), -math.sin(yaw))
    forward = (math.sin(yaw), math.cos(yaw))
    assert abs(right[0]*forward[0]+right[1]*forward[1]) < 1e-12
    assert abs(math.hypot(*right)-1) < 1e-12
    assert abs(math.hypot(*forward)-1) < 1e-12
    for x in [-1, 1]:
        movement = (x*right[0], x*right[1])
        assert movement[0]*right[0]+movement[1]*right[1] == x or abs(movement[0]*right[0]+movement[1]*right[1]-x)<1e-12
print(f"OK: {len(checks)} controller guards + camera-space direction tests")
