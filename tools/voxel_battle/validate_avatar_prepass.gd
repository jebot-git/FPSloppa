extends SceneTree
const Library=preload("res://deathmatch/avatars/library.gd")
const IndexCache=preload("res://tools/meshoptimizer/index_cache.gd")
var errors: Array=[]
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:errors.append(label);push_error(label)
func triangles(indices: PackedInt32Array) -> Dictionary:
	var counts: Dictionary={}
	for i in range(0,indices.size(),3):
		var key:=Vector3i(indices[i],indices[i+1],indices[i+2]);counts[key]=int(counts.get(key,0))+1
	return counts
func run() -> void:
	var library:=Library.new();root.add_child(library)
	var rows: Array=[]
	for name in ["d","f","g"]:
		var path: String="res://vrm/sample_"+name+".vrm";var hash:=FileAccess.get_sha256(path)
		check(library.visual_loader.prepare_avatar(library,hash,true),"VRM loads "+name)
		var model=library.scenes[hash].instantiate()
		var originals: Array=[]
		for instance in model.find_children("*","MeshInstance3D",true,false):originals.append(instance.mesh)
		var changes:=IndexCache.model(model);rows.append(changes)
		check(changes.changed_instances>0,"prepass optimizes "+name)
		var index:=0
		for instance in model.find_children("*","MeshInstance3D",true,false):
			var a: ArrayMesh=originals[index];var b: ArrayMesh=instance.mesh;index+=1
			check(a.get_surface_count()==b.get_surface_count(),"material surfaces preserved")
			check(a.get_blend_shape_count()==b.get_blend_shape_count(),"morph count preserved")
			for shape in a.get_blend_shape_count():check(a.get_blend_shape_name(shape)==b.get_blend_shape_name(shape),"morph names preserved")
			for surface in a.get_surface_count():
				var sa: Dictionary=a.get("_surfaces")[surface];var sb: Dictionary=b.get("_surfaces")[surface]
				for key in sa:
					if key!="index_data":check(sa[key]==sb[key],"skin/vertex/morph/LOD encoded data preserved "+str(key))
				check(triangles(a.surface_get_arrays(surface)[Mesh.ARRAY_INDEX])==triangles(b.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]),"oriented triangles preserved")
				check(a.surface_get_material(surface)==b.surface_get_material(surface),"material identity preserved")
				if not IndexCache.Materials.safe_material(a.surface_get_material(surface)):check(sa.index_data==sb.index_data,"transparent draw order preserved")
		check(FileAccess.get_sha256(path)==hash,"original VRM file untouched")
		model.free()
	var report:={"checks":checks,"errors":errors,"models":rows}
	DirAccess.make_dir_recursive_absolute("res://test-results/voxel-battle")
	FileAccess.open("res://test-results/voxel-battle/avatar-prepass.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AVATAR_PREPASS_VALIDATION ",JSON.stringify(report));library.free();await process_frame;await process_frame;quit(0 if errors.is_empty() else 1)
