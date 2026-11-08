extends RefCounted
## Convert Android physical safe insets into the expanded logical viewport.

static func rect(viewport: Viewport) -> Rect2:
    var logical: Vector2=viewport.get_visible_rect().size
    var full:=Rect2(Vector2.ZERO,logical)
    if not OS.has_feature("android"):
        return full
    var pixels: Vector2=Vector2(DisplayServer.window_get_size())
    var safe:=Rect2(DisplayServer.get_display_safe_area())
    if pixels.x<=0 or pixels.y<=0 or not safe.has_area():
        return full
    var ratio: Vector2=logical/pixels
    return Rect2(safe.position*ratio,safe.size*ratio).intersection(full)
