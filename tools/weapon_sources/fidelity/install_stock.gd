extends SceneTree
const OUT="res://test-results/weapon-stock/"
func _initialize():run.call_deferred()
func tris(mesh: Mesh) -> int:
	var count:=0
	for i in mesh.get_surface_count():count+=mesh.surface_get_array_index_len(i)/3
	return count
func run():
	var report:=[]
	for slot in [1,2,4,5,7]:
		var key="tribes_%d"%slot
		var path="res://deathmatch/weapons/fidelity/"+key+".scn"
		var backup=OUT+key+"-before.scn"
		if not FileAccess.file_exists(backup):assert(DirAccess.copy_absolute(path,backup)==OK)
		var model=load(backup).instantiate()
		var stock=model.find_child("SculptedShoulderStock",true,false)
		var doc=GLTFDocument.new();var state=GLTFState.new();assert(doc.append_from_file(OUT+key+"-stock.glb",state)==OK)
		var replacement=doc.generate_scene(state)
		var part=replacement.find_child("SculptedShoulderStock",true,false)
		assert(part and stock)
		var before=tris(stock.mesh)
		var bounds=stock.mesh.get_aabb();var new_bounds=part.mesh.get_aabb()
		assert((bounds.position-new_bounds.position).length()<.004 and (bounds.size-new_bounds.size).length()<.004,"Stock local bounds changed")
		assert(tris(part.mesh)<=1000)
		var material=stock.mesh.surface_get_material(0)
		stock.mesh=part.mesh.duplicate()
		for surface in stock.mesh.get_surface_count():stock.mesh.surface_set_material(surface,material)
		var scene=PackedScene.new();assert(scene.pack(model)==OK)
		assert(ResourceSaver.save(scene,path,ResourceSaver.FLAG_COMPRESS)==OK)
		report.append({"key":key,"before":before,"after":tris(stock.mesh),"saved":before-tris(stock.mesh),"bounds_delta_m":(bounds.size-new_bounds.size).length()})
		model.free();replacement.free()
	FileAccess.open(OUT+"runtime-counts.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("STOCK_RUNTIME ",report);quit()
