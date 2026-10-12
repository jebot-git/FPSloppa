extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const IndexCache=preload("res://tools/meshoptimizer/index_cache.gd")
var checks:=0
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures.append(message);push_error(message)
func triangles(indices: PackedInt32Array) -> Dictionary:
	var counts: Dictionary={}
	for i in range(0,indices.size(),3):
		var key:=Vector3i(indices[i],indices[i+1],indices[i+2]);counts[key]=counts.get(key,0)+1
	return counts
func run() -> void:
	var library:=Library.new();root.add_child(library);var models: Array=[]
	var lod_service=preload("res://deathmatch/avatars/mesh_lod.gd").new();root.add_child(lod_service)
	for name in ["d","f","g"]:
		var path: String="res://test-results/meshoptimizer/sample_"+name+"-cache-only.vrm"
		var hash:=library.register_file(path,false);check(not hash.is_empty(),name+" optimized local VRM passes application validation")
		if hash.is_empty():continue
		var original_hash:=FileAccess.get_sha256("res://vrm/sample_"+name+".vrm")
		var original: Node3D=library.create_avatar(original_hash);var optimized: Node3D=library.create_avatar(original_hash)
		for instance in original.model.find_children("*","MeshInstance3D",true,false):lod_service.enqueue(instance.mesh)
		while lod_service.task>=0 or not lod_service.pending.is_empty():await process_frame
		var changes:=IndexCache.model(optimized.model)
		check(original!=null and optimized!=null,name+" imports and configures both humanoid rigs")
		if original==null or optimized==null:continue
		var before:=checks;var source=original.model.find_children("*","MeshInstance3D",true,false);var target=optimized.model.find_children("*","MeshInstance3D",true,false)
		check(source.size()==target.size(),name+" mesh node count")
		for i in source.size():
			var a: ArrayMesh=source[i].mesh;var b: ArrayMesh=target[i].mesh
			check(original.model.get_path_to(source[i])==optimized.model.get_path_to(target[i]),name+" mesh node paths "+str(original.model.get_path_to(source[i]))+" / "+str(optimized.model.get_path_to(target[i])))
			check(a.get_surface_count()==b.get_surface_count(),name+" surface count")
			check(a.get_blend_shape_count()==b.get_blend_shape_count(),name+" morph count")
			for shape in a.get_blend_shape_count():check(a.get_blend_shape_name(shape)==b.get_blend_shape_name(shape),name+" expression name")
			for surface in a.get_surface_count():
				var packed_a: Dictionary=a.get("_surfaces")[surface];var packed_b: Dictionary=b.get("_surfaces")[surface]
				for key in packed_a:
					if key!="index_data":check(packed_a[key]==packed_b[key],name+" encoded surface bytes "+str(key))
				var aa:=a.surface_get_arrays(surface);var bb:=b.surface_get_arrays(surface)
				check(triangles(aa[Mesh.ARRAY_INDEX])==triangles(bb[Mesh.ARRAY_INDEX]),name+" same oriented triangle multiset")
				if not IndexCache.Materials.safe_material(a.surface_get_material(surface)):check(aa[Mesh.ARRAY_INDEX]==bb[Mesh.ARRAY_INDEX],name+" transparent triangle order preserved")
				for channel in Mesh.ARRAY_MAX:
					if channel!=Mesh.ARRAY_INDEX:check(aa[channel]==bb[channel],name+" decoded non-index stream "+str(channel))
				check(a.surface_get_blend_shape_arrays(surface)==b.surface_get_blend_shape_arrays(surface),name+" decoded morph streams")
			var skin_a: Skin=source[i].skin;var skin_b: Skin=target[i].skin
			if skin_a!=null:
				check(skin_b!=null and skin_a.get_bind_count()==skin_b.get_bind_count(),name+" skin bind count")
				for bind in skin_a.get_bind_count():check(skin_a.get_bind_name(bind)==skin_b.get_bind_name(bind) and skin_a.get_bind_pose(bind)==skin_b.get_bind_pose(bind),name+" skin bind identity")
		models.append({"model":name,"checks":checks-before,"mesh_nodes":source.size(),"changes":changes});original.free();optimized.free()
	var result:={"checks":checks,"failures":failures,"models":models,"scope":"Index-only local VRMs pass application validation. Tested post-decode prototype uses built-in meshoptimizer via SurfaceTool; encoded/decoded non-index, morph, node-path and skin-bind equality. No shipped import path modified."}
	FileAccess.open("res://test-results/meshoptimizer/import-validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "));print("MESHOPT_IMPORT_VALIDATION ",JSON.stringify(result));lod_service.free();library.free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
