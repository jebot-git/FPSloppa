extends SceneTree
## Fixed navigation goals; traversal uses real BSP triggers and player physics.
var game
var checks:Array=[]
var rows:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks.append({"pass":ok,"name":label});print("PASS " if ok else "FAIL ",label)
func run():
 seed(7129)
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 var maps=Array(OS.get_cmdline_user_args()) if not OS.get_cmdline_user_args().is_empty() else ["tf_vesper","qsrc_dm7","koth_hyperborea"]
 for map in maps:
  game.selected_map=map;game.start_host("Transport",0,100,60,true,"tf" if map=="tf_vesper" else "koth" if map.begins_with("koth_") else "dm","quake")
  game.set_physics_process(false);game.set_process(false)
  for id in [1,-2,-3]:game._peer_left(id)
  game.players[-1].tf_class="soldier";game.players[-1].tf_next="soldier";game._spawn(-1)
  var deadline=Time.get_ticks_msec()+20000
  while not game.bots.ready_to_walk or not game.bots.navigation.ready():
   if Time.get_ticks_msec()>deadline:check(false,"Navigation ready "+map);finish();return
   await physics_frame
  for frame in 5:await physics_frame
  game.bots.navigation.install_links()
  for frame in 4:await physics_frame
  var links=game.bots.navigation.links.filter(func(link):return link.kind in ["lift","pad","trigger_push","push_chain"])
  if map in ["tf_vesper","qsrc_dm7"]:check(links.filter(func(link):return link.kind=="lift").size()==(4 if map=="tf_vesper" else 1),map+" has all elevator route links")
  if map=="koth_hyperborea":check(links.size()==3,"Hyperborea has all three directional jump-pad routes")
  if map=="qsrc_dm7":check(links.filter(func(link):return link.kind=="push_chain").size()>=2,"DM7 vertical and directional push routes are recognized")
  for link in links:
   await traverse(map,link)
  if map=="tf_vesper":await traverse(map,links[0],true)
  game.disconnect_game();await physics_frame
 finish()
func traverse(map:String,link:Dictionary,wait_for_lift:bool=false):
 var actor=game.fighters[-1];var s:Dictionary=game.players[-1];var runtime=game.get_node("Map/MapRuntime")
 actor.position=link.start+Vector3.UP*.06;actor.velocity=Vector3.ZERO;actor.reset_view();s.dead=false;s.hp=10000;s.invulnerable=1000
 if link.kind=="lift":
  link.lift.node.position.y=link.lift.base
  for gate in game.gates:
   if gate.node==link.lift.node:
    if gate.has("motion_tween") and is_instance_valid(gate.motion_tween):gate.motion_tween.kill()
    gate.open=false;gate.until=0
 if wait_for_lift:
  for gate in game.gates:
   if gate.node==link.lift.node:gate.node.position=gate.base_position+gate.travel;gate.open=true;gate.until=game.clock+2
  actor.position=Vector3(link.end.x,link.start.y+.06,link.end.z)
 runtime.trigger_until.clear()
 for frame in 10:await physics_frame
 var brain=game.bots.new_brain(-1);brain.goal=link.end;brain.goal_kind="item";brain.hold=true;brain.next=INF;brain.plan_at=INF
 brain.path=game.bots.navigation.path(actor.position,link.start if wait_for_lift else link.end);brain.step=0
 if wait_for_lift:brain.path.append(link.end)
 game.bots.brains[-1]=brain
 var initial:Vector3=actor.position;var peak:float=initial.y;var launched=false;var reached=false
 check(not brain.path.is_empty(),map+" planner routes "+link.kind+" to "+str(link.end))
 for frame in 1200:
  await physics_frame;game._physics_process(1.0/60)
  # Suppress combat replanning, but let steering retain all traversal state.
  brain.next=INF;brain.plan_at=INF
  peak=maxf(peak,actor.position.y);launched=launched or actor.velocity.y>10
  if actor.position.distance_to(link.end)<.45 and actor.is_supported():
   var floor_hit=game.bots.navigation.ray(actor.position+Vector3.UP*.1,actor.position-Vector3.UP*.3)
   if not floor_hit.is_empty() and (link.kind!="lift" or floor_hit.collider!=link.lift.node):reached=true;break
 var row={"map":map,"kind":link.kind,"wait_for_lift":wait_for_lift,"start":str(initial),"end":str(link.end),"final":str(actor.position),"peak":peak,"launched":launched,"reached":reached,"path":str(brain.path),"step":brain.step,"lift_state":str(brain.lift_link)}
 rows.append(row);print("TRANSPORT_ROW ",JSON.stringify(row))
 check(reached,map+(" bot waits for and completes " if wait_for_lift else " bot completes ")+link.kind+" and lands at destination")
func finish():
 var passed=checks.all(func(row):return row.pass)
 FileAccess.open("res://test-results/server-bots/transport"+("-"+str(OS.get_cmdline_user_args()[0]) if not OS.get_cmdline_user_args().is_empty() else "")+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":passed,"checks":checks,"traversals":rows},"  "))
 game.disconnect_game();game.free();print("BOT_MAP_TRANSPORT_RESULT ",passed);quit(0 if passed else 1)
