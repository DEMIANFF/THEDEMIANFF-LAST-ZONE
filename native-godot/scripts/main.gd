extends Node3D
## Native scene assembly. No block-built buildings or cubic player meshes.
const TERRAIN = preload("res://scripts/world/island_terrain.gd")
const OPERATOR = preload("res://scripts/player/third_person_operator.gd")
const DISTRICT = preload("res://scripts/world/aurora_district.gd")
const HUD = preload("res://scripts/ui/native_hud.gd")
const COMBAT = preload("res://scripts/combat/training_combat.gd")
const SECTOR_MATCH = preload("res://scripts/match/sector_director.gd")
const NAVIGATION = preload("res://scripts/ai/aurora_navigation.gd")
const NATURE = preload("res://scripts/world/aurora_nature.gd")
const COASTAL_QUARTER=preload("res://scripts/world/aurora_coastal_quarter.gd")
const AURORA_AUDIO=preload("res://scripts/audio/aurora_audio.gd")
const TRACE=preload("res://scripts/match/flight_diagnostics.gd")
const STARTUP_DIAG=preload("res://scripts/persistence/scene_startup_diagnostics.gd")
const RENDER_BUDGET=preload("res://scripts/render/aurora_render_budget.gd")

var island: StaticBody3D
var operator: CharacterBody3D


