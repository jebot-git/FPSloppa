extends SceneTree
var g
func _initialize():run.call_deferred()
func run():
 var key: String=OS.get_cmdline_user_args()[0]
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map=key
 g.start_host("Classic route survey",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 await physics_frame;await physics_frame
 var started:=Time.get_ticks_msec();var routes=g.bots.tribes.routes;routes.build()
 var failures: Array=[];var checks:=0
 for team in 2:
  for spawn in g.ctf_spawns[team]:
   checks+=1
   if routes.path(spawn,g.match_mode.bases[1-team]).is_empty():failures.append({"team":team,"spawn":str(spawn)})
 var report:={"id":key,"checks":checks,"failures":failures,"nodes":routes.points.size(),"elapsed_ms":Time.get_ticks_msec()-started}
 FileAccess.open("res://test-results/t2-classic/"+key+"/routes.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CLASSIC_ROUTES ",JSON.stringify(report));g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
