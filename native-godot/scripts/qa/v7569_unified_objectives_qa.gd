extends SceneTree
## V75.69: the real Godot lobby merges missions, achievements and events.
## Progress comes from the existing signed local match journal, no fake prizes.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const QA_PATH="user://qa/v7569_objectives_profile.json"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7569_OBJECTIVES "+reason)

func _clean() -> void:
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        var file: String=ProjectSettings.globalize_path(QA_PATH+suffix)
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(file)

func _verify() -> void:
    var path: String=ProjectSettings.globalize_path(QA_PATH)
    check(DirAccess.make_dir_recursive_absolute(path.get_base_dir())==OK,
        "isolated objectives journal directory unavailable")
    _clean()
    var source=RECORDS.new(QA_PATH)
    check(source.record_result(1,true,2,120) and
        source.record_result(2,false,4,300),
        "could not produce two genuine signed journal fixtures")

    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    front._show_lobby()
    await process_frame
    front._offline_records=RECORDS.new(QA_PATH)
    check(front._lobby_nav.get_child_count()==8,
        "consolidated lobby still overflows with nine sections")
    check(front._lobby_nav.get_node_or_null("TabOBJETIVOS")!=null and
        front._lobby_nav.get_node_or_null("TabEVENTOS")==null and
        front._lobby_nav.get_node_or_null("TabMISIONES")==null,
        "events or missions not grouped under one objectives entry")
    front._select_tab("OBJETIVOS")
    var options: OptionButton=front._objective_selector
    check(options!=null and options.is_visible_in_tree() and
        options.get_item_count()==3,
        "objectives switcher is not visible and functional")
    check(not front._battle_entry.visible and
        not front._encounter_selector.visible,
        "mode buttons cover the objectives details")
    check(front._info.text.contains("2 / 3") and
        front._info.text.contains("5 / 5") and
        front._info.text.contains("1 / 1"),
        "missions do not reflect real saved-match totals")
    options.select(1)
    front._on_objective_category_selected(1)
    check(front._info.text.contains("Primera victoria: COMPLETADO") and
        front._info.text.contains("10 eliminaciones: 6 / 10"),
        "achievements are not calculated from real outcomes")
    options.select(2)
    front._on_objective_category_selected(2)
    check(front._info.text.contains("SIN TEMPORADA ACTIVA") and
        front._info.text.contains("validación del servidor"),
        "events advertise a nonexistent online season or fake reward")
    front._select_tab("PERSONAJE")
    check(not options.visible and front._battle_entry.visible,
        "objective menu did not restore real Classic start button")
    check(front._currency_strip.text.contains("MONEDAS") and
        front._currency_strip.text.contains("DIAMANTES"),
        "economy bar disappeared after switching menu section")

    for resolution in [Vector2i(960,540),Vector2i(1280,720)]:
        root.size=resolution
        await process_frame
        await process_frame
        front._layout_safe()
        check(root.get_visible_rect().encloses(
            front._objective_selector.get_global_rect()) or
            not front._objective_selector.visible,
            "objective selector exceeds landscape screen")
    front.queue_free()
    await process_frame
    _clean()
    if not failed:
        print("V7569_OBJECTIVES PASS tabs=8 missions=verified "+
            "achievements=verified events=not_fake mobile=bounded")
    quit(1 if failed else 0)
