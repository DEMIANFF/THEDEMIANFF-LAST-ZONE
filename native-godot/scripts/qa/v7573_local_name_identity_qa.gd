extends SceneTree
## V75.73: real editable nickname on device, no fabricated numeric cloud ID.
const LOCAL_NAME=preload("res://scripts/persistence/local_player_name.gd")
const QA_PATH="user://qa/v7573_player_name.cfg"
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V7573_PLAYER_NAME "+reason)

func _clean() -> void:
    for suffix in ["",".bak",".tmp"]:
        var target: String=ProjectSettings.globalize_path(QA_PATH+suffix)
        if FileAccess.file_exists(target):
            DirAccess.remove_absolute(target)

func _verify() -> void:
    var path: String=ProjectSettings.globalize_path(QA_PATH)
    check(DirAccess.make_dir_recursive_absolute(path.get_base_dir())==OK,
        "cannot isolate device nickname QA")
    _clean()

    var name_store=LOCAL_NAME.new(QA_PATH)
    check(name_store.display_name=="Operador",
        "uninitialized local player should not claim an official Firebase identity")
    for invalid in ["","AB"," Aiden","Aiden ","BAD@NAME","ADMIN",
            "FIREBASE","a".repeat(17),"a  b"]:
        check(not LOCAL_NAME.valid_name(invalid) and
            name_store.save_name(invalid)==ERR_INVALID_PARAMETER,
            "invalid/reserved nickname was accepted: "+invalid)
    check(LOCAL_NAME.valid_name("Lila Aurora") and
        LOCAL_NAME.valid_name("Ñandú_777"),
        "valid Latin-script player names were rejected")
    check(name_store.save_name("Lila Aurora")==OK,
        "player nickname did not save to device")
    check(LOCAL_NAME.new(QA_PATH).display_name=="Lila Aurora",
        "nickname did not survive reopening local save")
    check(name_store.save_name("Ñandú_777")==OK,
        "renaming on the same device failed")

    var boot: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(boot)
    boot._show_lobby()
    await process_frame
    boot._player_name=LOCAL_NAME.new(QA_PATH)
    boot._update_identity_strip(boot._offline_records.snapshot())
    boot._select_tab("CUENTA")
    check(boot._name_entry.is_visible_in_tree() and
        boot._name_save_button.is_visible_in_tree(),
        "real mobile nickname input or save button is missing")
    check(not boot._match_mode_selector.visible and
        not boot._battle_entry.visible,
        "battle controls overlap the player-name editor")
    check(boot._info.text.contains("NOMBRE: Ñandú_777") and
        boot._info.text.contains("ID OFICIAL: PENDIENTE DE FIREBASE"),
        "account screen claims a fake ID or hides real saved nickname")
    boot._name_entry.text="AURORA_2026"
    boot._save_player_name()
    check(LOCAL_NAME.new(QA_PATH).display_name=="AURORA_2026" and
        boot._stats_strip.text.contains("AURORA_2026") and
        boot._info.text.contains("NOMBRE: AURORA_2026"),
        "saving from lobby did not persist and refresh the real nickname")
    boot._name_entry.text="ADMIN"
    boot._save_player_name()
    check(LOCAL_NAME.new(QA_PATH).display_name=="AURORA_2026" and
        boot._info.text.contains("NOMBRE NO GUARDADO"),
        "invalid nickname overwrote a valid saved profile")
    boot._select_tab("PERSONAJE")
    check(not boot._name_entry.visible and
        not boot._name_save_button.visible and
        boot._battle_entry.visible,
        "returning from Account failed to restore local Classic")

    for resolution in [Vector2i(960,540),Vector2i(1280,720)]:
        root.size=resolution
        await process_frame
        await process_frame
        boot._layout_safe()
        boot._select_tab("CUENTA")
        check(root.get_visible_rect().encloses(
            boot._name_entry.get_global_rect()),
            "editable name is outside screen "+str(resolution))
        check(root.get_visible_rect().encloses(
            boot._name_save_button.get_global_rect()),
            "name-save control is outside screen "+str(resolution))
    boot.queue_free()
    await process_frame

    # Valid prior .bak must recover from accidental corruption of primary.
    var bad:=FileAccess.open(QA_PATH,FileAccess.WRITE)
    check(bad!=null,"cannot simulate damaged nickname profile")
    if bad!=null:
        bad.store_string("[player]\nschema=1\nname=\"INVALID!!\"\n")
        bad.close()
    var recovered=LOCAL_NAME.new(QA_PATH)
    check(recovered.recovered and recovered.display_name=="Ñandú_777",
        "corrupted latest nickname did not fall back to valid prior saved name")
    check(recovered.save_name("Operador_2")==OK and
        LOCAL_NAME.new(QA_PATH).display_name=="Operador_2",
        "recovered local identity could not be saved again")
    _clean()
    if not failed:
        print("V7573_PLAYER_NAME PASS editable=1 durable=1 reserved=rejected "+
            "recoverable=1 real_id=pending mobile=bounded")
    quit(1 if failed else 0)
