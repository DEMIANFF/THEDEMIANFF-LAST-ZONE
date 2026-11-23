extends SceneTree
## V75.176 full local BR inventory integration with actual acquired loot.
## Uses the project's real Main/Combat/HUD; no fake online economy/players.
const HUD=preload("res://scripts/ui/native_hud.gd")
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75176_VISUAL_INVENTORY "+message)

func _verify() -> void:
    root.size=Vector2i(964,434)
    var game: Node3D=(load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(game)
    var hud: CanvasLayer=game.get_node("TrainingHUD")
    var combat: Node3D=game.get_node("CombatRange")
    var operator: CharacterBody3D=game.get_node("Operator")
    operator.set_physics_process(false)
    combat.set_process(false)
    for rival: CharacterBody3D in combat._targets:
        rival.set_physics_process(false)
    check(hud._inventory_tiles.size()==6 and hud._inventory_close!=null and
        hud._inventory_scroll!=null and hud._inventory_medkit!=null,
        "equipment grid, scroll, close or medical action missing")
    var base: Dictionary=combat.inventory_snapshot()
    check(HUD.inventory_tile_text("backpack",base).contains("SIN EQUIPAR"),
        "fresh round received a phantom backpack")
    check(HUD.inventory_tile_text("awm",base).contains("SIN RECOGER"),
        "uncollected AWM incorrectly shown as owned")
    combat.sector_battle_active=true
    check(combat.collect_sector_loot("backpack_2"),
        "actual physical tier-2 backpack pickup failed")
    check(combat.collect_sector_loot("medkit"),
        "real medkit pickup failed")
    check(combat.collect_sector_loot("grenade"),
        "real grenade pickup failed")
    var inventory: Dictionary=combat.inventory_snapshot()
    check(int(inventory["backpack"])==2 and
        hud._inventory_tiles["backpack"].text.contains("NIVEL 2") and
        hud._inventory_button.text=="MOCHILA N2",
        "UI not bound to real upgraded backpack tier")
    check(hud._inventory_tiles["supplies"].text.contains(
        "BOTIQUINES %d"%int(inventory["medkits"])) and
        hud._inventory_tiles["tactical"].text.contains(
        "GRANADAS %d"%int(inventory["grenades"])),
        "displayed supplies are invented rather than from CombatRange")
    check(hud._inventory_metrics.text.contains(
        "BOTÍN %d"%int(inventory["loot_collected"])),
        "loot statistics missing confirmed world pickups")
    check(hud._inventory_ar.disabled and hud._inventory_ar.text.contains("EN MANOS"),
        "active AR cannot be identified in live inventory")
    check(hud._inventory_awm.disabled,
        "uncollected sniper must not be usable in the backpack")
    check(hud._inventory_medkit.visible and hud._inventory_grenade.visible,
        "physically collected medical and grenade actions not available")
    hud.set_air_stage("ground")
    hud.set_match_controls(true)
    hud._toggle_inventory()
    await process_frame
    var panel: Control=hud._inventory_panel
    var screen: Rect2=root.get_visible_rect()
    check(panel.visible and screen.grow(1.0).encloses(panel.get_global_rect()),
        "inventory drawer clipped at Motorola 964x434")
    check(hud._inventory_close.get_global_rect().size.y>=39.0,
        "inventory close touch target too small")
    var calls: Array[int]=[0]
    hud.heal_pressed.connect(func(): calls[0]+=1)
    hud._inventory_medkit.pressed.emit()
    check(calls[0]==1 and not panel.visible,
        "medkit action not wired to actual combat heal signal")
    hud._toggle_inventory()
    hud._inventory_close.pressed.emit()
    check(not panel.visible,"close button leaves inventory blocking combat")
    hud._toggle_inventory()
    hud.set_air_stage("aircraft")
    check(not panel.visible,
        "inventory was not closed before aircraft/freefall")
    root.size=Vector2i(1280,720)
    await process_frame
    hud._layout()
    hud.set_air_stage("ground")
    hud.set_match_controls(true)
    hud._toggle_inventory()
    await process_frame
    screen=root.get_visible_rect()
    check(panel.visible and screen.grow(1.0).encloses(panel.get_global_rect()),
        "inventory drawer clipped at 1280x720")
    hud._inventory_close.pressed.emit()
    combat.sector_battle_active=false
    game.queue_free()
    await process_frame
    if not failed:
        print("V75176_VISUAL_INVENTORY PASS real_backpack=2 real_medkit=1 "+
            "real_grenade=1 active_weapon=1 six_tiles=1 scroll=1 "+
            "touch=1 close=1 964x434=1 1280x720=1")
    quit(1 if failed else 0)
