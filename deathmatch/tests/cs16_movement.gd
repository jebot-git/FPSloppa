extends SceneTree
const CS=preload("res://deathmatch/movement/cs16.gd")
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Wire=preload("res://deathmatch/network/locomotion_wire.gd")
const DT:=1.0/60
var failures:Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func terminal(wish:Vector2,speed:float) -> Vector2:
 var v:=Vector2.ZERO
 for tick in 600:v=CS.horizontal(v,wish,speed,true,DT)
 return v
func run():
 var run_speed:=250.0/32
 check(is_equal_approx(CS.horizontal(Vector2.ZERO,Vector2.RIGHT,run_speed,true,.01).x,12.5/32),"Stock ground acceleration adds 12.5 units/s in a 10 ms command")
 check(is_equal_approx(CS.horizontal(Vector2(250.0/32,0),Vector2.ZERO,run_speed,true,.01).x,240.0/32),"Stock ground friction removes 10 units/s in a 10 ms command")
 check(is_equal_approx(CS.horizontal(Vector2(50.0/32,0),Vector2.ZERO,run_speed,true,.01).x,47.0/32),"Low-speed friction uses the 75-unit stop threshold")
 check(CS.horizontal(Vector2(250.0/32,0),Vector2.ZERO,run_speed,true,.01,0,true).x==230.0/32,"Edge friction doubles ground braking")
 for strength in [1.0,.5,.1]:
  check(absf(terminal(Vector2.RIGHT*strength,run_speed).length()-run_speed*strength)<.001,"VR analog speed %.1f"%strength)
 check(is_equal_approx(terminal(Vector2.ONE,run_speed).length(),run_speed),"Diagonal commands do not exceed weapon speed")
 var drift:=Vector2(250.0/32,0)
 check(CS.horizontal(drift,Vector2.ZERO,run_speed,false,DT)==drift,"Air coasting preserves momentum")
 check(CS.horizontal(drift,Vector2.RIGHT,run_speed,false,DT)==drift,"Air wish cap prevents forward acceleration past 30 units/s")
 var strafe:=CS.horizontal(drift,Vector2.DOWN,run_speed,false,.01)
 check(is_equal_approx(strafe.y,25.0/32) and strafe.x==drift.x,"Air acceleration uses uncapped wish speed but caps directional gain")
 check(is_equal_approx(CS.horizontal(strafe,Vector2.DOWN,run_speed,false,.01).y,30.0/32),"Second air command saturates the 30-unit projection")
 check(CS.jump_limit(Vector2(300.0/32,0),run_speed).x==300.0/32,"Bunny-hop limit permits exactly 120 percent")
 check(is_equal_approx(CS.jump_limit(Vector2(400.0/32,0),run_speed).x,240.0/32),"Overspeed jump crops to 96 percent of weapon speed")
 check(is_equal_approx(CS.stamina_ratio(CS.JUMP_STAMINA),.75),"Fresh jump fatigue gives 75 percent jump power")
 var world:=Node3D.new();root.add_child(world)
 Fixture.box(world,Vector3(0,-.5,0),Vector3(100,1,100))
 var actor:=Fighter.new();actor.setup(1,"CS movement",Color.WHITE);world.add_child(actor);actor.set_process(false)
 actor.configure_cs16(true);actor.position=Vector3(0,.02,0)
 for i in 10:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT)
 for i in 90:await physics_frame;actor.simulate(Vector2.UP,0,false,DT)
 check(actor.is_supported() and absf(actor.velocity.z+run_speed)<.01,"Real collision movement reaches 250 units/s")
 for i in 90:await physics_frame;actor.simulate(Vector2.UP,0,true,DT)
 check(absf(actor.velocity.z+130.0/32)<.01,"Walking reaches 52 percent speed")
 actor.update_height(1.05,true)
 for i in 90:await physics_frame;actor.simulate(Vector2.UP,0,false,DT)
 check(absf(actor.velocity.z+83.25/32)<.01,"Crouching reaches 33.3 percent speed")
 actor.update_height(1.65,true);actor.position=Vector3(0,.02,0);actor.velocity=Vector3.ZERO;actor.reset_view()
 for i in 10:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT)
 var base:float=actor.position.y;var apex:=base;var takeoffs:=0
 for i in 100:
  await physics_frame
  var ground:bool=actor.is_supported()
  actor.simulate(Vector2.ZERO,0,false,DT,true)
  apex=maxf(apex,actor.position.y)
  if ground and actor.velocity.y>1:takeoffs+=1
 check(absf(apex-base-45.0/32)<.02,"Jump apex is 45 GoldSrc units")
 check(takeoffs==1 and actor.is_supported(),"Holding jump cannot auto-hop")
 actor.cs16_stamina=0
 await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,false)
 await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,true)
 for i in 10:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,false)
 for i in 75:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,true)
 check(actor.is_supported() and actor.velocity.y<=0,"A press while airborne is consumed instead of queued for landing")
 actor.cs16_stamina=CS.JUMP_STAMINA
 await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,false)
 await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,true)
 check(actor.velocity.y<6.1 and actor.velocity.y>5.8,"Rapid second jump has reduced takeoff speed")
 var state:=actor.locomotion_state()
 var decoded:=Wire.decode(Wire.encode(state))
 check(is_equal_approx(decoded.replay.cs16_stamina,actor.cs16_stamina),"Jump fatigue survives compact snapshot encoding")
 actor.cs16_stamina=0;actor.restore_prediction_state(decoded.replay)
 check(actor.cs16_stamina>1.3,"Authority restores fatigue for prediction replay")
 actor.position=Vector3(0,5,0);actor.velocity=Vector3.ZERO;actor.in_water=true
 for i in 60:await physics_frame;actor.simulate(Vector2.RIGHT,0,false,DT,false)
 check(absf(actor.velocity.x-200.0/32)<.01,"CS swimming reaches 80 percent of running speed")
 await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT,true)
 check(actor.velocity.y>2.8 and actor.velocity.y<3.2,"Held jump swims upward at CS water speed")
 actor.in_water=false
 Fixture.box(world,Vector3(2,2,0),Vector3(.2,4,10))
 actor.position=Vector3(1.59,.02,0);actor.velocity=Vector3.ZERO;actor.reset_view()
 for i in 10:await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT)
 for i in 150:await physics_frame;actor.simulate(Vector2(1,.2),0,false,DT)
 check(actor.position.z>.1 and actor.position.x<1.61,"Shallow wall input slides tangentially without a 15-degree dead zone")
 actor.reset_view();check(actor.cs16_stamina==0 and not actor.jump_held,"Respawn/reset clears fatigue and jump latch")
 actor.configure_cs16(false);check(is_equal_approx(actor.floor_snap_length,.6) and is_equal_approx(actor.movement_speed(),9.4),"Leaving CS profile restores arena movement")
 world.free();await process_frame
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="de_varq_nuke_rarea";g.start_host("CS movement rules",0,20,10,true,"de")
 g.set_process(false);g.set_physics_process(false)
 var id:=1;var s:Dictionary=g.players[id];var f=g.fighters[id]
 check(f.cs16_enabled and not f.tribes_enabled,"DE spawn on a supported map activates CS movement")
 var codec=preload("res://deathmatch/network/codec.gd").native_codec
 f.cs16_stamina=.875
 var row:Array=[1,Vector3.ZERO,Vector3.ZERO,0.,0.,100,0,false,6,[1,2,3,4],[6],0,0,0,1,0.,false,0.,{},0.,false,Vector2.ZERO]
 var snapshot:Array=[[row],PackedByteArray(),600.,0.,"",20,600.,[],[],1,{"kind":"de","locomotion":{1:f.locomotion_state()},"movement_ack":{}},{},1.,0]
 var groups:Dictionary=codec.snapshot_records(snapshot,1,{},{},{})
 var record:Array=codec.decode(groups.personal[0].slice(1))
 check(Wire.decode(record[3]).replay.cs16_stamina==.875,"Native recipient snapshot preserves CS fatigue for client replay")
 for w in range(12):
  s.weapon=w;g._configure_cs16(id,{})
  check(is_equal_approx(f.cs16_max_speed,float(preload("res://deathmatch/counterstrike/arsenal.gd").SPEEDS[w])/32),"Weapon speed "+str(w))
 s.weapon=9;g._configure_cs16(id,{"alt_fire":true})
 check(f.cs16_max_speed==150.0/32,"Scoped AWP uses 150 units/s for desktop and optic aim input")
 g._configure_cs16(id,{"alt_fire":false});check(f.cs16_max_speed==210.0/32,"Unscoping restores AWP speed immediately")
 g.match_mode.kind="dm";g._configure_cs16(id,{})
 check(not f.cs16_enabled,"DE map in another mode retains arena movement")
 g.match_mode.kind="de";var saved_sha:String=g.map_sha;g.map_sha="unknown";g._configure_cs16(id,{})
 check(not f.cs16_enabled,"DE mode on an unsupported map does not activate CS movement")
 g.map_sha=saved_sha;g._configure_cs16(id,{})
 var saved_map:String=g.current_map;g.current_map=g.lobby.ID;g._configure_cs16(id,{})
 check(not f.cs16_enabled,"Lobby never inherits CS movement")
 g.current_map=saved_map;g._configure_cs16(id,{})
 f.cs16_stamina=1;g._spawn(id);check(f.cs16_stamina==0,"New round clears jump fatigue")
 g.bots.free();g.bots=null;Fixture.setup(g)
 f.position=Fixture.point();f.velocity=Vector3.ZERO;f.reset_view()
 s.weapon=0;s.move=Vector2.UP;s.last_input=g.clock
 var de=g.match_mode.defusal;de.phase="prepare";de.phase_end=g.clock+20
 var before:Vector3=f.position
 g._server_tick(DT)
 check(f.position==before and f.velocity==Vector3.ZERO,"Preparation still freezes authoritative CS movement")
 de.phase="live";de.phase_end=g.clock+120
 for i in 90:
  await physics_frame
  g.clock+=DT;s.last_input=g.clock;s.move=Vector2.UP
  g._server_tick(DT)
 check(absf(Vector2(f.velocity.x,f.velocity.z).length()-250.0/32)<.01,"Live server tick uses CS speed without applying weapon scaling twice")
 g.disconnect_game();g.free();await process_frame
 print("CS16_MOVEMENT_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