func _ready() -> void:
    var render_budget:=RENDER_BUDGET.new()
    render_budget.name="AuroraRenderBudget"
    add_child(render_budget)
    TRACE.checkpoint("active","scene_load",null,"main_ready_enter",
        "startup="+str(STARTUP_DIAG.mode()))
    _set_up_lighting()
    TRACE.checkpoint("active","scene_load",null,"terrain_build_begin")
    island = TERRAIN.new()
    island.name = "AuroraTerrain"
    add_child(island)
    island.collision_layer=3 # World collision and walkable support.
    TRACE.checkpoint("active","scene_load",null,"terrain_build_done")
    TRACE.checkpoint("active","scene_load",null,"district_build_begin")
    var district = DISTRICT.new()
    district.name = "PuertoAuroraSector"
    district.terrain = island
    add_child(district)
    TRACE.checkpoint("active","scene_load",null,"district_build_done")
    if not STARTUP_DIAG.without_decorations():
        TRACE.checkpoint("active","scene_load",null,"coastal_build_begin")
        var town: Node3D=COASTAL_QUARTER.new()
        town.name="PuertoAuroraCoastalQuarter"
        town.terrain=island
        add_child(town)
        district.navigation_points.append_array(town.navigation_points)
        district.cover_points.append_array(town.cover_points)
        TRACE.checkpoint("active","scene_load",null,"coastal_build_done")
        var nature: Node3D=NATURE.new()
        nature.name="AuroraNature"
        nature.terrain=island
        add_child(nature)
        TRACE.checkpoint("active","scene_load",null,"nature_build_done")
    else:
        TRACE.checkpoint("active","scene_load",null,"decorations_skipped_diagnostic")

    var water := MeshInstance3D.new()
    water.name = "SeaSurface"
    var plane := PlaneMesh.new()
    plane.size = Vector2(910.0, 910.0)
    water.mesh = plane
    water.position.y = island.sea_level
    var sea_material := StandardMaterial3D.new()
    sea_material.albedo_color = Color(0.045, 0.25, 0.31)
    sea_material.metallic = 0.11
    sea_material.roughness = 0.23
    sea_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
    # Opaque water writes depth and avoids 910x910m alpha overdraw on Mali.
    sea_material.emission_enabled = true
    sea_material.emission = Color(0.01, 0.12, 0.15)
    sea_material.emission_energy_multiplier = 0.24
    water.material_override = sea_material
    water.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(water)

    TRACE.checkpoint("active","scene_load",null,"operator_build_begin")
    operator = OPERATOR.new()
    operator.name = "Operator"
    add_child(operator)
    TRACE.checkpoint("active","scene_load",operator,"operator_build_done")
    operator.global_position = Vector3(0.0, island.height_at(0.0, 0.0) + 1.2, 0.0)
    operator.respawn_point=operator.global_position

    var hud = HUD.new()
    hud.name = "TrainingHUD"
    add_child(hud)
    TRACE.checkpoint("active","scene_load",operator,"hud_build_done")
    operator.training_health_changed.connect(hud.set_health)
    operator.player_damaged.connect(hud.show_damage_feedback)
    hud.run_pressed.connect(func(): operator.set_touch_run(true))
    hud.run_released.connect(func(): operator.set_touch_run(false))
    hud.jump_pressed.connect(operator.touch_jump)
    hud.crouch_pressed.connect(func(): operator.set_crouch(not operator._crouching))
    operator.crouch_state_changed.connect(hud.set_crouch_state)
    hud.movement_axis_changed.connect(operator.set_touch_move_axis)
    hud.set_health(operator.training_health)
    var sound: Node=AURORA_AUDIO.new()
    sound.name="AuroraSoundStage"
    add_child(sound)
    TRACE.checkpoint("active","scene_load",operator,"audio_build_done")
    operator.footstep.connect(sound.play_footstep)
    operator.jumped.connect(func(): sound.play_event("jump"))
    operator.grounded_impact.connect(func(on_stone: bool): sound.play_footstep(on_stone))
    operator.player_damaged.connect(func(_amount: float): sound.play_event("hit"))

    TRACE.checkpoint("active","scene_load",operator,"combat_build_begin",
        "bot_visuals="+str(not STARTUP_DIAG.without_enemy_rigs()))
    var combat = COMBAT.new()
    combat.name = "CombatRange"
    combat.operator = operator
    combat.terrain = island
    combat.hud = hud
    add_child(combat)
    TRACE.checkpoint("active","scene_load",operator,"combat_build_done",
        "targets="+str(combat._targets.size()))
    var navigation: Node3D=NAVIGATION.new()
    navigation.name="AuroraNavigation"
    navigation.terrain=island
    navigation.district=district
    navigation.actors.append(operator)
    navigation.actors.append_array(combat._targets)
    add_child(navigation)
    TRACE.checkpoint("active","scene_load",operator,"navigation_ready")
    combat.navigation=navigation
    combat.shot_fired.connect(func(weapon: int,_hit: bool): sound.play_event("awm_fire" if weapon==1 else "ar_fire",.96+randf()*.08))
    combat.impact_occurred.connect(func(): sound.play_event("impact"))
    combat.bot_shot.connect(sound.play_world_shot)
    combat.reload_started.connect(func(): sound.play_event("reload"))
    combat.healed.connect(func(): sound.play_event("heal"))
    for bot in combat._targets:
        bot.navigation=navigation
    hud.set_training_radar_sources(operator,combat._targets)
    var match_director: Node3D=SECTOR_MATCH.new()
    match_director.name="AuroraSectorMatch"
    match_director.player=operator
    match_director.combat=combat
    match_director.terrain=island
    match_director.hud=hud
    add_child(match_director)
    hud.set_tactical_map_sources(operator,island,match_director)
    TRACE.checkpoint("active","scene_load",operator,"main_scene_ready")


func _set_up_lighting() -> void:
    var environment_node := WorldEnvironment.new()
    environment_node.name = "AuroraAtmosphere"
    var world_env := Environment.new()
    # Aurora sky gradient: actual Godot procedural atmospheric material,
    # independent from copyrighted/static game art references.
    var sky:=Sky.new()
    var sky_gradient:=ProceduralSkyMaterial.new()
    sky_gradient.sky_top_color=Color(.055,.13,.26)
    sky_gradient.sky_horizon_color=Color(.44,.65,.78)
    sky_gradient.ground_bottom_color=Color(.11,.23,.30)
    sky_gradient.ground_horizon_color=Color(.47,.69,.76)
    sky_gradient.use_debanding=true
    sky.sky_material=sky_gradient
    world_env.background_mode=Environment.BG_SKY
    world_env.sky=sky
    world_env.ambient_light_energy = 0.82
    environment_node.environment = world_env
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.name = "ArcticSun"
    sun.rotation = Vector3(-0.89, -0.42, 0.0)
    sun.light_color=Color(.92,.97,1.0)
    sun.light_energy = 1.25
    sun.shadow_enabled = false  # Enabled selectively after real-device benchmark.
    add_child(sun)
