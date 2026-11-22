extends SceneTree
## V75.166 verifies actual native Godot lobby, two mobile/desktop sizes,
## real skinned Lila and new bounded 3D render target clarity.
const POLICY=preload("res://scripts/ui/aurora_lobby_resolution.gd")
const SAFE_SCREEN=preload("res://scripts/ui/safe_screen.gd")
const QUALITY=preload("res://scripts/render/aurora_render_budget.gd")
var failed: bool=false


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75166_LOBBY_CLARITY "+reason)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    check(POLICY.shrink_for_size(Vector2(964,434))==1,
        "Motorola 964x434 lost native 3D resolution")
    check(POLICY.shrink_for_size(Vector2(1280,720))==1,
        "1280x720 lobby still rendered blurred 640x360")
    check(POLICY.shrink_for_size(Vector2(1280,720),"FLUIDEZ")==2,
        "low-end phone profile must allow bounded 3D downscale")
    check(POLICY.shrink_for_size(Vector2(1280,720),"EQUILIBRADO")==1,
        "balanced 1280x720 should render one pixel per source pixel")
    check(POLICY.shrink_for_size(Vector2(1920,1080),"AUTO")==2,
        "AUTO fullscreen must bound 1080p render cost")
    check(POLICY.shrink_for_size(Vector2(1920,1080),"CLARIDAD")==1,
        "requested high quality must respect full-HD user intent")
    check(POLICY.shrink_for_size(Vector2(3840,2160),"AUTO")==3,
        "4K preview must not allocate an unbounded 3D framebuffer")
    check(POLICY.shrink_for_size(Vector2.ZERO)==4,
        "invalid sizes require safe downscale")
    check(POLICY.allocated_pixels(Vector2(1280,720),1)==921600.0,
        "native viewport pixel budget calculation is incorrect")

    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    await process_frame
    var portrait: SubViewportContainer=front._preview_container
    var scene: SubViewport=portrait.get_node("PreviewViewport")
    check(front.stage=="lobby" and portrait.stretch and
        portrait.stretch_shrink==1 and scene.own_world_3d and
        scene.render_target_update_mode==SubViewport.UPDATE_WHEN_PARENT_VISIBLE,
        "964x434 live 3D lobby/lifecycle changed")
    check(front._preview_avatar!=null and
        front._preview_avatar.find_child("Lila_Aurora_Mesh",true,false)!=null,
        "Lila model was replaced with flat image")
    check(front._bottom_navigation.get_child_count()==5 and
        front._match_mode_selector.visible and front._mode_gallery_entry==null,
        "lobby five-button and right-only BR controls changed")
    root.size=Vector2i(1280,720)
    await process_frame
    front._layout_safe()
    await process_frame
    var safe: Rect2=SAFE_SCREEN.rect(root)
    var chosen: int=POLICY.shrink_for_size(safe.size,QUALITY.read_profile())
    check(chosen==1 and portrait.stretch_shrink==1,
        "1280x720 live 3D render target is still unnecessarily reduced")
    check(POLICY.allocated_pixels(safe.size,portrait.stretch_shrink)<=2180000.0,
        "lobby 3D target exceeds CLARIDAD budget")
    root.size=Vector2i(964,434)
    await process_frame
    front._layout_safe()
    await process_frame
    check(portrait.stretch_shrink==1,
        "return to Motorola size did not restore full clarity")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75166_LOBBY_CLARITY PASS 964x434=1:1 1280x720=1:1 "+
            "profiles=4 4k_bounded=1 Lila=GLB footer=5 BR=1 "+
            "mobile_device_FPS=unmeasured")
    quit(1 if failed else 0)
