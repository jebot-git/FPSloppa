extends SceneTree
## Real authored navigation/Jolt smoke for the native prototype bot planner.
var arena
func _initialize()->void:call_deferred("run")
func run()->void:
 var packed:PackedScene=load("res://tools/voxel_battle/class_arena.tscn")
 arena=packed.instantiate();root.add_child(arena)
 var starts:Dictionary={};var lives:Dictionary={};var distance:=0.;var shots:=0;var ticks:=0
 for frame in 5400:
  await physics_frame
  if not arena.resident.enabled or arena.resident.core==null or not is_instance_valid(arena.bots) or not arena.bots.ready_to_walk:continue
  ticks+=1
  for id in arena.players:
   if id>=0:continue
   var state:Dictionary=arena.resident.core.inspect(id)
   if state.is_empty():continue
   if starts.has(id) and lives.get(id)==state.life:distance=maxf(distance,state.position.distance_to(starts[id]))
   else:starts[id]=state.position;lives[id]=state.life
   shots=maxi(shots,state.shots)
  if ticks>=600:break
 var failures:Array=[]
 if starts.size()!=4:failures.append("four bots admitted")
 if distance<2:failures.append("bots traverse authored navigation")
 if ticks<600:failures.append("native simulation startup")
 var result:Dictionary={"bots":starts.size(),"maximum_displacement":distance,"maximum_shots":shots,"ticks":ticks,"failures":failures}
 print("AUTHORITY_BOTS ",JSON.stringify(result))
 var args:=OS.get_cmdline_user_args();var index:=args.find("--authority-client-report")
 if index>=0:var f:=FileAccess.open(args[index+1],FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"))
 arena.queue_free();await process_frame;await create_timer(.3).timeout;quit(0 if failures.is_empty() else 1)
