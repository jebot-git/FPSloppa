extends SceneTree
func _initialize():run.call_deferred()
func run():
	var loader=load("res://deathmatch/maps/loader.gd")
	var selected=OS.get_cmdline_user_args()
	if selected.is_empty():selected=PackedStringArray(["nuke","inferno","aztec","train"])
	for map in selected:
		var id: String="de_"+map+"_rebuilt";var path: String="res://maps/"+id+".bsp"
		assert(loader.validate(path).is_empty())
		var level=loader.read(path);assert(level)
		var scene:=PackedScene.new();assert(scene.pack(level)==OK)
		assert(ResourceSaver.save(scene,"res://maps/cache/"+id+".scn")==OK)
		assert(ResourceSaver.save(scene,"res://maps/cache/"+id+"-lightmap1.scn")==OK)
		root.add_child(level)
		var mesh=load("res://deathmatch/bots.gd").new_mesh(id)
		var data:=NavigationMeshSourceGeometryData3D.new()
		NavigationServer3D.parse_source_geometry_data(mesh,data,level)
		NavigationServer3D.bake_from_source_geometry_data(mesh,data)
		assert(mesh.get_polygon_count()>0)
		assert(ResourceSaver.save(mesh,"res://maps/navigation/"+id+".res")==OK)
		print("CLASSIC_DE_BAKE ",id," polygons=",mesh.get_polygon_count())
		level.free()
	quit()
