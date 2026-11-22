extends SceneTree
## V75.162 quality gate for the actual original 675m playable world:
## material resources, real scene, 50-player runtime contract, native HUD,
## cheap GPU MultiMesh pine LOD and true Vulkan-vs-Compatibility flags.
const MICRO=preload("res://scripts/render/aurora_micro_surface.gd")
const RENDER=preload("res://scripts/render/aurora_render_budget.gd")
var failed: bool=false


func _initialize() -> void:
    call_deferred("_verify")


func check(ok: bool,why: String) -> void:
    if not ok:
        failed=true
        push_error("V75162_WORLD_QUALITY "+why)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var snow: Image=MICRO.normal_image(false)
    var water: Image=MICRO.normal_image(true)
    check(snow.get_size()==Vector2i(128,128) and
        water.get_size()==Vector2i(128,128) and
        snow.has_mipmaps() and water.has_mipmaps(),
        "real normal maps must be 128px and mipmapped for mobile")
    var snow_min: float=1.0
    var snow_max: float=0.0
    var sea_min: float=1.0
    var sea_max: float=0.0
    for y in range(0,128,7):
        for x in range(0,128,7):
            var a: float=snow.get_pixel(x,y).r
            var b: float=water.get_pixel(x,y).r
            snow_min=minf(snow_min,a)
            snow_max=maxf(snow_max,a)
            sea_min=minf(sea_min,b)
            sea_max=maxf(sea_max,b)
    check(snow_max-snow_min>.04 and sea_max-sea_min>.04,
        "repeatedly identical blank material would not improve terrain/water")
    # Synthetic presets are policy tests, not measured device performance.
    var low: Dictionary=RENDER.quality_flags("FLUIDEZ",.78,"mobile")
    var high: Dictionary=RENDER.quality_flags("CLARIDAD",1.0,"mobile")
    var auto_slow: Dictionary=RENDER.quality_flags("AUTO",.78,"mobile")
    var desktop: Dictionary=RENDER.quality_flags("CLARIDAD",1.0,"gl_compatibility")
    check(not low["msaa"] and not low["sun_shadow"] and
        not low["fog"] and not low["foliage"],
        "FLUIDEZ failed to disable heavy post FX/shadows and use cheap pine LOD")
    check(high["msaa"] and high["sun_shadow"] and high["fog"] and
        high["foliage"] and not high["fxaa"],
        "Vulkan CLARIDAD did not enable bounded 2x MSAA and 3D nature")
    check(not auto_slow["msaa"] and not auto_slow["foliage"] and
        not auto_slow["fog"] and
        not desktop["msaa"] and not desktop["sun_shadow"],
        "AUTO downscale or desktop Compatibility erroneously forces Mobile FX")

    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    await process_frame
    var terrain: StaticBody3D=game.get_node("AuroraTerrain")
    var island_surface: MeshInstance3D=terrain.get_node("ContinuousIslandSurface")
    var material: StandardMaterial3D=(
        island_surface.mesh.surface_get_material(0) as StandardMaterial3D)
    var sea: MeshInstance3D=game.get_node("SeaSurface")
    var sea_mat: StandardMaterial3D=sea.material_override as StandardMaterial3D
    var world_env: WorldEnvironment=game.get_node("AuroraAtmosphere")
    var sun: DirectionalLight3D=game.get_node("ArcticSun")
    var nature: Node3D=game.get_node("AuroraNature")
    var pines: MultiMeshInstance3D=nature.get_node("AuroraPineCrowns")
    var budget: Node=game.get_node("AuroraRenderBudget")
    var combat: Node3D=game.get_node("CombatRange")
    check(material!=null and material.normal_enabled and
        material.normal_texture!=null and
        material.normal_texture.get_size()==Vector2(128,128) and
        material.vertex_color_use_as_albedo,
        "terrain lost physical color blend or mipmapped snow/rock shading")
    check(sea_mat!=null and sea_mat.normal_enabled and
        sea_mat.normal_texture!=null and
        sea_mat.normal_texture.get_size()==Vector2(128,128) and
        sea_mat.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and
        sea_mat.uv1_scale.x>=40.0,
        "water waves became full-screen transparency/refraction or lack normals")
    check(sea.mesh is PlaneMesh and
        sea.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and
        is_equal_approx(sea.position.y,float(terrain.get("sea_level"))),
        "water shader modification broke opaque physical sea placement")
    check(world_env.environment!=null and
        world_env.environment.fog_density>0.0005 and
        world_env.environment.fog_density<.004 and
        sun.directional_shadow_max_distance<=70.0,
        "atmosphere missing or shadows exceed mobile light budget")
    var initial_instances: int=pines.multimesh.instance_count
    var initial_positions: int=(nature.get("pine_positions") as Array).size()
    check(initial_instances==initial_positions and initial_instances>100,
        "quality manager replaced real GPU forest positions with a prototype")

    var renderer_method: String=RenderingServer.get_current_rendering_method()
    check(budget.call("select_profile","FLUIDEZ")==OK and
        absf(float(budget.get("current_scale"))-.78)<.002 and
        not world_env.environment.fog_enabled and not sun.shadow_enabled and
        not bool(nature.get("detailed_foliage")) and
        pines.multimesh.mesh is CylinderMesh and
        pines.multimesh.instance_count==initial_instances,
        "FLUIDEZ did not make real terrain/nature cheaper without removing trees")
    check(budget.call("select_profile","CLARIDAD")==OK and
        absf(float(budget.get("current_scale"))-1.0)<.002 and
        world_env.environment.fog_enabled and
        bool(nature.get("detailed_foliage")) and
        pines.multimesh.mesh is ArrayMesh and
        pines.multimesh.instance_count==initial_instances and
        sun.shadow_enabled==(renderer_method=="mobile"),
        "CLARIDAD did not restore detail without changing real forest or backend")
    var high_mesh: ArrayMesh=pines.multimesh.mesh as ArrayMesh
    check(high_mesh!=null and high_mesh.get_surface_count()==1 and
        high_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>90,
        "three-tier original foliage did not produce one efficient detailed mesh")

    var screen: Viewport=game.get_viewport()
    check(screen.msaa_3d==(
        Viewport.MSAA_2X if renderer_method=="mobile" else
        Viewport.MSAA_DISABLED),
        "MSAA bypassed Mobile-only budget and forced Compatibility overhead")
    check(budget.call("select_profile","AUTO")==OK and
        pines.multimesh.instance_count==initial_instances and
        world_env.environment.fog_enabled and
        not sun.shadow_enabled and
        game.get_node_or_null("TrainingHUD")!=null and
        game.get_node_or_null("AuroraSectorMatch")!=null and
        combat!=null,
        "AUTO lost BR mission systems, HUD or forest while restoring quality")
    var report: Dictionary=budget.call("snapshot")
    for label in ["sun_shadows","depth_fog","pine_detail","antialiasing",
            "fps","target_fps","draw_calls","bottleneck"]:
        check(report.has(label),"render quality diagnostics missing "+label)
    check(RENDER.save_profile("AUTO")==OK,
        "quality preferences could not return to conservative AUTO")
    game.queue_free()
    await process_frame
    if not failed:
        print("V75162_WORLD_QUALITY PASS actual_675m_world=1 "+
            "terrain_water_normalmaps=128_mips opaque_sea=1 "+
            "multimesh_pines="+str(initial_instances)+
            " high_lod=3_layers low_lod=1_cone "+
            "adaptive_mobile_msaa=1 restricted_sun_shadows=1 "+
            "fog_depth=1 HUD_untouched=1 actual_device_FPS=NOT_MEASURED")
    quit(1 if failed else 0)
