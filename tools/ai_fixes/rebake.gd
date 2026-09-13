extends SceneTree
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.selected_map="qsrc_dm3";game.start_host("Navigation bake",0,100,60,true,"dm","quake")
 game.set_process(false);game.set_physics_process(false)
 var mesh=game.bots.new_mesh("qsrc_dm3")
 var data:=NavigationMeshSourceGeometryData3D.new()
 var level=game.get_node("Map").get_child(0)
 for node in level.find_children("*","PhysicsBody3D",true,false):
  if node.get_script()==preload("res://deathmatch/maps/entity.gd") and node.attributes.get("classname","") in ["func_door","func_door_secret"]:node.collision_layer=0
 NavigationServer3D.parse_source_geometry_data(mesh,data,level)
 NavigationServer3D.bake_from_source_geometry_data(mesh,data)
 var error:=ResourceSaver.save(mesh,"res://maps/navigation/qsrc_dm3.res")
 print("REBAKE ",mesh.get_polygon_count()," ",error)
 game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit(error)
