extends SceneTree
const Runtime=preload("res://deathmatch/maps/runtime.gd")
var failures:Array=[]
var results:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func xyz(v:Vector3)->Array:return [v.x,v.y,v.z]
func run():
 check(Runtime.push_velocity({"angle":"360"}).is_equal_approx(Vector3.FORWARD*62.5),"Default Quake conveyor respects original 2000-unit velocity bound")
 check(Runtime.push_velocity({"angle":"-1","speed":"850"},1).is_equal_approx(Vector3.UP*26.5625),"Calibrated legacy lift force is unchanged")
 check(Runtime.push_velocity({"angle":"-1","speed":"850","fpsloppa_push_scale":"1"}).is_equal_approx(Vector3.UP*26.5625),"Explicit native pad force is unchanged")
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.start_host("DM7 pipe regression",0,100,60,true,"dm","quake");game._rotate_map("qsrc_dm7");game.set_physics_process(false);game.set_process(false)
 game.bots.free();game.bots=null
 for id in game.players.keys():
  if id!=1:game._peer_left(id)
 var runtime=game.get_node("Map/MapRuntime");runtime.set_physics_process(false)
 var pushes:Array=runtime.regions.filter(func(r):return r.kind=="trigger_push")
 check(pushes.map(func(r):return r.data.model)==["*2","*3","*4","*5","*6","*7"],"All six pipe triggers retain authored BSP ordering")
 var actor=game.fighters[1]
 for side in ["short","tall"]:
  for offset in [-.5,0.,.5]:
   for phase in [0.,.5]:
    var start:=Vector3(21+offset,-3.74,-39+phase) if side=="short" else Vector3(21+offset,-13.99,-1-phase)
    actor.position=start;actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.floor_grace=0;actor.stepped_last_frame=false;actor.jump_held=false
    game.players[1].dead=false;game.players[1].hp=10000;game.players[1].invulnerable=1e9
    for i in 3:await physics_frame
    var maximum:float=start.y;var reached:Array=[]
    for tick in 150:
     await physics_frame;game.clock+=1./60.;runtime._physics_process(1./60.)
     actor.simulate(Vector2.UP if side=="short" else Vector2.DOWN,0,false,1./60.)
     maximum=maxf(maximum,actor.position.y)
     for region in pushes:
      if region.area.overlaps_body(actor) and not region.data.model in reached:reached.append(region.data.model)
    var passed:bool=maximum>5.5 if side=="short" else maximum>22
    results.append({"pipe":side,"offset":offset,"phase":phase,"start":xyz(start),"end":xyz(actor.position),"maximum_y":maximum,"triggers":reached,"passed":passed})
    check(passed,side+" pipe clears entrance, lift and exit; lateral offset="+str(offset)+" approach phase="+str(phase))
 var output:=OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() and OS.get_cmdline_user_args()[0].ends_with(".json") else "res://test-results/remote-vr-20260914/pipe-regression.json"
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"results":results,"failures":failures},"  "))
 game.disconnect_game();game.free();await process_frame;print("DM7_PIPES_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
