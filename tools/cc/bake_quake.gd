extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var loader=preload("res://deathmatch/maps/loader.gd")
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://deathmatch/maps/manifest.json")).filter(func(row):return str(row.id).begins_with("qsrc_dm"))
	for row in rows:
		var id: String=row.id
		var path: String="res://maps/"+id+".bsp"
		assert(loader.validate(path).is_empty())
		var level=loader.read(path)
		assert(level!=null)
		var scene:=PackedScene.new();assert(scene.pack(level)==OK)
		assert(ResourceSaver.save(scene,"res://maps/cache/"+id+".scn")==OK)
		assert(ResourceSaver.save(scene,"res://maps/cache/"+id+"-lightmap1.scn")==OK)
		assert(level.get_meta("baked_light_invalid_faces",0)==0 and level.get_meta("baked_light_overflow_faces",0)==0)
		root.add_child(level)
		for node in level.find_children("*","PhysicsBody3D",true,false):
			if node.get_script()==preload("res://deathmatch/maps/entity.gd") and node.attributes.get("classname","") in ["func_door","func_door_secret"]:node.collision_layer=0
		var mesh=preload("res://deathmatch/bots.gd").new_mesh()
		var data:=NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh,data,level)
		NavigationServer3D.bake_from_source_geometry_data(mesh,data)
		assert(mesh.get_polygon_count()>0)
		assert(ResourceSaver.save(mesh,"res://maps/navigation/"+id+".res")==OK)
		print("QUAKE_BAKED ",id," polygons=",mesh.get_polygon_count())
		level.free()
	quit()
