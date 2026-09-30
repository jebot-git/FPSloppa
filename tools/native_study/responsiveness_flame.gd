extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Cone=preload("res://deathmatch/modes/flame_cone.gd")
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.start_host("Flame cost",0,100,60,true,"tf","quake")
 game.bots.free();game.bots=null;game.set_process(false);game.set_physics_process(false)
 for i in range(1,16):
  if not game.players.has(-i):game._add_player(-i,"Trace target")
 for id in game.players:
  game.players[id].dead=false;game.players[id].spectator=false
  game.fighters[id].position=Fixture.point(id*.65,-5)
 game.fighters[1].position=Fixture.point()
 await physics_frame;await physics_frame
 var reports:Array=[];var start:Vector3=Fixture.point()+Vector3.UP*1.3
 for rays in [1,5]:
  var samples:Array=[]
  for iteration in 220:
   var seen:Dictionary={};var began:=Time.get_ticks_usec()
   for ray in rays:
    var end:Vector3=start+Cone.direction(Basis.IDENTITY,ray,5.)*8.
    var hit:Dictionary=game._trace(start,end,1)
    Cone.first_hit(seen,hit)
   if iteration>=20:samples.append(Time.get_ticks_usec()-began)
  samples.sort();reports.append({"rays":rays,"median_us":samples[samples.size()/2],"p95_us":samples[int(samples.size()*.95)]})
 print("FLAME_PERF_RESULT ",JSON.stringify({"players":game.players.size(),"native_trace":game.native_projectiles!=null and game._native_trace_allowed(),"measurements":reports,"scope":"World/body queries and per-dose target deduplication only, 16 players; no damage, rendering, network, or rewind. 20 warmup plus 200 samples per case."}))
 game.disconnect_game();game.free();await process_frame;quit()
