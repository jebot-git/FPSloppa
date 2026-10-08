extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
var checks:=0
func check(ok: bool,label: String):
 checks+=1;print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.selected_map="de_varq_santorini";game.start_host("DE awareness",0,100,30,true,"de","cs16")
 game.set_process(false);game.set_physics_process(false);Fixture.setup(game)
 var ai=game.bots;var native=ai.native_ai
 for id in game.players:
  game.players[id].spectator=id not in [-1,1]
  game.fighters[id].position=Fixture.point(18,18)
  game.fighters[id].collision_layer=0 if game.players[id].spectator else 2
 var s: Dictionary=game.players[-1];var target: Dictionary=game.players[1]
 s.merge({"team":0,"dead":false,"spectator":false,"owned":[0,6],"weapon":6,"ammo":[100,100,100,100],"yaw":0.,"pitch":0.,"hp":100,"armor":0,"invulnerable":0.},true)
 target.merge({"team":1,"dead":false,"spectator":false,"hp":1000,"invulnerable":0.},true)
 game.match_mode.defusal.phase="live";game.match_mode.defusal.utility.states.clear()
 var ai_actor=game.fighters[-1];var enemy=game.fighters[1]
 ai_actor.position=Fixture.point();enemy.position=Fixture.point(0,-12)
 for frame in 3:await physics_frame
 for accelerated in [false,true]:
  ai.native_ai=native if accelerated else null
  var brain: Dictionary=ai.new_brain(-1);ai.brains[-1]=brain;s.yaw=0;s.pitch=0
  ai.perceive(-1,brain)
  check(brain.enemy==1,"Front enemy acquired "+str(accelerated))
  var fired:=false
  for frame in 60:
   game.clock+=1./60;ai.combat(-1,brain,1./60)
   if s.fire:fired=true;break
  check(fired,"Visible front enemy receives a normal reaction and firing input "+str(accelerated))
  var cover_height: float=(ai_actor.eye_height()+enemy.torso_height())*.5+.04
  var cover=Fixture.box(game,Fixture.point(0,-6)+Vector3.UP*(cover_height*.5),Vector3(4,cover_height,.35))
  for frame in 3:await physics_frame
  brain=ai.new_brain(-1);ai.brains[-1]=brain;ai.perceive(-1,brain)
  check(brain.enemy==1 and brain.get("exposed_offset",Vector3.ZERO).y>ai_actor.torso_height(),"Head visible over low cover is acquired and selected for aim "+str(accelerated))
  cover.free()
  var friend=game.fighters[-2];var friendly: Dictionary=game.players[-2]
  friendly.team=0;friendly.dead=false;friendly.spectator=false;friend.collision_layer=2;friend.position=Fixture.point(0,-6)
  for frame in 3:await physics_frame
  brain=ai.new_brain(-1);ai.brains[-1]=brain;ai.perceive(-1,brain)
  check(brain.enemy==1 and not ai.safe_shot(-1,ai.target_position(1)),"Teammate permits awareness but blocks firing lane "+str(accelerated))
  friendly.spectator=true;friend.collision_layer=0;friend.position=Fixture.point(18,18)
  enemy.position=Fixture.point(0,12);s.yaw=0;brain=ai.new_brain(-1);ai.brains[-1]=brain
  for frame in 3:await physics_frame
  ai.perceive(-1,brain);check(brain.enemy==0,"Silent rear enemy stays outside FOV "+str(accelerated))
  game._damage(-1,1,5,"AK47",false,ai_actor.position+Vector3.UP,Vector3.FORWARD)
  check(float(s.get("bot_hurt_until",0))>game.clock,"Real damage publishes an expiring direction cue "+str(accelerated))
  var acquired:=false
  for frame in 90:
   game.clock+=1./60;ai.awareness.before(ai,-1,brain,1./60)
   if frame%6==0:ai.perceive(-1,brain)
   ai.combat(-1,brain,1./60)
   if brain.enemy==1:acquired=true;break
  check(acquired,"Rear hit turns attention and then requires visual acquisition "+str(accelerated))
  brain=ai.new_brain(-1);ai.brains[-1]=brain;s.yaw=0;s.bot_hurt_until=game.clock+1.1;s.bot_hurt_direction=Vector3.BACK;s.bot_hurt_serial=s.serial;s.bot_hurt_at=game.clock
  var wall=Fixture.box(game,Fixture.point(0,6)+Vector3.UP*2,Vector3(6,4,.4))
  for frame in 3:await physics_frame
  for frame in 30:
   game.clock+=1./60;ai.awareness.before(ai,-1,brain,1./60);ai.perceive(-1,brain);ai.combat(-1,brain,1./60)
  check(brain.enemy==0 and not s.fire and brain.last_seen_at<0,"Damage cue grants neither wall vision nor blind wallbang memory "+str(accelerated))
  var heading: float=s.yaw;brain.goal=Fixture.point(10,0);brain.goal_kind="roam";ai.steer(-1,brain,1./60)
  check(is_equal_approx(s.yaw,heading),"Travel steering preserves hurt-direction attention "+str(accelerated))
  s.bot_hurt_until=game.clock+1;game.match_mode.defusal.carrier=-1;game.match_mode.defusal.held=true
  check(not game.match_mode.defusal.bot_input(-1) and not game.match_mode.defusal.held,"Hit interrupts bomb interaction "+str(accelerated))
  s.bot_hurt_until=game.clock-1;brain.enemy=0;ai.awareness.before(ai,-1,brain,1./60)
  check(not brain.hurt_tracking,"Expired damage cue stops steering "+str(accelerated))
  s.bot_hurt_until=game.clock+1;s.bot_hurt_serial=s.serial-1;ai.awareness.before(ai,-1,brain,1./60)
  check(not brain.hurt_tracking,"Previous life damage cue cannot steer respawn "+str(accelerated))
  wall.free();enemy.position=Fixture.point(0,-12);s.bot_hurt_until=0
  for frame in 3:await physics_frame
 ai.native_ai=native
 DirAccess.make_dir_recursive_absolute("res://test-results/de-awareness")
 FileAccess.open("res://test-results/de-awareness/validation.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 game.free();print("DE_AWARENESS_RESULT ",checks," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
