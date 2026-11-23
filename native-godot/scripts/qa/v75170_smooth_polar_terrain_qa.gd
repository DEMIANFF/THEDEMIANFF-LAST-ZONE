extends SceneTree
## V75.170 — smooth mountain and plowed-snow geometry in the actual
## Boot.tscn lobby. Tests spatial normals and index sharing (a visual QA
## gap in earlier passes). No external art, new meshes or extra lights.
var failed: bool=false


func check(ok: bool,reason: String) -> void:
    if not ok:
        failed=true
        push_error("V75170_SMOOTH_TERRAIN "+reason)


func _initialize() -> void:
    call_deferred("_verify")


func _verify_mesh(mesh_instance: MeshInstance3D,tag: String) -> void:
    check(mesh_instance!=null,"physical polar terrain mesh absent: "+tag)
    if mesh_instance==null:
        return
    var surface: ArrayMesh=mesh_instance.mesh as ArrayMesh
    check(surface!=null and surface.get_surface_count()==1,
        "one indexed ArrayMesh surface required for "+tag)
    if surface==null or surface.get_surface_count()!=1:
        return
    var arrays: Array=surface.surface_get_arrays(0)
    var positions: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
    var normals: PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
    var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
    check(indices.size()>0 and positions.size()>0 and
        positions.size()==normals.size(),
        "indexed normal geometry missing for "+tag)
    # Adjacent faces MUST reuse vertices before generating normals. A
    # flat-shaded triangle mesh can pass count-only render QA while its
    # hard face boundaries make snowy peaks look like low-poly wedges.
    check(positions.size()*2<indices.size(),
        "terrain still has flat-shaded duplicated face vertices: "+tag+
        " vertices="+str(positions.size())+
        " indices="+str(indices.size()))
    check(indices.size()<=16000,
        "unexpected polygon increase on budgeted phone terrain "+tag)
    for index in range(0,normals.size(),maxi(1,normals.size()/25)):
        var n: Vector3=normals[index]
        check(n.is_finite() and n.length_squared()>.70 and
            n.length_squared()<1.30,
            "non-unit/invalid smoothed terrain normal "+tag)
    check(mesh_instance.cast_shadow==
        GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
        "mountain/shoulder shader must not cast mobile-expensive shadows")
    check(mesh_instance.material_override is ShaderMaterial,
        "procedural PBR terrain shader was replaced: "+tag)


func _verify() -> void:
    root.size=Vector2i(964,434)
    var front: Control=(load("res://scenes/Boot.tscn") as PackedScene).instantiate()
    root.add_child(front)
    await front.wait_for_startup()
    front._enter_local_lobby()
    await process_frame
    front._layout_safe()
    var stage: Node3D=front._preview_container.get_node(
        "PreviewViewport/AuroraCharacterStage/AuroraReal3DLobbyEnvironment")
    for title in ["AuroraSnowPeak","AuroraSnowPeakMiddle",
            "AuroraSnowPeakHorizon"]:
        _verify_mesh(stage.get_node_or_null(title) as MeshInstance3D,title)
    # Side-specific stable names also let QA verify geometry and handedness.
    var snowbanks: Array=[]
    for side_name in ["PlowedSnowbankLeft","PlowedSnowbankRight"]:
        var bank: MeshInstance3D=stage.get_node_or_null(side_name) as MeshInstance3D
        check(bank!=null,"real physical runway shoulder missing: "+side_name)
        if bank!=null:
            snowbanks.append(bank)
    check(snowbanks.size()==2,"both independently named runway shoulders required")
    for i in range(snowbanks.size()):
        _verify_mesh(snowbanks[i] as MeshInstance3D,
            "PlowedSnowbank"+str(i))
    var existing_batches: Array=stage.find_children(
        "*","MultiMeshInstance3D",true,false)
    check(existing_batches.size()<=12,
        "smoothing must not allocate additional mobile GPU batches")
    var marks: Dictionary=stage._runway_batch_audit
    check(int(marks.get("edge_count",-1))==44 and
        int(marks.get("center_count",-1))==7,
        "existing real runway markings must remain unchanged")
    check(front._preview_avatar!=null and
        front._preview_avatar.find_child(
            "Lila_Aurora_Mesh",true,false)!=null and
        front._bottom_navigation.get_child_count()==5 and
        front._mode_gallery_entry==null,
        "improving snowy horizon damaged skinned Lila or mobile UI")
    front._welcome()
    await process_frame
    check(front._preview_container==null,
        "3D terrain memory must be released on returning to login")
    front.queue_free()
    await process_frame
    if not failed:
        print("V75170_SMOOTH_TERRAIN PASS mountains=3 snowbanks=2 "+
            "shared_vertices=1 smooth_normals=1 extra_batches=0 "+
            "runway_marks=51 Lila=GLB footer=5 VRAM_released=1")
    quit(1 if failed else 0)
