extends SceneTree
const Compiler=preload("res://deathmatch/avatars/surface_compiler.gd")
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func mesh_with_surfaces(material: Material,eight: bool=false) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	for surface in 3:
		var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(surface,0,0),Vector3(surface,1,0),Vector3(surface,0,1)])
		arrays[Mesh.ARRAY_NORMAL]=PackedVector3Array([Vector3.RIGHT,Vector3.RIGHT,Vector3.RIGHT])
		arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2(0,1),Vector2(1,0)])
		arrays[Mesh.ARRAY_BONES]=PackedInt32Array([0,1,0,0,1,0,0,0,0,1,0,0])
		arrays[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array([.75,.25,0,0,1,0,0,0,.5,.5,0,0])
		if eight:
			var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
			for vertex in 3:
				bones.append_array(arrays[Mesh.ARRAY_BONES].slice(vertex*4,vertex*4+4));bones.append_array(PackedInt32Array([0,0,0,0]))
				weights.append_array(arrays[Mesh.ARRAY_WEIGHTS].slice(vertex*4,vertex*4+4));weights.append_array(PackedFloat32Array([0,0,0,0]))
			arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
		arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2]);mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if eight else 0);mesh.surface_set_material(surface,material)
	return mesh
func run():
	preload("res://deathmatch/avatars/visual_loader.gd").compile_surfaces=false
	var material:=StandardMaterial3D.new();var source:=mesh_with_surfaces(material);var merged:=Compiler.merge(source)
	check(merged.get_surface_count()==1,"Identical opaque materials combine into one surface")
	var arrays:=merged.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_INDEX]==PackedInt32Array(range(9)),"Indices are rebased to the appended vertices")
	for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_BONES,Mesh.ARRAY_WEIGHTS]:
		var expected=source.surface_get_arrays(0)[channel]
		for i in [1,2]:expected.append_array(source.surface_get_arrays(i)[channel])
		check(arrays[channel]==expected,"Vertex attribute preserved: "+str(channel))
	var eight:=Compiler.merge(mesh_with_surfaces(material,true))
	check(eight.get_surface_count()==1 and eight.surface_get_format(0)&Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS and eight.surface_get_arrays(0)[Mesh.ARRAY_BONES].size()==72,"Eight-influence skin format survives merging")
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	check(Compiler.merge(source)==source,"Transparent surfaces retain their order and geometry")
	material.transparency=BaseMaterial3D.TRANSPARENCY_DISABLED
	var root_node:=Node3D.new();var mesh:=MeshInstance3D.new();mesh.name="Body";mesh.mesh=source;root_node.add_child(mesh)
	mesh.set_surface_override_material(1,StandardMaterial3D.new());Compiler.compile(root_node)
	check(mesh.mesh==source,"Surface overrides exclude a mesh from compilation")
	mesh.set_surface_override_material(1,null)
	var player:=AnimationPlayer.new();root_node.add_child(player);var library:=AnimationLibrary.new();var clip:=Animation.new()
	var track:=clip.add_track(Animation.TYPE_VALUE);clip.track_set_path(track,NodePath("Body:surface_material_override/1:albedo_color"));clip.track_insert_key(track,0,Color.RED);library.add_animation("material",clip);player.add_animation_library("",library)
	Compiler.compile(root_node);check(mesh.mesh==source,"Material-animation targets retain surface indices")
	root_node.free()
	var models=preload("res://deathmatch/avatars/library.gd").new()
	for sample in ["sample_d","sample_f","sample_g","sakurada_fumiriya"]:
		models.entries[sample]={"path":"res://vrm/"+sample+".vrm"};var rig=models.create_avatar(sample)
		var meshes: Dictionary={}
		for node in rig.visual_meshes:meshes[node]=node.mesh
		var counts:=Compiler.compile(rig.model)
		check(counts.surfaces_after<counts.surfaces_before,"Real VRM surfaces reduced: "+sample)
		for node in meshes:
			var old: ArrayMesh=meshes[node];var next: ArrayMesh=node.mesh
			var vertices:=0;var indices:=0
			for i in old.get_surface_count():vertices+=old.surface_get_array_len(i);indices+=old.surface_get_array_index_len(i)
			for i in next.get_surface_count():vertices-=next.surface_get_array_len(i);indices-=next.surface_get_array_index_len(i)
			check(vertices==0 and indices==0,"Geometry counts preserved: "+sample+"/"+str(node.name))
			if old.get_blend_shape_count()>0:check(old==next,"Facial morph mesh remains byte-identical: "+sample)
		rig.free()
	preload("res://deathmatch/avatars/visual_loader.gd").compile_surfaces=true
	for sample in ["sample_d","AsiaCarrera-FemaleCommando-AsiaBots-experimental"]:
		models.scenes.clear();models.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
		var rig=models.create_avatar(sample)
		check(rig!=null and rig.model.has_meta("arena_surface_compile"),"Default compiler accepts VRM input: "+sample)
		if rig:rig.free()
	models.free();print("AVATAR_SURFACE_COMPILE_RESULT ",failures);quit(0 if failures.is_empty() else 1)
