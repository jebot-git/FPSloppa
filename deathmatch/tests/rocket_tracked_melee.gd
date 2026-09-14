extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.start_host("Tracked rocket",0,100,60,true,"dm","doom");game.set_physics_process(false);game.set_process(false)
 if is_instance_valid(game.bots):game.bots.free();game.bots=null
 for id in game.players.keys():
  if id<0:game._peer_left(id)
 game._add_player(-99,"Melee target")
 var actor=game.fighters[1];var s:Dictionary=game.players[1];var target:Dictionary=game.players[-99]
 for rules in ["doom","quake"]:
  game.armory.select(rules)
  for scenario in ["aim_sweep","foot_motion","melee_contact"]:
   game._spawn(1);game._spawn(-99)
   s.merge({"weapon":6,"owned":[6],"hp":100,"armor":0,"ammo":[100,100,100,100],"invulnerable":0.,"cooldown":0.,"vr_device":true,"melee":true,"yaw":0.,"pitch":0.},true)
   target.invulnerable=0.;target.armor=0;target.fire=false;target.melee=false
   actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO
   game.fighters[-99].position=Fixture.point(0,-.85) if scenario=="melee_contact" else Fixture.point(-8,-8)
   for i in 4:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1./60.)
   var pose:=Poses.neutral();pose.right.origin=Vector3(0,1.2,-.6);pose.weapon=Transform3D(Basis(Vector3.RIGHT,-PI/2),pose.right.origin)
   if scenario=="foot_motion":pose.body={"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.15,.3,-.3))}
   var shots:int=s.shots
   for tick in 2:
    if tick==1:
     if scenario=="foot_motion":pose.body.left_foot.origin.z-=.08
     else:pose.right.origin.x+=.08;pose.weapon.origin=pose.right.origin
    s.xr=pose.duplicate(true);s.last_seq+=1;s.last_input=game.clock;s.fire=tick==1
    await physics_frame;game.clock+=1./60.;game._server_tick(1./60.)
   if scenario=="melee_contact":
    check(target.hp==90 and s.shots==shots and s.cooldown>0,rules+" confirmed melee contact still blocks simultaneous shooting")
   else:
    check(s.melee_ready_at>game.clock,rules+" fixture detects a tracked "+scenario)
    check(s.shots==shots+1 and s.ammo[2]==99,rules+" empty tracked "+scenario+" cannot discard a ready rocket")
   print("ROCKET_TRACKED_MELEE_METRICS ",JSON.stringify({"rules":rules,"case":scenario,"shots":s.shots-shots,"cooldown":s.cooldown,"target_hp":target.hp}))
   for id in game.projectiles.keys():game._projectile_end(id,game.projectiles[id].position,6)
 game.disconnect_game();game.free();await process_frame
 print("ROCKET_TRACKED_MELEE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
