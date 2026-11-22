extends RefCounted
## Aurora lobby render target budget. Only the 3D scene is downscaled;
## all native Controls, labels and touchscreen hitboxes keep full resolution.
## This is deliberately NOT the Battle Royale world's dynamic frame governor.
##
## Evidence: before V75.166 the 1280x720 native editor capture used a 640x360
## 3D SubViewport. For the normal setting 1280x720 now stays 1:1.
## The 964x434 Motorola capture already used 1:1 and must never regress.

const PIXEL_BUDGETS: Dictionary={
    "FLUIDEZ":550000.0,
    "EQUILIBRADO":1050000.0,
    "AUTO":1550000.0,
    "CLARIDAD":2180000.0
}
const MAX_SHRINK: int=4


static func shrink_for_size(size: Vector2,profile: String="AUTO") -> int:
    if not is_finite(size.x) or not is_finite(size.y):
        return MAX_SHRINK
    if size.x<=0.0 or size.y<=0.0:
        return MAX_SHRINK
    var pixels: float=size.x*size.y
    if not is_finite(pixels):
        return MAX_SHRINK
    var budget: float=float(PIXEL_BUDGETS.get(profile,
        PIXEL_BUDGETS["AUTO"]))
    return clampi(ceili(sqrt(pixels/budget)),1,MAX_SHRINK)


static func allocated_pixels(size: Vector2,shrink: int) -> float:
    if shrink<=0:
        return 0.0
    return maxf(0.0,size.x)*maxf(0.0,size.y)/float(shrink*shrink)
