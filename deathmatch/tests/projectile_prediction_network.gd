extends "res://deathmatch/tests/network_runner.gd"
class Sync extends Node:
 var prepared:=false
 var checked:=false
 @rpc("any_peer","call_remote","reliable")
 func mark_ready():
  if multiplayer.is_server():prepared=true
 @rpc("any_peer","call_remote","reliable")
 func mark_checked():
  if multiplayer.is_server():checked=true
func run():
 role=OS.get_cmdline_user_args()[0]
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 var sync:=Sync.new();sync.name="PredictionSync";root.add_child(sync)
 if role=="server":
  game.selected_map="tf_abbeyline";game.dedicated=true;game.bind_address="127.0.0.1"
  game.armory.select("quake")
  game.start_host("Cosmetic handoff",28994,100,60,false,"dm","quake")
  check(await wait_for(func():return game.players.size()==1,20),"client admitted")
  game.set_process(false);game.set_physics_process(false)
  if game.players.is_empty():quit(1);return
  var id:int=game.players.keys()[0];var s:Dictionary=game.players[id]
  s.dead=false;s.spectator=false;s.weapon=6;s.owned=[6];s.ammo=[0,0,50,0];s.xr={};s.yaw=0.;s.pitch=0.
  game.fighters[id].position=Fixture.point();game._send_snapshot();game._announcement.rpc("COSMETIC_READY")
  var deadline:int=Time.get_ticks_msec()+12000
  while not sync.prepared and Time.get_ticks_msec()<deadline:
   game._send_snapshot();await pause(.05)
  check(sync.prepared,"cosmetic prepared before authority")
  var identity:Array=[s.serial,1,1,0,6]
  var d:Dictionary=game.armory.data(6)
  game.variant_combat.launch(id,6,Fixture.point()+Vector3.UP*1.3,Vector3.FORWARD,{"prediction":identity})
  game._send_snapshot()
  check(await wait_for(func():return sync.checked),"client confirms exact handoff")
  game._projectile_end.rpc(game.projectile_id,Fixture.point()+Vector3.FORWARD*2,6)
  await pause(.5)
 else:
  game.start_join("Cosmetic client","127.0.0.1",28994)
  check(await wait_for(func():return game.active and not game.local_state().is_empty(),20),"client joined")
  game.set_process(false);game.set_physics_process(false)
  check(await wait_for(func():return game.feed.any(func(e):return e.text=="COSMETIC_READY")),"launch state received")
  check(await wait_for(func():return game.local_state().owned==[6] and game.armory.kind=="quake"),"owner launch snapshot received")
  var s:Dictionary=game.local_state();var identity:Array=[s.serial,1,1,0,6]
  game.projectile_prediction.add(game,identity,game.armory.data(6),Fixture.point()+Vector3.UP*1.3,Vector3.FORWARD)
  var cosmetic=game.projectile_prediction.flights.values()[0].node
  sync.mark_ready.rpc_id(1)
  check(await wait_for(func():return not game.projectiles.is_empty()),"authoritative projectile arrives")
  if not game.projectiles.is_empty():
   var id:int=game.projectiles.keys()[0];var p:Dictionary=game.projectiles[id]
   check(p.node==cosmetic and game.projectile_prediction.flights.is_empty(),"RPC/snapshot adopts exact cosmetic node: "+str(identity)+" extra="+str(p.extra)+" pending="+str(game.projectile_prediction.flights.keys()))
   game._projectile_spawn(id,p.owner,p.weapon,p.position,p.direction,p.yaw,p.pitch,p.extra)
   check(game.projectiles.size()==1 and game.projectiles[id].node==cosmetic,"duplicate spawn leaves one visual")
  sync.mark_checked.rpc_id(1)
  check(await wait_for(func():return game.projectiles.is_empty()),"authoritative end removes projectile")
 print("PROJECTILE_PREDICTION_NETWORK_RESULT ",JSON.stringify({"role":role,"failures":failures}))
 game.disconnect_game();game.free();sync.free();await process_frame;quit(0 if failures.is_empty() else 1)
