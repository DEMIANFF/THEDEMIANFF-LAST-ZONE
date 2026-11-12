extends RefCounted
## Combines stationary decorative primitives into ONE draw surface per material
## per building. Keeps every collision body and authored transform unchanged.
## Built once during world assembly, never invoked during physics frames.
## Restrict to direct-child MeshInstance3D primitives: roof ArrayMesh,
## animated meshes, MultiMesh roofs, labels, hitboxes and loot are untouched.

static func merge_building(root: Node3D,minimum: int=3) -> Dictionary:
    var materials: Dictionary={}
    for child in root.get_children():
        var part: MeshInstance3D=child as MeshInstance3D
        if part==null or not part.visible or part.mesh==null:
            continue
        var primitive: Mesh=part.mesh
        if not (primitive is BoxMesh or primitive is CylinderMesh
                or primitive is SphereMesh):
            continue
        if primitive.get_surface_count()!=1 or part.material_override==null:
            continue
        var key: int=part.material_override.get_instance_id()
        if not materials.has(key):
            materials[key]={"material":part.material_override,"items":[]}
        var entries: Array=materials[key]["items"]
        entries.append(part)

    var batched_parts: int=0
    var new_surfaces: int=0
    var groups: Array=materials.values()
    for group in groups:
        var parts: Array=group["items"]
        if parts.size()<minimum:
            continue
        var builder:=SurfaceTool.new()
        builder.begin(Mesh.PRIMITIVE_TRIANGLES)
        for mesh_item in parts:
            var source: MeshInstance3D=mesh_item
            builder.append_from(source.mesh,0,source.transform)
        var combined: ArrayMesh=builder.commit()
        if combined==null or combined.get_surface_count()==0:
            continue
        var output:=MeshInstance3D.new()
        output.name="AuroraRenderBatch"+str(new_surfaces+1)
        output.mesh=combined
        output.material_override=group["material"]
        output.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(output)
        # Keep authored nodes for QA/editor inspection. Disable their
        # individual 3D draws, NOT the collision bodies or navigation.
        for mesh_item in parts:
            var original: MeshInstance3D=mesh_item
            original.visible=false
        batched_parts+=parts.size()
        new_surfaces+=1
    return {
        "batched_originals":batched_parts,
        "combined_surfaces":new_surfaces,
        "estimated_draws_saved":batched_parts-new_surfaces
    }
