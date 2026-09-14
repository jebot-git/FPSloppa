extends "res://deathmatch/tests/network_runner.gd"
const Delivery=preload("res://deathmatch/network/fire_delivery.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
const JumpDelivery=preload("res://deathmatch/network/input_delivery.gd")
var rules:="quake"
func cases() -> Array:
 var rows:Array=[{"name":"normal_jump","vr":false,"rocket":false},
  {"name":"standing_rocket","vr":false,"rocket":true},
  {"name":"tracked_floor_rocket","vr":true,"rocket":true,"low":true}]
 for phase in 4:
  rows.append({"name":"moving_bhop_phase_%d"%phase,"vr":true,"rocket":true,"moving":true,"phase":phase,"drop":phase%2==1,"delay":6 if phase>=2 else 0,"low":phase%2==1})
 rows.append({"name":"brief_tap_before_cooldown_ends","vr":true,"rocket":true,"cooldown":.2})
 return rows
func run() -> void:
 role=OS.get_cmdline_user_args()[0]
 if OS.get_cmdline_user_args().size()>1 and OS.get_cmdline_user_args()[1] in ["quake","doom"]:rules=OS.get_cmdline_user_args()[1]
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 Fixture.box(game,Fixture.ORIGIN+Vector3(0,-.5,-60),Vector3(30,1,140))
 if role=="server":await authority()
 else:await client()
 print("ROCKET_TRIGGER_NETWORK_RESULT ",JSON.stringify({"role":role,"rules":rules,"failures":failures}))
 game.disconnect_game();game.free();await pause(.1);quit(0 if failures.is_empty() else 1)
func authority():
 game.dedicated=true;game.bind_address="127.0.0.1";game.armory.select(rules);game.start_host("Trigger test",28993,100,60,false,"dm",rules)
 check(game.armory.kind==rules,"Authority explicitly selects "+rules+" weapons")
 check(await wait_for(func():return game.players.size()==1,20),"Real client admitted")
 if game.players.is_empty():return
 game.set_physics_process(false);game.set_process(false)
 var id:int=game.players.keys()[0];var s:Dictionary=game.players[id];var actor=game.fighters[id]
 for index in cases().size():
  var row:Dictionary=cases()[index]
  s.merge({"weapon":6,"owned":[0,2,6],"hp":100,"armor":0,"ammo":[200,100,100,100],"dead":false,"spectator":false,"invulnerable":0.,"fire":false,"alt_fire":false,"cooldown":0.,"input_blocked":false,"jump":false,"xr":{},"vr_device":false,"move":Vector2.ZERO},true)
  actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO;actor.jump_held=false;actor.jump_queued=false
  for i in 4:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1./60.)
  var shots:int=s.shots;game._send_snapshot();game._announcement.rpc("TRIGGER_CASE_"+str(index))
  var apex:=0.;var upward:=0.;var takeoffs:=0;var grounded:=true;var clipped:=false;var landed:=false
  var received_before:int=s.get("fire_received",0);var cooldown_armed:=false;var cooldown_until:=-1.;var shot_at:=-1.
  for i in 220:
   await physics_frame
   if row.has("cooldown") and not cooldown_armed and s.get("fire_received",0)>received_before:
    s.cooldown=row.cooldown;cooldown_armed=true;cooldown_until=game.clock+row.cooldown
   game.clock+=1./60.;game._server_tick(1./60.);game._send_snapshot();apex=maxf(apex,actor.position.y-Fixture.ORIGIN.y);upward=maxf(upward,actor.velocity.y)
   if shot_at<0 and s.shots>shots:shot_at=game.clock
   if not s.xr.is_empty():clipped=clipped or game._shot_solution(id).clipped
   if grounded and not actor.is_supported():takeoffs+=1
   if not grounded and actor.is_supported():landed=true
   grounded=actor.is_supported()
  check(s.shots==shots+int(row.rocket) and s.ammo[2]==100-int(row.rocket),"Exact shot/ammo count: "+row.name)
  check(s.hp>0 and (s.hp<100 if row.rocket else s.hp==100) and apex>(2. if row.rocket else 1.),"Expected jump height and self damage: "+row.name)
  check(s.vr_device==row.vr and landed,"Expected input path and return to ground: "+row.name)
  if row.get("moving",false):check(takeoffs==2 and actor.position.z<Fixture.ORIGIN.z-10,"Ordinary moving hop followed by rocket jump: "+row.name)
  if row.get("low",false):check(clipped,"Floor-intersecting muzzle is safely retracted: "+row.name)
  if row.has("cooldown"):check(cooldown_armed and shot_at>=cooldown_until-.001 and shot_at<=cooldown_until+.035,"Buffered tap preserves cooldown and fires promptly when ready")
  print("ROCKET_TRIGGER_METRICS ",JSON.stringify({"rules":rules,"case":row,"apex_m":apex,"max_upward_mps":upward,"self_damage":100-s.hp,"shots":s.shots-shots,"distance_m":Vector2(actor.position.x-Fixture.ORIGIN.x,actor.position.z-Fixture.ORIGIN.z).length(),"takeoffs":takeoffs,"landed":landed,"clipped":clipped}))
 game._announcement.rpc("TRIGGER_DONE");await pause(.3)
