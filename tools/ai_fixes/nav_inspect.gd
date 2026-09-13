extends SceneTree
var game
var report:Dictionary={"probes":[],"trials":[]}
func _initialize():run.call_deferred()
func run():
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.selected_map="qsrc_dm3";game.start_host("Traversal observer",0,100000,60,true,"dm","quake")
 game.set_process(false);game.set_physics_process(false);game.dedicated=true
 for id in game.players:
  game.players[id].spectator=id!=-1;game._spawn(id)
 var deadline:=Time.get_ticks_msec()+30000
 while not game.bots.navigation.ready():
  if Time.get_ticks_msec()>deadline:push_error("Navigation timeout");quit(1);return
  await physics_frame
 game.bots.navigation.install_links()
 for i in 120:game.bots.navigation.update_jump_links();await physics_frame

 for i in 1500:game.bots.navigation.update_jump_links();await physics_frame
 var nav=game.bots.navigation;var region=game.bots.region;var map=region.get_navigation_map()
 var doors:Array=[]
 for door in game.gates:doors.append({"center":door.center,"travel":door.travel,"bounds":game.get_node("Map/MapRuntime").node_bounds(door.node)})
 var links:Array=[]
 for link in nav.links:
  if link.start.distance_to(Vector3(-24,6,-16))<12:links.append({"start":link.start,"end":link.end,"kind":link.kind})
 var tests:Array=[]
 for start:Vector3 in nav.jump_candidates:
  if start.distance_to(Vector3(-24,6,-16))>10:continue
  for i in 16:
   var probe:Vector3=start+Vector3(cos(i*TAU/16),0,sin(i*TAU/16))*3.5
   var hit:Dictionary=nav.ray(probe+Vector3.UP*.3,probe-Vector3.UP*6.5)
   if hit.is_empty() or hit.normal.y<.7 or start.y-hit.position.y<1.4:continue
   var end:Vector3=NavigationServer3D.map_get_closest_point(map,hit.position)
   tests.append({"start":start,"end":end,"drop":nav.drop_clear(start,end),"jump":nav.jump_clear(start,end),"clear":nav.landing_clear(end),"projection":end.distance_to(hit.position)})
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify({"doors":doors,"water_path":nav.path(Vector3(2.5,-7.16,-42.24),Vector3(10.75,-1.45,-43.25)),"links":links,"tests":tests,"cursor":nav.jump_cursor,"candidates":nav.jump_candidates.size()},"  "))
 game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
