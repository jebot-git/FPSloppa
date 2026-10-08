extends SceneTree
func _initialize():run.call_deferred()
func run():
 var id: String=OS.get_cmdline_user_args()[0]
 var scene:=load("res://maps/cache/"+id+"-lightmap1.scn") as PackedScene;var level:=scene.instantiate();root.add_child(level)
 var mesh:=preload("res://deathmatch/bots.gd").new_mesh(id);mesh.cell_size=.16;mesh.cell_height=.05;mesh.agent_radius=.32;mesh.agent_max_climb=.55;mesh.region_min_size=1.
 var data:=NavigationMeshSourceGeometryData3D.new();var doors:=preload("res://deathmatch/maps/de_navigation.gd").open_for_navigation(level)
 NavigationServer3D.parse_source_geometry_data(mesh,data,level);preload("res://deathmatch/maps/de_navigation.gd").restore(doors)
 NavigationServer3D.bake_from_source_geometry_data(mesh,data)
 assert(mesh.get_polygon_count()>0);assert(ResourceSaver.save(mesh,"res://maps/navigation/"+id+".res",ResourceSaver.FLAG_COMPRESS)==OK)
 print("ARENA_FINE_NAV ",id," ",mesh.get_polygon_count());level.free();quit()