func client():
 game.start_join("Trigger client","127.0.0.1",28993)
 check(await wait_for(func():return game.active and not game.local_state().is_empty(),20),"Client joins")
 check(game.armory.kind==rules,"Client receives "+rules+" weapons")
 game.set_physics_process(false);game.set_process(false)
 var seq:=10000;var delivery:=Delivery.new();var jumping:=JumpDelivery.new()
 for index in cases().size():
  var row:Dictionary=cases()[index];var queued:Array=[]
  check(await wait_for(func():return game.feed.any(func(e):return e.text=="TRIGGER_CASE_"+str(index))),"Case synchronised %d"%index)
  var fire_tick:int=75+int(row.get("phase",0)) if row.get("moving",false) else 5
  var observed_apex:=0.
  for tick in 205:
   var jumping_now:bool=(not row.rocket and tick==5) or (row.get("moving",false) and (tick==5 or tick==fire_tick))
   var cmd:Dictionary={"seq":seq,"map_epoch":game.map_epoch,"input_life":game.local_state().serial,"move":Vector2(0,-1) if row.get("moving",false) else Vector2.ZERO,"yaw":0.,"pitch":-PI/2,"fire":row.rocket and tick==fire_tick,"weapon":6,"slow":false,"respawn":false,"jump":jumping_now}
   if row.vr:
    var pose:=preload("res://deathmatch/vr/poses.gd").neutral();pose.right.origin=Vector3(.25,.45 if row.get("low",false) else 1.2,-.3);pose.weapon=Transform3D(Basis(Vector3.RIGHT,-PI/2),pose.right.origin);cmd.xr=pose
   delivery.sample(cmd,game.local_state().serial,tick/60.)
   jumping.sample(cmd,game.local_state().serial,tick/60.)
   if tick%2==0:
    delivery.annotate(cmd,tick/60.);jumping.annotate(cmd,tick/60.)
    # Drop the first packet carrying the edge, including an already released trigger.
    if not (row.get("drop",false) and tick==fire_tick+fire_tick%2):queued.append({"at":tick+int(row.get("delay",0)),"packet":Codec.pack(cmd)})
   while not queued.is_empty() and queued[0].at<=tick:game._input_packet.rpc_id(1,queued.pop_front().packet)
   var replica=game.fighters.get(game.multiplayer.get_unique_id())
   if tick>10 and replica:observed_apex=maxf(observed_apex,replica.target.y-Fixture.ORIGIN.y)
   seq+=1;await physics_frame
  check(observed_apex>(2. if row.rocket else 1.),"Owning client receives authoritative jump height: "+row.name)
  check(game.local_state().hp<100 if row.rocket else game.local_state().hp==100,"Owning client receives authoritative health: "+row.name)
 check(await wait_for(func():return game.feed.any(func(e):return e.text=="TRIGGER_DONE"),10),"Server completes all rocket cases")
