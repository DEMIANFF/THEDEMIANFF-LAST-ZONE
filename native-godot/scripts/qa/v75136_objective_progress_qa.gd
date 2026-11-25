extends SceneTree
## V75.136 verifies truthful mission/achievement bars in the actual Godot UI.
## No online quests, premium rewards, new entitlements or invented data.
const RECORDS=preload("res://scripts/persistence/offline_match_records.gd")
const QA_PATH="user://qa/v75136_visual_objectives.json"
var failed: bool=false


func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75136_OBJECTIVE_PROGRESS "+message)


func _clean() -> void:
    var parent: String=ProjectSettings.globalize_path(QA_PATH).get_base_dir()
    DirAccess.make_dir_recursive_absolute(parent)
    for suffix in ["",".bak",".tmp",".auto",".auto.tmp"]:
        var file: String=ProjectSettings.globalize_path(QA_PATH+suffix)
        if FileAccess.file_exists(file):
            DirAccess.remove_absolute(file)


func _initialize() -> void:
    call_deferred("_verify")


func _verify() -> void:
    _clean()
    var ledger=RECORDS.new(QA_PATH)
    check(ledger.record_result(1,true,2,120) and
        ledger.record_result(2,false,4,300),
        "could not create two genuine local journal results")
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    front._offline_records=RECORDS.new(QA_PATH)
    var baseline: Dictionary=front._offline_records.snapshot()
    front._select_tab("OBJETIVOS")
    var panel: VBoxContainer=front._objectives_progress_panel
    var rows: Array[Dictionary]=front._objectives_progress_rows
    check(panel!=null and panel.is_visible_in_tree() and rows.size()==3,
        "three progress rows not visible in original objectives section")
    if panel==null or rows.size()!=3:
        quit(1)
        return
    for i in range(3):
        var bar: ProgressBar=rows[i]["bar"] as ProgressBar
        var label: Label=rows[i]["label"] as Label
        var value: int=[2,5,1][i]
        var maximum: int=[3,5,1][i]
        var paint: StyleBoxFlat=bar.get_theme_stylebox("fill") as StyleBoxFlat
        var track: StyleBoxFlat=bar.get_theme_stylebox(
            "background") as StyleBoxFlat
        check(bar!=null and label!=null and
            int(bar.value)==value and int(bar.max_value)==maximum and
            label.text.contains("%d / %d"%[value,maximum]) and
            not bar.show_percentage,
            "mission progress differs from verified journal counts")
        check(bar.custom_minimum_size.y>=20.0 and
            label.get_theme_font_size("font_size")>=15 and
            paint!=null and track!=null and
            (paint.bg_color.r>.9 if value==maximum else
                paint.bg_color.g>.7),
            "phone-sized mission progress invisible or incorrect state color")
    front._objective_selector.current_tab=1
    front._on_objective_category_selected(1)
    check(panel.visible,"completed real achievements have no progress")
    for i in range(3):
        var bar: ProgressBar=rows[i]["bar"] as ProgressBar
        check(int(bar.value)==[1,1,6][i] and
            int(bar.max_value)==[1,1,10][i],
            "achievement bar does not represent actual 1/1/6 records")
    front._open_lobby_category("OBJETIVOS","events")
    check(not panel.visible and
        front._info.text.contains("SIN TEMPORADA ACTIVA"),
        "online events incorrectly receive invented local progress")
    front._open_lobby_category("OBJETIVOS","missions")
    await process_frame
    await process_frame
    front._layout_safe()
    check(root.get_visible_rect().encloses(panel.get_global_rect()) and
        panel.get_global_rect().size.y>=76 and
        front._lobby_detail_scroll.get_global_rect().end.y<=
            front._page.get_global_rect().end.y+4.0,
        "three mission bars overflow Motorola 964x434 lobby panel")
    for row in rows:
        var gauge: ProgressBar=row["bar"] as ProgressBar
        check(root.get_visible_rect().encloses(gauge.get_global_rect()) and
            gauge.get_global_rect().size.y>=10.0,
            "a local mission progress bar becomes a hairline on Motorola")
    front._select_tab("JUGAR")
    check(not panel.visible and front._battle_entry.visible,
        "objectives overlay classic local game launch")
    check(front._offline_records.snapshot()==baseline,
        "read-only progress display mutated coins, wins or real match journal")
    front._welcome()
    check(not panel.visible,
        "objective bars leak into account-selection screen")
    front.queue_free()
    await process_frame
    _clean()
    if not failed:
        print("V75136_OBJECTIVE_PROGRESS PASS mission=2_5_1 "+
            "achievements=1_1_6 events=disabled no_claims=1 "+
            "no_journal_mutation=1 viewport=964x434")
    quit(1 if failed else 0)
