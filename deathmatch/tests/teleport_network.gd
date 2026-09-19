extends "res://deathmatch/tests/network_runner.gd"
class Barrier extends Node:
 var arrived: Dictionary={}
 @rpc("any_peer","call_remote","reliable")
 func acknowledge(phase: String) -> void:
  if multiplayer.is_server():arrived[phase+":"+str(multiplayer.get_remote_sender_id())]=true
var barrier: Barrier
func seen(label: String) -> bool:return game.feed.any(func(e):return e.text==label)
func input(life: int,seq: int,yaw: float) -> Dictionary:
 return {"map_epoch":game.map_epoch,"input_life":life,"seq":seq,"move":Vector2(0,-1),"yaw":yaw,"pitch":0.,"fire":false,"weapon":2,"slow":false,"respawn":false}
func run() -> void:
 role=OS.get_cmdline_user_args()[0]
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 barrier=Barrier.new();barrier.name="TeleportBarrier";root.add_child(barrier)
 if role=="server":await authority()
 else:await client()
 print("TELEPORT_NETWORK_RESULT ",role," ",JSON.stringify(failures))
 game.disconnect_game();await pause(.1);game.free();quit(0 if failures.is_empty() else 1)
func authority() -> void:
 game.dedicated=true;game.selected_map="qsrc_dm1";game.start_host("Teleport network",27897,100,10,false)
 check(await wait_for(func():return game.players.size()==2,20),"Two clients join the portal test server")
 if game.players.size()!=2:return
 game.set_physics_process(false);game.set_process(false);Fixture.setup(game)
 var runtime=game.get_node("Map/MapRuntime");runtime.set_physics_process(false)
 var traveler: int=game.players.keys().filter(func(id):return game.players[id].name=="traveler")[0]
 var s: Dictionary=game.players[traveler];var actor=game.fighters[traveler]
 for id in game.players:
  game.players[id].dead=false;game.players[id].spectator=id!=traveler;game.fighters[id].position=Fixture.point(15,15)
 actor.position=Fixture.point(-8,0)+Vector3.UP*.05;actor.velocity=Vector3.ZERO
 s.yaw=0.;s.xr={};s.invulnerable=0.;s.move=Vector2.ZERO;s.serial+=1
 var old_life: int=s.serial
 var portal:=Area3D.new();portal.position=actor.position+Vector3.UP*.8;portal.collision_layer=0;portal.collision_mask=2
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1,2,1);shape.shape=box;portal.add_child(shape);game.add_child(portal)
 runtime.regions=[{"kind":"trigger_teleport","area":portal,"data":{"target":"exit"}}]
 var destination:=Fixture.point()+Vector3.UP*.05
 runtime.destinations={"exit":{"position":destination,"yaw":PI/2}}
 game._send_snapshot();game._announcement.rpc("PORTAL_READY")
 check(await wait_for(func():return game.players.keys().all(func(id):return barrier.arrived.has("ready:"+str(id))),10),"Both clients receive the pre-teleport life")
 await physics_frame;await physics_frame;runtime._physics_process(1./60.)
 check(s.serial==old_life+1 and actor.position==destination and s.yaw==PI/2,"Authority teleports with the destination heading")
 # Intentionally withhold the new snapshot while the owner sends old input.
 game._announcement.rpc("PORTAL_STALE")
 check(await wait_for(func():return barrier.arrived.has("stale:"+str(traveler)),8),"Owner sends delayed entrance input before receiving the warp")
 await pause(.15)
 check(s.yaw==PI/2 and s.move==Vector2.ZERO and actor.position==destination,"Stale ENet input leaves exit position and facing intact")
 game._send_snapshot();game._announcement.rpc("PORTAL_WARPED")
 check(await wait_for(func():return game.players.keys().all(func(id):return barrier.arrived.has("warped:"+str(id))),10),"Owner and observer confirm the replicated exit")
 game._announcement.rpc("PORTAL_FRESH")
 check(await wait_for(func():return s.last_seq>=100002,8),"Input carrying the new life is accepted")
 check(is_equal_approx(s.yaw,.25) and s.move!=Vector2.ZERO,"Owner can turn and walk normally after the warp")
 game._announcement.rpc("PORTAL_DONE");await pause(.3)
func client() -> void:
 game.start_join(role,"127.0.0.1",27897)
 check(await wait_for(func():return game.active and not game.local_state().is_empty(),20),"Client joins and receives state")
 game.set_physics_process(false);game.set_process(false)
 game.get_node("Map/MapRuntime").set_physics_process(false)
 check(await wait_for(func():return seen("PORTAL_READY"),10),"Pre-teleport state arrives")
 var traveler: int=game.players.keys().filter(func(id):return game.players[id].name=="traveler")[0]
 var old_life: int=game.players[traveler].serial
 barrier.acknowledge.rpc_id(1,"ready")
 check(await wait_for(func():return seen("PORTAL_STALE"),10),"Stale-input phase begins")
 if role=="traveler":
  game._input_command.rpc_id(1,input(old_life,100001,PI));barrier.acknowledge.rpc_id(1,"stale")
 check(await wait_for(func():return seen("PORTAL_WARPED") and game.players[traveler].serial>old_life,10),"Teleport serial reaches replica")
 check(game.fighters[traveler].position.distance_to(Fixture.point()+Vector3.UP*.05)<.01 and is_equal_approx(game.players[traveler].yaw,PI/2),"Replica receives exact exit position and facing")
 if role=="traveler":check(is_equal_approx(game.local_yaw,PI/2),"Owning camera adopts the server's exit heading")
 barrier.acknowledge.rpc_id(1,"warped")
 check(await wait_for(func():return seen("PORTAL_FRESH"),8),"Fresh-input phase begins")
 if role=="traveler":game._input_command.rpc_id(1,input(game.players[traveler].serial,100002,.25))
 check(await wait_for(func():return seen("PORTAL_DONE"),8),"Teleport network scenario completes")
