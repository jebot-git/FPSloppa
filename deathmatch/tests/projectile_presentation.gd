extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Art=preload("res://deathmatch/art.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
 g.start_host("Projectile presentation",0,100,10,true,"dm","quake");g.set_physics_process(false);g.set_process(false)
 if is_instance_valid(g.bots):g.bots.free();g.bots=null
 for id in g.players.keys():
  if id<0:g._peer_left(id)
 await physics_frame;await physics_frame
 var rig=g.xr_rig;g.local_yaw=0.;rig.set_process(false);rig.calibration_pending=false;rig.seated=false;rig.origin_offset=Vector3.ZERO;rig.origin.transform=Transform3D.IDENTITY
 var actor=g.fighters[1];var s:Dictionary=g.players[1]
 for slot in [4,5,6,7]:
  actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.reset_view();s.dead=false;s.spectator=false;s.input_blocked=false;s.invulnerable=0.;s.weapon=slot;s.owned=[slot];s.ammo=[200,100,100,100];s.cooldown=0.;g.desired_weapon=slot
  rig.head.position=Vector3(0,1.65,0);rig.right.position=Vector3(.25,1.2,-.3);rig.right_aim.transform=rig.right.transform
  rig._process(1./60.)
  s.xr=rig.sample_pose();s.vr_device=true;s.yaw=0.
  var visible:Vector3=rig.gun.global_transform*Art.muzzle(slot,"quake")
  # Authority advances one tick before the tracked first-person render catches up.
  actor.position.x+=9.4/60.
  var authoritative:Vector3=g._shot_solution(1).origin
  check(authoritative.distance_to(visible)>.15,"Fixture reproduces moving barrel lag for slot "+str(slot))
  check(g.variant_combat.fire(1),"Quake projectile launches for slot "+str(slot))
  var projectile:Dictionary=g.projectiles[g.projectile_id]
  check(projectile.position.distance_to(authoritative)<.001,"Collision starts at authoritative muzzle for slot "+str(slot))
  check(projectile.previous_position.distance_to(visible)<.001,"First visual sample starts at visible barrel for slot "+str(slot))
  g._update_projectiles(1./60.);g._update_projectile_visuals(1./90.)
  var start:Vector3=projectile.previous_position;var end:Vector3=projectile.position
  var shown:Vector3=projectile.node.global_position
  check(shown.distance_to(Geometry3D.get_closest_point_to_segment(shown,start,end))<.001,"Rendered projectile follows the single interpolated launch segment for slot "+str(slot))
  check(projectile.node.get_global_transform_interpolated().origin.distance_to(shown)<.001,"No second interpolation displaces projectile from rendered segment for slot "+str(slot))
  var prior:Vector3=projectile.position;g._update_projectiles(1./60.)
  check(projectile.previous_position.distance_to(prior)<.001,"Following flight samples preserve physical continuity for slot "+str(slot))
  g._projectile_end(g.projectile_id,projectile.position,slot)
  await process_frame
 g.disconnect_game();g.free();await process_frame
 print("PROJECTILE_PRESENTATION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
