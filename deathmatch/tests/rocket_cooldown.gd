extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
class TestBindings extends "res://deathmatch/settings/bindings.gd":
 var firing:=false
 func pressed(action:String) -> bool:return action=="fire" and firing
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.start_host("Rocket cooldown",0,100,60,true,"dm","quake");game.set_physics_process(false);game.set_process(false)
 if is_instance_valid(game.bots):game.bots.free();game.bots=null
 for id in game.players.keys():
  if id<0:game._peer_left(id)
 var bindings:=TestBindings.new();game.bindings=bindings
 var actor=game.fighters[1];var s:Dictionary=game.players[1]
 for rules in ["quake","doom"]:
  game.armory.select(rules)
  for scenario in ["early","expired","menu","switch"]:
   game._spawn(1);s.merge({"weapon":6,"owned":[2,6],"hp":100,"armor":0,"ammo":[100,100,100,100],"invulnerable":0.,"cooldown":.4 if scenario=="expired" else .2},true)
   game.desired_weapon=6;game.local_pitch=-PI/2;game.local_yaw=0.;game.menu_open=false
   actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO
   for i in 4:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1./60.)
   var before:int=s.shots;var shot_at:=-1.;var start:float=game.clock
   for tick in 65:
    bindings.firing=tick==0
    if scenario=="menu" and tick==2:game.menu_open=true
    if scenario=="menu" and tick==20:game.menu_open=false
    if scenario=="switch" and tick==2:game.desired_weapon=2
    await physics_frame;game._physics_process(1./60.)
    if shot_at<0 and s.shots>before:shot_at=game.clock-start
   check(s.shots-before==(1 if scenario=="early" else 0),rules+" local one-frame tap: "+scenario)
   if scenario=="early":check(shot_at>=.2-.001 and shot_at<=.235 and s.ammo[2]==99,rules+" fires once when ready without shortening cooldown")
   print("ROCKET_COOLDOWN_METRICS ",JSON.stringify({"rules":rules,"case":scenario,"shots":s.shots-before,"shot_delay_seconds":shot_at}))
 game.disconnect_game();game.free();await process_frame
 print("ROCKET_COOLDOWN_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
