extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var loader=preload("res://deathmatch/maps/loader.gd")
	var path:="res://maps/as_frigate.bsp"
	assert(loader.validate(path).is_empty() and loader.supports_assault(path))
	var level=loader.read(path)
	assert(level!=null)
	var scene:=PackedScene.new();assert(scene.pack(level)==OK)
	assert(ResourceSaver.save(scene,"res://maps/cache/as_frigate.scn")==OK)
	assert(ResourceSaver.save(scene,"res://maps/cache/as_frigate-lightmap1.scn")==OK)
	root.add_child(level)
	# The path through a dynamic door must exist after that door opens.
	var doors:=0
	for node in level.find_children("*","PhysicsBody3D",true,false):
		if node.get_script()==preload("res://deathmatch/maps/entity.gd") and node.attributes.get("classname","")=="func_door":node.collision_layer=0;doors+=1
	var mesh=preload("res://deathmatch/bots.gd").new_mesh()
	var data:=NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh,data,level)
	NavigationServer3D.bake_from_source_geometry_data(mesh,data)
	assert(mesh.get_polygon_count()>0)
	assert(ResourceSaver.save(mesh,"res://maps/navigation/as_frigate.res")==OK)
	print("FRIGATE_BASE_BAKED polygons=",mesh.get_polygon_count()," dynamic_doors=",doors)
	level.free();quit()
