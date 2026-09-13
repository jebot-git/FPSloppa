extends SceneTree
var game
func _initialize():run.call_deferred()
func length_of(route:PackedVector3Array)->float:
 var length:=0.0
 for i in range(1,route.size()):length+=route[i-1].distance_to(route[i])
 return length
func run():
 var opts:Dictionary=JSON.parse_string(OS.get_cmdline_user_args()[0])
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.selected_map=opts.map;game.start_host("Supply route audit",0,100000,60,true,opts.mode,opts.rules)
 game.set_process(false);game.set_physics_process(false)
 var deadline:=Time.get_ticks_msec()+30000
 while not game.bots.navigation.ready():
  if Time.get_ticks_msec()>deadline:push_error("Supply audit navigation timeout");quit(1);return
  await physics_frame
 game.bots.navigation.install_links()
 for i in 120:game.bots.navigation.update_jump_links();await physics_frame
 var rows:Array=[]
 for team in 2:
  var spawn_points:Array=game.match_mode.spawns(team)
  var goal:Vector3=game.match_mode.hill if opts.mode=="koth" else game.match_mode.bases[1-team]
  for index in spawn_points.size():
   var start:Vector3=spawn_points[index];var direct:PackedVector3Array=game.bots.navigation.path(start,goal)
   for pickup in game.pickups:
    if pickup.kind!="weapon":continue
    var route:PackedVector3Array=game.bots.navigation.path(start,pickup.position)
    var onward:PackedVector3Array=game.bots.navigation.path(pickup.position,goal)
    var direct_length:=length_of(direct);var via_length:=length_of(route)+length_of(onward)
    rows.append({"team":team,"spawn":index,"start":start,"goal":goal,"weapon":pickup.item,"weapon_name":game.armory.data(int(pickup.item)).get("name",""),"position":pickup.position,"capsule_clear":game.bots.navigation.landing_clear(pickup.position),"navigation_offset":NavigationServer3D.map_get_closest_point(game.bots.region.get_navigation_map(),pickup.position).distance_to(pickup.position),"route_to_weapon":route.size(),"route_onward":onward.size(),"direct_route":direct.size(),"direct_metres":direct_length,"via_metres":via_length,"detour_ratio":via_length/direct_length if direct_length>0 and route.size()>1 and onward.size()>1 else -1})
 var output:Dictionary={"map":opts.map,"bsp_sha256":FileAccess.get_sha256("res://maps/"+opts.map+".bsp"),"rows":rows,"limits":"Navigation and pickup capsule clearance only; prior physical route tests remain separate. A finite detour ratio is not proof of tactical safety under fire."}
 FileAccess.open(opts.output,FileAccess.WRITE).store_string(JSON.stringify(output,"  "));print("SUPPLY_AUDIT ",opts.map," ",rows.size())
 game.disconnect_game();game.queue_free();await process_frame;await process_frame;quit()
