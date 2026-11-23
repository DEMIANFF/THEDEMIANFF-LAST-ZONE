extends SceneTree
## V75.174: actual menu + 3D-only resolution persistence. This test
## does not claim a Motorola FPS improvement or synthetic mobile touch.
const RENDER=preload("res://scripts/render/aurora_render_budget.gd")
## Load settings when the active project autoloads are registered, not in
## isolated --check-only mode (AuroraLobbyMusic is not available there).
const HUD_LAYOUT=preload("res://scripts/persistence/hud_layout.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75174_RENDER_SCALE "+reason)


func _verify() -> void:
    check(RENDER.PROFILES.has("PERSONALIZADO"),
        "manual profile absent from existing quality selector")
    check(RENDER.save_custom_scale(.75)==OK,
        "manual 75% render scale not persisted")
    check(RENDER.read_profile()=="PERSONALIZADO" and
        absf(RENDER.read_custom_scale()-.75)<.001,
        "manual profile and scale did not survive ConfigFile reload")
    for value in [-1.0,.55,1.10,INF,NAN]:
        check(RENDER.save_custom_scale(value)==ERR_INVALID_PARAMETER,
            "invalid 3D scale accepted: "+str(value))
    check(absf(RENDER.read_custom_scale()-.75)<.001,
        "invalid request overwrote valid graphics settings")

    var budget: Node=RENDER.new()
    root.add_child(budget)
    check(str(budget.get("profile"))=="PERSONALIZADO" and
        absf(float(budget.get("current_scale"))-.75)<.001 and
        absf(root.scaling_3d_scale-.75)<.001,
        "live 3D viewport did not apply saved resolution")
    check(budget.call("select_custom_scale",.85)==OK and
        absf(root.scaling_3d_scale-.85)<.001,
        "manual slider cannot update the active 3D viewport")
    check(RENDER.save_profile("AUTO")==OK and
        absf(RENDER.read_custom_scale()-.85)<.001,
        "AUTO preset erased the independent custom scale")

    var preset: int=HUD_LAYOUT.selected_preset()
    var settings_script: GDScript=load(
        "res://scripts/ui/aurora_settings_overlay.gd") as GDScript
    check(settings_script!=null,
        "native settings overlay failed to load with project autoloads")
    if settings_script==null:
        budget.queue_free()
        quit(1)
        return
    var overlay: CanvasLayer=settings_script.new()
    root.add_child(overlay)
    overlay.call("_show_category","PANTALLA")
    var slider: HSlider=overlay.find_child(
        "AuroraCustom3DScale",true,false) as HSlider
    var choice: OptionButton=overlay.find_child(
        "AuroraRenderQuality",true,false) as OptionButton
    check(slider!=null and choice!=null,
        "custom render slider not present in the real settings screen")
    if slider!=null and choice!=null:
        check(slider.min_value==65.0 and slider.max_value==100.0 and
            slider.step==5.0,"slider ranges no longer safe for Mobile/Vulkan")
        slider.value=70.0
        slider.drag_ended.emit(true)
        check(absf(RENDER.read_custom_scale()-.70)<.001 and
            RENDER.read_profile()=="PERSONALIZADO",
            "slider release did not save user choice")
        check(choice.get_item_text(choice.selected)=="PERSONALIZADO",
            "quality menu does not reflect custom 3D mode")
    check(HUD_LAYOUT.selected_preset()==preset,
        "graphics menu unexpectedly modified persisted HUD selection")
    overlay.call("_close")
    await process_frame
    budget.queue_free()
    await process_frame
    check(absf(root.scaling_3d_scale-1.0)<.001,
        "3D viewport quality leaked into lobby after match exit")
    check(RENDER.save_profile("AUTO")==OK,
        "cannot restore automatic graphics profile")
    if not failed:
        print("V75174_RENDER_SCALE PASS custom_65_100=1 invalid_rejected=1 "+
            "active_viewport=1 settings_slider=1 persisted=1 HUD_untouched=1")
    quit(1 if failed else 0)
