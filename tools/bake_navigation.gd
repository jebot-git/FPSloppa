extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for row in preload("res://deathmatch/maps/loader.gd").catalog():
		if not row.id.begins_with("lqdm"): continue
		var level: Node3D=load(row.scene).instantiate()
		root.add_child(level)
		var mesh:=preload("res://deathmatch/bots.gd").new_mesh()
		var data:=NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh,data,level)
		NavigationServer3D.bake_from_source_geometry_data(mesh,data)
		var path: String="res://deathmatch/maps/navigation/"+row.id+".res"
		if mesh.get_polygon_count()==0 or ResourceSaver.save(mesh,path)!=OK: quit(1);return
		print("NAV_BAKED ",row.id," polygons=",mesh.get_polygon_count())
		level.free()
	quit()
