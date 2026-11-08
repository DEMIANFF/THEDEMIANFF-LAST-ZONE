extends Node3D
## Native scene assembly. No block-built buildings or cubic player meshes.
const TERRAIN = preload("res://scripts/world/island_terrain.gd")
const OPERATOR = preload("res://scripts/player/third_person_operator.gd")
const DISTRICT = preload("res://scripts/world/aurora_district.gd")

var island: StaticBody3D
var operator: CharacterBody3D


func _ready() -> void:
    _set_up_lighting()
    island = TERRAIN.new()
    island.name = "AuroraTerrain"
    add_child(island)
    var district = DISTRICT.new()
    district.name = "PuertoAuroraSector"
    district.terrain = island
    add_child(district)

    var water := MeshInstance3D.new()
    water.name = "SeaSurface"
    var plane := PlaneMesh.new()
    plane.size = Vector2(910.0, 910.0)
    water.mesh = plane
    water.position.y = island.sea_level
    var sea_material := StandardMaterial3D.new()
    sea_material.albedo_color = Color(0.045, 0.25, 0.31, 0.84)
    sea_material.metallic = 0.11
    sea_material.roughness = 0.23
    sea_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sea_material.emission_enabled = true
    sea_material.emission = Color(0.01, 0.12, 0.15)
    sea_material.emission_energy_multiplier = 0.24
    water.material_override = sea_material
    add_child(water)

    operator = OPERATOR.new()
    operator.name = "Operator"
    add_child(operator)
    operator.global_position = Vector3(0.0, island.height_at(0.0, 0.0) + 1.2, 0.0)


func _set_up_lighting() -> void:
    var environment_node := WorldEnvironment.new()
    environment_node.name = "AuroraAtmosphere"
    var world_env := Environment.new()
    world_env.background_mode = Environment.BG_COLOR
    world_env.background_color = Color(0.53, 0.68, 0.78)
    world_env.ambient_light_energy = 0.75
    environment_node.environment = world_env
    add_child(environment_node)

    var sun := DirectionalLight3D.new()
    sun.name = "ArcticSun"
    sun.rotation = Vector3(-0.89, -0.42, 0.0)
    sun.light_energy = 1.05
    sun.shadow_enabled = false  # Enabled selectively after real-device benchmark.
    add_child(sun)
