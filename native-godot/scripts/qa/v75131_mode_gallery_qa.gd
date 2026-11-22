extends SceneTree
## V75.131 regression updated for the actual, single RIGHT-HAND OptionButton
## instead of the removed center-left MODOS shortcut and modal gallery.
## Ranking remains gated; training and 50-participant classic remain real.
var failed: bool=false

func _initialize() -> void:
    call_deferred("_verify")

func check(ok: bool,message: String) -> void:
    if not ok:
        failed=true
        push_error("V75131_MODE_SELECTOR "+message)

func select_mode(front: Control,index: int) -> void:
    var right: OptionButton=front._match_mode_selector
    right.select(index)
    right.item_selected.emit(index)

func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._show_lobby()
    await process_frame
    front._layout_safe()
    var right: OptionButton=front._match_mode_selector
    check(right!=null and right.get_item_count()==3 and right.visible and
        right.selected==0 and front._selected_match_mode=="classic",
        "main Battle Royale card has no working Classic/Ranked/Training picker")
    check(front._mode_gallery_entry==null and
        front._mode_gallery_overlay==null and
        front.find_child("AuroraModeGalleryEntry",true,false)==null,
        "obsolete floating MODOS button or full-screen duplicate remains")
    check(right.get_global_rect().position.x>
        front._surface.global_position.x+front._surface.size.x*.68,
        "mode selector was moved out of the right-side Battle Royale card")
    select_mode(front,1)
    check(front._selected_match_mode=="ranked" and
        front._lobby_mode_status.text.contains("BLOQUEADA") and
        not front._battle_entry.visible and not front._training_entry.visible,
        "blocked ranked match was presented as an actual online game")
    front._launch(true)
    check(front.stage=="lobby" and front._game==null,
        "ranked mode bypassed server-authoritative matchmaking gate")
    select_mode(front,2)
    check(front._selected_match_mode=="training" and
        front._training_entry.visible and not front._battle_entry.visible,
        "real local training lost the only right-side mode control")
    select_mode(front,0)
    check(front._selected_match_mode=="classic" and
        front._battle_entry.visible and not front._training_entry.visible and
        front._lobby_mode_status.text.contains("50 PARTICIPANTES"),
        "right-hand selector failed to restore Classic with 49 AI")
    front._select_tab("INVENTARIO")
    check(not right.visible and front._equipment_selector.visible,
        "right-hand BR picker leaked into inventory screen")
    front._select_tab("JUGAR")
    check(right.visible and front._selected_match_mode=="classic",
        "Battle Royale selector not restored on return to play screen")
    front._welcome()
    # _welcome() detaches and queues the old right-side OptionButton.
    # A queued Control can retain visible=true until frame teardown;
    # is_visible_in_tree() is the correct end-user visibility assertion.
    check((not is_instance_valid(right) or not right.is_visible_in_tree()) and
        front._mode_gallery_entry==null,
        "mode selector/duplicate control leaks into login screen")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75131_MODE_SELECTOR PASS 964x434 right_side_only=1 "+
            "classic50=1 training_local=1 ranked_server_gated=1 "+
            "no_floating_modos=1 inventory_no_mode=1")
    quit(1 if failed else 0)
