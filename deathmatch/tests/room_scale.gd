extends SceneTree
const Room=preload("res://deathmatch/vr/room_scale.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
func check(ok: bool,label: String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
 check(Room.request(Vector3(.1,1.65,0)).is_equal_approx(Vector3(.08,0,0)),"Small room-scale motion moves capsule with only 2 cm tolerance")
 check(Room.request(Vector3(.8,1.65,0))==Vector3.ZERO,"Tracking displacement beyond fixed limit cannot move capsule")
 var pose:=Poses.neutral();pose.head.origin.x=.3
 check(Room.validate(Vector3(-10,4,0),pose)==Vector3.ZERO,"Room request cannot move away from headset or move vertically")
 check(Room.validate(Vector3(10,4,0),pose).is_equal_approx(Vector3(.08,0,0)),"Room request is capped to 2.4 metres per second")
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.set_process(false);game.set_physics_process(false)
 game.hud=load("res://deathmatch/interface.gd").new();game.add_child(game.hud);game.hud.setup(game)
 game.xr_rig=load("res://deathmatch/vr/rig.gd").new();game.add_child(game.xr_rig);game.xr_rig.setup(game,true)
 var rig=game.xr_rig;rig.set_process(false);rig.calibration_pending=false;rig.tracking.enabled=false
 game._add_player(1,"Room");game.active=true;game.menu_open=false;game.local_yaw=0
 var actor=game.fighters[1];actor.position=Fixture.point();actor.velocity=Vector3.ZERO
 rig.origin_offset=Vector3.ZERO;rig.head.position=Vector3(.3,1.65,0);rig._process(0)
 var head_world:Vector3=rig.head.global_position
 var weapon_steady:=true
 for i in range(20):
  await physics_frame
  rig._process(0)
  var command:Dictionary=rig.command(i);game._accept_input(1,command)
  var weapon_before:Vector3=game._weapon_transform(1).origin
  game.clock+=1.0/60;game._server_tick(1.0/60);rig._process(0)
  weapon_steady=weapon_steady and game._weapon_transform(1).origin.distance_to(weapon_before)<.01
 check(absf(actor.position.x-Fixture.ORIGIN.x-.28)<.012,"Authoritative movement aligns capsule below headset")
 check(Vector2(rig.head.global_position.x,rig.head.global_position.z).distance_to(Vector2(head_world.x,head_world.z))<.001,"Capsule alignment preserves physical headset horizontal position")
 check(weapon_steady,"Authoritative weapon pose is rebased with capsule movement")
 var hit:Dictionary=game._trace(Fixture.point(.28,-2)+Vector3.UP,Fixture.point(.28,2)+Vector3.UP,2)
 check(hit.id==1,"Damage capsule follows room-scale movement")
 Fixture.box(game,Fixture.point(.6)+Vector3.UP*1.5,Vector3(.1,3,4))
 actor.position=Fixture.point();actor.velocity=Vector3.ZERO;rig.origin_offset=Vector3.ZERO;rig.head.position.x=.7;rig._process(0)
 head_world=rig.head.global_position
 for i in range(20,45):
  await physics_frame
  rig._process(0);game._accept_input(1,rig.command(i));game.clock+=1.0/60;game._server_tick(1.0/60);rig._process(0)
 check(actor.position.x<Fixture.ORIGIN.x+.3,"Room-scale capsule cannot pass through wall")
 check(rig.head.global_position.distance_to(head_world)<.01 and rig.blackout.visible,"Blocked movement preserves tracking origin and activates head-wall fade")
 game.local_yaw=0;rig.turn_speed=180;rig.smooth_turn=true;rig.apply_turn(1,.5)
 check(absf(game.local_yaw+PI/2)<.001,"Smooth turn uses configured degrees per second")
 rig.smooth_turn=false;rig.snap_angle=45;rig.turn_latched=false;game.local_yaw=0
 rig.apply_turn(1,.016);rig.apply_turn(1,.016)
 check(absf(game.local_yaw+PI/4)<.001,"Snap angle is configurable and held stick turns once")
 rig.apply_turn(0,.016);rig.apply_turn(1,.016)
 check(absf(game.local_yaw+PI/2)<.001,"Snap turn rearms after stick release")
 check(rig.status_surface.get_parent()==rig.head and rig.status_surface.visible,"HUD floats in view independently of either hand")
 rig.status_hud.update_status({"hp":25,"armor":50,"weapon":0,"ammo":[0,0,0,0],"dead":false},61,20,7,false,false)
 check(rig.status_hud.values.ammo==-1 and rig.status_hud.values.frags==13 and rig.status_hud.values.seconds==61,"HUD handles melee ammunition and remaining match limits")
 rig.focused=false;rig._process(0);check(not rig.status_surface.visible,"HUD hides on headset focus loss")
 game.free();await create_timer(.25).timeout
 print("ROOM_SCALE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
