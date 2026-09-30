extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Cone=preload("res://deathmatch/modes/flame_cone.gd")
func stats(a:Array) -> Dictionary:
 a.sort();return {"median":a[a.size()/2],"p95":a[int(a.size()*.95)]}
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.start_host("Special trace study",0,100,60,true,"tf","quake")
 if game.bots:game.bots.free();game.bots=null
 game.set_process(false);game.set_physics_process(false)
 for i in range(1,16):
  if not game.players.has(-i):game._add_player(-i,"Trace target")
 for id in game.players:
  game.players[id].dead=false;game.players[id].spectator=false;game.fighters[id].position=Fixture.point(id*.65,-5)
 game.fighters[1].position=Fixture.point()
 await physics_frame;await physics_frame
 if not game.native_projectiles:push_error("Native extension required");quit(1);return
 var start:Vector3=Fixture.point()+Vector3.UP*1.3;var reports:Array=[]
 for scenario in [["tf",0],["tf",16],["tf",64],["st",16],["st",64]]:
  var buildings:int=scenario[1];var mode:String=scenario[0]
  game.match_mode.kind=mode;game.armory.select("tribes" if mode=="st" else "quake")
  game.match_mode.tribes.deployables.rows.clear()
  game.match_mode.tribes.targeting.beacons.clear()
  game.match_mode.tribes.vehicles.rows.clear()
  game.match_mode.fortress.buildings.clear()
  for i in buildings:
   var position:Vector3=Fixture.point((i%8-4)*.8,-2.-(i/8)*.8)
   if mode=="tf":game.match_mode.fortress.buildings[str(i)]={"position":position}
   else:game.match_mode.tribes.deployables.rows[i+1]={"kind":"turret","position":position,"normal":Vector3.UP,"yaw":0.}
  if mode=="st":
   for i in 4:game.match_mode.tribes.vehicles.rows[i+1]={"kind":"scout","position":Fixture.point(i*5-8,-10)+Vector3.UP,"yaw":.2}
   for i in 8:game.match_mode.tribes.targeting.beacons[i+1]={"position":Fixture.point(i*1.5-6,-6)+Vector3.UP}
  for hybrid in [false,true,true,false]:
   var times:Array=[];var mismatches:=0
   for iteration in 120:
    var began:=Time.get_ticks_usec();var hits:Array=[];var seen:Dictionary={}
    for ray in 5:
     var end:Vector3=start+Cone.direction(Basis.IDENTITY,ray,5.)*8.
     var hit:Dictionary
     if hybrid:hit=game._trace(start,end,1)
     else:hit=game._trace_reference(start,end,1)
     Cone.first_hit(seen,hit);hits.append(hit)
    if iteration>=20:times.append(Time.get_ticks_usec()-began)
    if hybrid and iteration==20:
     for ray in 5:
      var expected:Dictionary=game._trace_reference(start,start+Cone.direction(Basis.IDENTITY,ray,5.)*8.,1)
      if expected.id!=hits[ray].id or expected.get("building","")!=hits[ray].get("building","") or expected.position.distance_to(hits[ray].position)>.001:mismatches+=1
   reports.append({"mode":mode,"structures":buildings,"native":hybrid,"five_rays_us":stats(times),"fixture_mismatches":mismatches})
 game.match_mode.fortress.buildings.clear()
 game.match_mode.tribes.deployables.rows.clear();game.match_mode.tribes.targeting.beacons.clear();game.match_mode.tribes.vehicles.rows.clear()
 print("SPECIAL_TRACE_PERF_RESULT ",JSON.stringify({"reports":reports,"production_gate_enabled":game._native_trace_allowed(),"scope":"16 actors, five rays, TF structures or ST deployables with four scouts/eight beacons; production native body/structure tracing versus complete reference; no rendered scene or damage application. Hull/Tribes correctness covered separately."}))
 game.disconnect_game();game.free();await process_frame;quit()
