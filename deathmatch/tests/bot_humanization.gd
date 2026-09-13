extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
var game
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
 seed(7129)
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.start_host("Human behavior",0,100,60,true,"dm");game.set_process(false);game.set_physics_process(false)
 Fixture.setup(game)
 for id in [-2,-3]:game.players[id].spectator=true;game.fighters[id].position=Fixture.point(18,18)
 var bots=game.bots;var actor=game.fighters[-1];var s: Dictionary=game.players[-1]
 actor.position=Fixture.point();s.yaw=0;s.pitch=0;s.owned=[2];s.ammo=[100,0,0,0]
 game.fighters[1].position=Fixture.point(0,12)
 var brain: Dictionary=bots.new_brain(-1)
 await physics_frame;bots.perceive(-1,brain)
 check(brain.enemy==0,"Distant enemy behind bot is not acquired through the back of its head")
 game.fighters[1].position=Fixture.point(0,-12)
 await physics_frame;bots.perceive(-1,brain)
 check(brain.enemy==1,"Enemy entering field of view is acquired")
 game.clock=brain.seen_at+.1;bots.combat(-1,brain,1.0/60)
 check(not s.fire,"Newly spotted opponent allows a reaction interval before firing")
 var angles: Array=[]
 for hz in [60,120]:
  s.yaw=.8;s.pitch=.3
  brain=bots.new_brain(-1);brain.enemy=1;brain.seen_at=game.clock-1
  var maximum_step:=0.0
  for frame in hz:
   var before: float=s.yaw
   game.clock+=1.0/hz;bots.combat(-1,brain,1.0/hz)
   maximum_step=maxf(maximum_step,absf(angle_difference(before,s.yaw)))
  angles.append(Vector2(s.yaw,s.pitch))
  check(maximum_step<.13,"Aim turns smoothly at %s Hz"%hz)
 check(angles[0].distance_to(angles[1])<.001,"Aim response is consistent across 60 and 120 Hz physics")
 # Goal replans must not erase evidence of a persistent collision snag.
 brain=bots.new_brain(-1);brain.goal=Fixture.point(0,-12);brain.goal_kind="roam";brain.progress_at=game.clock-2.1
 brain.progress_position=actor.position+Vector3.RIGHT*.1
 bots.steer(-1,brain,1.0/60)
 check(brain.recover_until>game.clock and not brain.recover_direction.is_zero_approx(),"Small collision jitter still triggers ordinary movement recovery")
 # A friend entering a charged rocket's lane cancels instead of releasing into them.
 game.armory.select("ut99");game.match_mode.kind="tdm";s.team=0;s.owned=[6];s.weapon=6;s.ammo=[0,0,10,0];s.cooldown=0;s.input_blocked=false;s.last_input=game.clock
 game.players[1].team=1;game.players[-2].team=0;game.players[-2].spectator=false
 game.fighters[-2].position=Fixture.point(0,-2)
 brain=bots.new_brain(-1);brain.enemy=1;brain.seen_at=game.clock-1
 game.variant_combat.charging[-1]={"weapon":6,"alt":false,"time":.4,"maximum":3.0}
 var shots: int=s.shots
 await physics_frame;bots.combat(-1,brain,1.0/60);game.variant_combat.tick_input(-1,1.0/60)
 check(s.input_blocked and not game.variant_combat.charging.has(-1) and s.shots==shots,"Unsafe charged rocket cancels without firing at a teammate")
 game.match_mode.kind="tf";s.tf_class="soldier";game.match_mode.flags[0].dropped=true;brain.enemy=0
 var rows: Array=[];bots.mode_goals(-1,brain,rows)
 check(not rows.any(func(row):return row.key=="return") and rows.any(func(row):return row.key=="flag:defend" and row.hold),"TF bots guard their dropped flag instead of attempting a touch return")
 game.match_mode.kind="ctf";game.fighters[-1].position=game.match_mode.flags[0].position;rows=[];bots.mode_goals(-1,brain,rows)
 check(rows.any(func(row):return row.key=="return"),"CTF retains the friendly touch-return goal")
 check(not bots.navigation.landing_clear(Fixture.point(9.55,0)) and bots.navigation.landing_clear(Fixture.point()),"Translocator landings leave enough wall clearance to walk away")
 var step=Fixture.box(game,Fixture.point(0,.9)+Vector3.UP*.25,Vector3(2,.5,.8))
 var recovery: Dictionary={}
 await physics_frame
 var direction: Vector3=bots.recovery_direction(Fixture.point(),Vector3.FORWARD,-1,recovery)
 check(direction.z>.9 and recovery.recover_jump,"Recovery uses a checked jump when a low step blocks the retreat")
 step.free()
 game.disconnect_game();game.free();print("BOT_HUMANIZATION_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
