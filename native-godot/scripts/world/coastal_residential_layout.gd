extends RefCounted
## Authoritative residential placement for BOTH terrain grading and walkable
## villa instances. One coordinate list prevents elevated visual/physics homes
## from drifting away from the collision heightfield in later expansions.
##
## Every house is built on a real flat terrain pad; hills remain outside the
## lowland residential sites. All dimensions are in world metres.
const HOUSE_COUNT: int=8
const PAD_HEIGHT: float=7.0
const PAD_SIDE_MARGIN: float=6.7
const PAD_REAR_MARGIN: float=6.7
const PAD_FRONT_MARGIN: float=14.5
const PAD_BLEND_WIDTH: float=8.0
# World X, world Z, physical house width, physical house depth.
const SITES: Array[Vector4]=[
    Vector4(-4.0,42.0,11.2,8.0),
    Vector4(19.0,43.0,10.8,8.4),
    Vector4(43.0,41.0,11.3,8.3),
    Vector4(62.0,28.0,9.6,7.7),
    Vector4(-22.0,66.0,10.4,8.3),
    Vector4(26.0,68.0,11.0,8.4),
    # Former cliff-edge coordinates (-52,44) and (72,50) caused exposed
    # house foundations and unnecessarily steep approach ramps.
    Vector4(-55.0,60.0,10.8,8.2),
    Vector4(68.0,48.0,10.5,8.1)
]
const YAWS: Array[float]=[.04,-.09,.12,-.13,-.06,.08,.06,-.08]


## Smooth pad selection based on the ACTUAL rotated house footprint.
## 1 => flat, physically buildable residential land; 0 => original wilderness.
## Include terrain-vertex margin to ensure all heightfield triangles beneath
## the floor AND the complete door ramp end at the same terrain height.
static func grading_weight(x: float,z: float) -> float:
    var coverage: float=0.0
    for i in range(HOUSE_COUNT):
        var site: Vector4=SITES[i]
        var delta: Vector3=Vector3(x-site.x,0.0,z-site.y).rotated(
            Vector3.UP,-YAWS[i])
        var half_width: float=site.z*.5+PAD_SIDE_MARGIN
        var back: float=-site.w*.5-PAD_REAR_MARGIN
        var front: float=site.w*.5+PAD_FRONT_MARGIN
        var dx: float=maxf(0.0,absf(delta.x)-half_width)
        var dz: float=maxf(0.0,maxf(back-delta.z,delta.z-front))
        var outside: float=Vector2(dx,dz).length()
        var ratio: float=clampf(outside/PAD_BLEND_WIDTH,0.0,1.0)
        var smooth: float=ratio*ratio*(3.0-2.0*ratio)
        coverage=maxf(coverage,1.0-smooth)
    return coverage


static func entrance_world(index: int,distance_from_front: float=7.5) -> Vector2:
    var site: Vector4=SITES[index]
    var forward: Vector3=Vector3(0.0,0.0,site.w*.5+distance_from_front).rotated(
        Vector3.UP,YAWS[index])
    return Vector2(site.x+forward.x,site.y+forward.z)
