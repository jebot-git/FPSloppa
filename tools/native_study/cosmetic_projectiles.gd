extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Prediction=preload("res://deathmatch/network/projectile_prediction.gd")
func stats(a:Array) -> Dictionary:
 a.sort();return {"median":a[a.size()/2],"p95":a[int(a.size()*.95)]}
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.armory.select("quake");game.start_host("Cosmetic cost",0,100,10,true,"dm","quake")
 if game.bots:game.bots.free();game.bots=null
 game.set_process(false);game.set_physics_process(false)
 await physics_frame;await physics_frame
 var began_setup:=Time.get_ticks_usec();game._weapon_visuals();var setup_us:=Time.get_ticks_usec()-began_setup
 var reports:Array=[];var start:Vector3=Fixture.point()+Vector3.UP*3
 for count in [1,6,32]:
  var prediction=Prediction.new();var spawn_times:Array=[]
  for i in count:
   var began:=Time.get_ticks_usec();prediction.add(game,[1,i+1,1,0,6],game.armory.data(6),start,Vector3.RIGHT);spawn_times.append(Time.get_ticks_usec()-began)
  var times:Array=[]
  for iteration in 220:
   for p in prediction.flights.values():p.age=0.;p.position=start;p.stopped=false
   var began:=Time.get_ticks_usec();prediction.step(game,1./90.,1,6,false,[])
   if iteration>=20:times.append(Time.get_ticks_usec()-began)
  reports.append({"cosmetics":count,"step_us":stats(times),"creation_us":stats(spawn_times)})
  prediction.reset();await process_frame
 print("COSMETIC_PERF_RESULT ",JSON.stringify({"reports":reports,"shared_fx_setup_us":setup_us,"scope":"Headless Node3D construction and world-clearance steps, 20 warmup/200 samples; excludes GPU, trails, effects and headset frame time. Creation samples are cold and few."}))
 game.disconnect_game();game.free();await process_frame;quit()
