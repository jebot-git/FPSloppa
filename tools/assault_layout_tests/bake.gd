extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var loader=preload("res://deathmatch/maps/loader.gd")
	for id in ["as_hislop","as_frigate","as_hislop_tiny","as_frigate_tiny"]:
		var path: String="res://maps/"+id+".bsp"
		assert(loader.validate(path).is_empty() and loader.supports_assault(path))
		var level=loader.read(path)
		assert(level!=null)
		var scene:=PackedScene.new();assert(scene.pack(level)==OK)
		var cache: String="res://maps/cache/"+id
		assert(ResourceSaver.save(scene,cache+".scn")==OK)
		assert(ResourceSaver.save(scene,cache+"-lightmap1.scn")==OK)
		root.add_child(level)
		for node in level.find_children("*","PhysicsBody3D",true,false):
			if node.get_script()==preload("res://deathmatch/maps/entity.gd") and node.attributes.get("classname","")=="func_door":node.collision_layer=0
		var mesh=preload("res://deathmatch/bots.gd").new_mesh()
		var data:=NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh,data,level)
		NavigationServer3D.bake_from_source_geometry_data(mesh,data)
		assert(mesh.get_polygon_count()>0)
		assert(ResourceSaver.save(mesh,"res://maps/navigation/"+id+".res")==OK)
		print("LAYOUT_BAKED ",id," polygons=",mesh.get_polygon_count())
		level.free()
	quit()
