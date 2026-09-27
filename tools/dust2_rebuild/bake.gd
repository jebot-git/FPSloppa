extends SceneTree
const ID="de_dust2_rebuilt"
func _initialize():run.call_deferred()
func run():
	var loader=load("res://deathmatch/maps/loader.gd")
	var path="res://maps/"+ID+".bsp"
	assert(loader.validate(path).is_empty())
	var level=loader.read(path);assert(level)
	var scene=PackedScene.new();assert(scene.pack(level)==OK)
	assert(ResourceSaver.save(scene,"res://maps/cache/"+ID+".scn")==OK)
	assert(ResourceSaver.save(scene,"res://maps/cache/"+ID+"-lightmap1.scn")==OK)
	root.add_child(level)
	var mesh=load("res://deathmatch/bots.gd").new_mesh()
	var data=NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh,data,level)
	NavigationServer3D.bake_from_source_geometry_data(mesh,data)
	assert(mesh.get_polygon_count()>0)
	assert(ResourceSaver.save(mesh,"res://maps/navigation/"+ID+".res")==OK)
	print("DUST2_BAKE polygons=",mesh.get_polygon_count())
	level.free();quit()
