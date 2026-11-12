extends SceneTree
## True performance plumbing, not a claim of measured FPS on Motorola.
## Tests generated surfaces, preserved collisions, GPU-budget settings,
## Android GL compatibility and in-game settings integration.
const RENDER=preload("res://scripts/render/aurora_render_budget.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(value: bool,why: String) -> void:
    if not value:
        failed=true
        push_error("V7545_RENDER_PIPELINE "+why)


func _verify() -> void:
    check(str(ProjectSettings.get_setting(
        "rendering/renderer/rendering_method"))=="gl_compatibility",
        "Motorola compatibility renderer must not silently switch to Vulkan")
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    var coastal: Node3D=game.get_node("PuertoAuroraCoastalQuarter")
    var old: Node3D=game.get_node("PuertoAuroraSector")
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var player: CharacterBody3D=game.get_node("Operator")
    var budget: Node=game.get_node("AuroraRenderBudget")

    check(coastal.get("buildings_built")==8,
        "renderer change removed actual furnished coastal residences")
    var saved: int=int(coastal.get("visual_draws_saved"))
    check(saved>=80,
        "static material batching did not meaningfully reduce calls")
    var total_batches: int=0
    var preserved_collision: int=0
    for building in coastal.get_children():
        if not str(building.name).begins_with("AuroraCoastalVilla"):
            continue
        var hidden_primitives: int=0
        for component in building.get_children():
            if component is MeshInstance3D:
                var visual:=component as MeshInstance3D
                if visual.name.begins_with("AuroraRenderBatch"):
                    check(visual.visible and visual.mesh is ArrayMesh and
                        visual.mesh.get_surface_count()==1 and
                        visual.material_override!=null,
                        "GPU batch must render real merged triangles using original material")
                    total_batches+=1
                elif not visual.visible:
                    hidden_primitives+=1
            if component is StaticBody3D and
                    str(component.name).contains("WalkableInteriorFloor"):
                preserved_collision+=1
        check(hidden_primitives>=8,
            "each house should consolidate repeated drawing primitives")
        check(building.get_node_or_null("WalkableRoofCollision")!=null,
            "roof collision missing after GPU mesh batching")
        check(building.get_node_or_null("InstancedCurvedTerracottaTiles")!=null,
            "original real roof tiles lost their efficient GPU instancing")
    check(total_batches>=16 and preserved_collision==8,
        "merged house geometry or unchanged collidable interior floors missing")
    for building in old.get_children():
        if str(building.name) in [
                "CENTRO_DE_EXPLORACION","TALLER_HELIOS",
                "ESTACION_METEOROLOGICA","PUESTO_VORTEX"]:
            check(building.get_node_or_null("AccessibleEntryRamp01")!=null,
                "legacy ramp collision deleted when optimizing scene")

    check(budget.get("profile") in RENDER.PROFILES and
        absf(float(budget.get("current_scale"))-.94)<.02,
        "default match should preserve legible high-resolution AUTO rendering")
    check(absf(RENDER.lower_step(.94)-.86)<.001 and
        absf(RENDER.lower_step(.86)-.78)<.001 and
        absf(RENDER.higher_step(.78)-.86)<.001 and
        absf(RENDER.higher_step(.94)-1.0)<.001,
        "adaptive up/down steps do not retain conservative quality bounds")
    check(RENDER.save_profile("TRUCO_INEXISTENTE")==ERR_INVALID_PARAMETER,
        "unsupported profile was accepted without validation")
    for item in [
        ["CLARIDAD",1.0],["EQUILIBRADO",.90],["FLUIDEZ",.78],["AUTO",.94]
    ]:
        var key: String=str(item[0])
        check(budget.call("select_profile",key)==OK,
            "cannot select game rendering mode "+key)
        check(RENDER.read_profile()==key and
            absf(float(budget.get("current_scale"))-float(item[1]))<.002,
            "persisted 3D quality does not match selected "+key)
    var root_viewport: Viewport=game.get_viewport()
    check(absf(root_viewport.scaling_3d_scale-.94)<.002 and
        root_viewport.scaling_3d_mode==Viewport.SCALING_3D_MODE_BILINEAR,
        "3D resolution scaling not applied to active rendering viewport")
    # The root HUD is an unscaled CanvasLayer, NOT a SubViewportTexture
    # attached to the governor: rifle controls stay at physical size.
    check(hud.get_parent()==game and player.get_view_camera()!=null,
        "render governor changed HUD ownership or camera pipeline")
    var camera: Camera3D=player.get_view_camera()
    check(camera.near>=.079 and camera.far>=630.0 and camera.far<=700.0,
        "camera depth precision and island coverage not preserved")
    var sea: MeshInstance3D=game.get_node("SeaSurface")
    var seawater: StandardMaterial3D=sea.material_override
    check(seawater.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and
        sea.mesh is PlaneMesh and sea.position.y==game.island.sea_level,
        "GPU performance regression: full island water became transparent")

    var settings: CanvasLayer=(
        load("res://scripts/ui/aurora_settings_overlay.gd") as GDScript).new()
    settings.context_game=game
    settings.context_origin="training"
    root.add_child(settings)
    settings._show_category("PANTALLA")
    var option:=settings.find_child("AuroraRenderQuality",true,false) as OptionButton
    check(option!=null and option.get_item_count()==4,
        "real screen settings missing 4 actual render modes")
    settings.queue_free()
    await process_frame
    # Keep the following exported/headless QA at reproducible AUTO default.
    check(RENDER.save_profile("AUTO")==OK,
        "QA cannot restore automatic quality")
    if not failed:
        print("V7545_RENDER_PIPELINE PASS villas=8 collision_roofs=8 "+
            "estimated_draws_saved="+str(saved)+
            " batched_surfaces="+str(total_batches)+
            " auto_scale=.94 renderer=GL HUD_native=1")
    quit(1 if failed else 0)
