extends SceneTree
const OUT="res://test-results/weapon-shared-reduction/"
func _initialize():run.call_deferred()
func tris(mesh: Mesh) -> int:
	var count:=0
	for i in mesh.get_surface_count():
		var n=mesh.surface_get_array_index_len(i)
		count+=(n if n>0 else mesh.surface_get_array_len(i))/3
	return count
func total(model:Node) -> int:
	var count:=0
	for m in model.find_children("*","MeshInstance3D",true,false):count+=tris(m.mesh)
	return count
func run():
	var report:=[]
	var rows=JSON.parse_string(FileAccess.get_file_as_string(OUT+"source-counts.json"))
	for row in rows:
		var path="res://deathmatch/weapons/fidelity/"+row.key+".scn"
		var backup=OUT+row.key+"-before.scn"
		if not FileAccess.file_exists(backup):assert(DirAccess.copy_absolute(path,backup)==OK)
		var model=load(backup).instantiate()
		var before_total=total(model)
		var doc=GLTFDocument.new();var state=GLTFState.new();assert(doc.append_from_file(OUT+row.key+"-parts.glb",state)==OK)
		var replacement=doc.generate_scene(state)
		var parts:=[]
		for spec in row.parts:
			var original=model.find_child(spec.name,true,false);var part=replacement.find_child(spec.name,true,false)
			assert(original and part)
			assert(original.transform.is_equal_approx(part.transform),"Exported part transform differs: "+row.key+" "+spec.name)
			var before=tris(original.mesh)
			var bounds=original.mesh.get_aabb();var new_bounds=part.mesh.get_aabb()
			assert((bounds.position-new_bounds.position).length()<.004 and (bounds.size-new_bounds.size).length()<.004,"Local bounds changed: "+row.key+" "+spec.name)
			assert(tris(part.mesh)<=spec.budget+2)
			assert(original.mesh.get_surface_count()==part.mesh.get_surface_count())
			var mesh=part.mesh.duplicate()
			for i in mesh.get_surface_count():mesh.surface_set_material(i,original.mesh.surface_get_material(i))
			original.mesh=mesh
			parts.append({"name":spec.name,"before":before,"after":tris(mesh),"budget":spec.budget,"bounds_delta_m":(bounds.size-new_bounds.size).length()})
		var after_total=total(model)
		if row.key in ["doom_9","quake_9"]:assert(after_total<10000)
		var scene=PackedScene.new();assert(scene.pack(model)==OK)
		assert(ResourceSaver.save(scene,path,ResourceSaver.FLAG_COMPRESS)==OK)
		report.append({"key":row.key,"before":before_total,"after":after_total,"saved":before_total-after_total,"parts":parts})
		print("INSTALLED ",row.key," ",before_total," -> ",after_total)
		model.free();replacement.free()
	FileAccess.open(OUT+"runtime-counts.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
