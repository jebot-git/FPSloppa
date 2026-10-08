extends SceneTree
var g
func _initialize():run.call_deferred()
func values(p: Vector3):return [p.x,p.y,p.z]
func run():
 var key: String=OS.get_cmdline_user_args()[0]
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=key
 g.start_host("Pad survey",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 var c=g.match_mode.tribes.vehicles;var pads=g.match_mode.tribes.stations()
 await physics_frame;await physics_frame
 var repairs: Array=[];var unresolved: Array=[]
 for i in pads.rows.size():
  var row: Dictionary=pads.rows[i]
  if row.kind!="vehicle":continue
  g.fighters[1].position=row.position
  var pose: Transform3D=c.spawn_frame(i);var half:=Vector3(3.15,1.,4.55)
  if c.clear_volume(pose,half):continue
  var best:=Vector3.INF;var cost:=INF;var old:=pose.origin
  for radius in [0.,2.,4.,8.,12.,16.]:
   for angle in 16:
    for up in [0.,.5,1.,2.,3.,4.,6.,8.]:
     pose.origin=old+Vector3(cos(angle*TAU/16)*radius,up,sin(angle*TAU/16)*radius)
     if pose.origin.distance_squared_to(old)>=cost:continue
     if c.clear_volume(pose,half):best=pose.origin;cost=best.distance_squared_to(old)
  if best==Vector3.INF:unresolved.append(i)
  else:repairs.append({"category":"vehicle_spawn","index":i,"from":values(old),"to":values(best)})
 var report:={"repairs":repairs,"unresolved":unresolved}
 FileAccess.open("res://test-results/t2-classic/"+key+"/repairs.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PAD_SURVEY ",JSON.stringify(report));g.queue_free();await process_frame;quit(0 if unresolved.is_empty() else 1)
