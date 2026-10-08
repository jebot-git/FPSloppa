extends "res://deathmatch/tests/network_runner.gd"
class Observer extends Node:
 var expected:=-1
 var acknowledged:=false
 var done:=false
 @rpc("authority","call_local","reliable")
 func damage(hp: int):expected=hp
 @rpc("any_peer","call_remote","reliable")
 func acknowledge():
  if multiplayer.is_server():acknowledged=true
 @rpc("authority","call_local","reliable")
 func finish():done=true
var observer: Observer
func run():
 role=OS.get_cmdline_user_args()[0]
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 observer=Observer.new();observer.name="CoverObserver";game.add_child(observer)
 if role=="server":
  game.dedicated=true;game.bind_address="127.0.0.1";game.selected_map="de_varq_inferno"
  game.start_host("Converted cover",28979,100,10,false,"de");game.set_physics_process(false);game.set_process(false)
  check(await wait_for(func():return game.players.size()==1,25),"Remote player joins converted Inferno")
  if game.players.size()==1:
   peer_id=game.players.keys()[0];game.match_mode.kind="dm";game.armory.select("cs16");game.variant_combat.reset();game._add_player(-9,"Wallbang shooter")
   var shooter: Dictionary=game.players[-9];var victim: Dictionary=game.players[peer_id]
   for state in [shooter,victim]:state.merge({"dead":false,"spectator":false,"hp":1000,"armor":0,"invulnerable":0.,"weapon":6,"owned":[0,6],"ammo":[60,0,90,0],"cooldown":0.,"held":false,"fire":false,"input_blocked":false,"yaw":0.,"pitch":0.,"last_input":game.clock,"xr":{}},true)
   shooter.team=0;victim.team=1
   var pen=game.get_node("Map/MapRuntime").ballistics;var cover=pen.bsp_cover;var candidate: Dictionary={};var space: PhysicsDirectSpaceState3D=game.get_world_3d().direct_space_state
   for model in cover.models:
    for i in range(int(model.faces[0]),int(model.faces[0]+model.faces[1])):
     var face: Dictionary=cover.faces[i]
     if face.material!="wood":continue
     var normal: Vector3=cover.planes[face.plane].normal*(1 if face.side==0 else -1)
     if absf(normal.y)>.05:continue
     var center:=Vector3.ZERO;var low:=INF;var high:=-INF
     for p in face.polygon:center+=p;low=minf(low,p.y);high=maxf(high,p.y)
     if high-low<2.:continue
     center=center/face.polygon.size()+model.node.global_position
     var hit: Dictionary=space.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*.04,center-normal*.04,1))
     if hit.is_empty() or hit.position.distance_to(center)>.01:continue
     var passage: Dictionary=pen.exit_surface(hit.position,-normal,39./32,space)
     if passage.is_empty() or passage.retention!=.6:continue
     if not space.intersect_ray(PhysicsRayQueryParameters3D.create(center+normal*2,center+normal*.05,1)).is_empty():continue
     if not space.intersect_ray(PhysicsRayQueryParameters3D.create(passage.position,passage.position-normal,1)).is_empty():continue
     candidate={"entry":hit.position,"exit":passage.position,"normal":normal};break
    if not candidate.is_empty():break
   check(not candidate.is_empty(),"Find actual thin wooden cover with clear space on both sides")
   if not candidate.is_empty():
    var normal: Vector3=candidate.normal;var direction: Vector3=-normal;shooter.yaw=atan2(-direction.x,-direction.z)
    game.fighters[-9].position=candidate.entry+normal*2-Vector3.UP*1.5;game.fighters[peer_id].position=candidate.exit-normal-Vector3.UP*1.5
    preload("res://deathmatch/tests/fixture.gd").box(game,game.fighters[-9].position-Vector3.UP*.05,Vector3(.8,.1,.8))
    await physics_frame;await physics_frame
    for settle in 8:
     game.fighters[-9].simulate(Vector2.ZERO,shooter.yaw,false,1./60);await physics_frame
    game.fighters[-9].reset_view();game.fighters[-9].rotation.y=shooter.yaw
    game.clock+=1;shooter.last_input=game.clock
    game.history.clear()
    var before: int=shooter.ammo[2]
    print("COVER_SHOT_DEBUG ",candidate," shooter=",game.fighters[-9].position," victim=",game.fighters[peer_id].position," solution=",game._shot_solution(-9)," aim=",game._weapon_transform(-9))
    var origin: Vector3=game._shot_solution(-9).origin
    print("COVER_TRACE_DEBUG ",pen.trace(game,origin,origin+direction*8,-9,0,6))
    check(game.variant_combat.cs.shoot(-9) and victim.hp<1000,"Authoritative AK shot damages a remote player through converted wood")
    check(shooter.ammo[2]==before-1,"Wallbang consumes one cartridge")
    observer.damage.rpc(int(victim.hp))
    var deadline:=Time.get_ticks_msec()+6000
    while Time.get_ticks_msec()<deadline and not observer.acknowledged:game.clock+=.05;game._send_snapshot();await pause(.05)
    check(observer.acknowledged,"Remote peer confirms authoritative penetrated damage")
  observer.finish.rpc();await pause(.3)
 else:
  await pause(2);game.start_join("Cover remote","127.0.0.1",28979)
  check(await wait_for(func():return game.active and game.local_state().get("serial",0)>0,25),"Client loads converted Inferno")
  game.set_physics_process(false);game.set_process(false)
  check(game.get_node("Map/MapRuntime").ballistics.ready,"Client binds matching BSP cover profile")
  check(await wait_for(func():return observer.expected>=0,15),"Client receives damage expectation")
  check(await wait_for(func():return observer.expected<1000 and game.local_state().hp==observer.expected,6),"Health snapshot matches wallbang damage")
  observer.acknowledge.rpc_id(1)
  check(await wait_for(func():return observer.done,6),"Scenario completes")
 var report:={"role":role,"failures":failures,"passed":failures.is_empty()}
 FileAccess.open("res://tools/de_penetration/network-"+role+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("CONVERTED_COVER_NETWORK ",JSON.stringify(report));game.disconnect_game();game.free();quit(0 if failures.is_empty() else 1)
