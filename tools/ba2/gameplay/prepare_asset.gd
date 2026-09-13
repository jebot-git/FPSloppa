extends SceneTree
func _initialize():call_deferred("run")
func part(arrays: Array,indices: PackedInt32Array,material: Material) -> ArrayMesh:
	var selected:=arrays.duplicate();selected[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,selected);mesh.surface_set_material(0,material)
	return mesh
func run():
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	var err:=doc.append_from_file("res://tools/ba2/animated/BA2-10m-walk.glb",state)
	if err!=OK:push_error("BA2 asset import failed");quit(1);return
	var model:=doc.generate_scene(state)
	var skeleton: Skeleton3D=model.find_children("*","Skeleton3D",true,false)[0]
	var source: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false)[0]
	var arrays: Array=source.mesh.surface_get_arrays(0)
	var hidden_binds: Array=[]
	for bind in source.skin.get_bind_count():
		var name: String=source.skin.get_bind_name(bind)
		if name.is_empty():name=skeleton.get_bone_name(source.skin.get_bind_bone(bind))
		if name in ["Body","Eye"]:hidden_binds.append(bind)
	if hidden_binds.size()!=2:push_error("Missing rigid hull bindings");model.free();quit(1);return
	var shell_indices:=PackedInt32Array();var other_indices:=PackedInt32Array()
	var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	var stride: int=joints.size()/arrays[Mesh.ARRAY_VERTEX].size()
	for face in range(0,indices.size(),3):
		var shell:=false
		for offset in stride:
			var index: int=indices[face]*stride+offset
			if weights[index]>.5 and joints[index] in hidden_binds:shell=true
		for offset in 3:
			if shell:shell_indices.append(indices[face+offset])
			else:other_indices.append(indices[face+offset])
	var material: Material=source.get_active_material(0)
	var hull:=MeshInstance3D.new();hull.name="PilotShell";hull.transform=source.transform;hull.skin=source.skin;hull.skeleton=source.skeleton
	hull.mesh=part(arrays,shell_indices,material);source.mesh=part(arrays,other_indices,material)
	source.get_parent().add_child(hull);hull.owner=model
	var packed:=PackedScene.new();packed.pack(model)
	err=ResourceSaver.save(packed,"res://deathmatch/vehicles/ba2/model.scn",ResourceSaver.FLAG_BUNDLE_RESOURCES)
	print("BA2_RUNTIME_ASSET ",err," shell_triangles=",shell_indices.size()/3," other_triangles=",other_indices.size()/3)
	model.free();quit(0 if err==OK else 1)
