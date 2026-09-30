extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures:Array=[]
func check(ok:bool,label:String):
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
 var game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game);Fixture.setup(game)
 game.start_host("Flame coverage",0,100,60,true,"tf","quake")
 game.bots.free();game.bots=null;game.set_process(false);game.set_physics_process(false)
 var s:Dictionary=game.players[1];s.tf_class="pyro";s.team=0;s.weapon=7;s.owned=[7];s.ammo=[0,0,0,100];s.invulnerable=0.;s.pitch=0.;s.yaw=0.;s.xr={};s.vr_device=false
 game.fighters[1].position=Fixture.point()
 for id in game.players:
  if id==1:continue
  game.players[id].spectator=id!=-1;game.players[id].team=1;game.players[id].armor=0;game.players[id].invulnerable=0.;game.players[id].hp=1000
  game.fighters[id].position=Fixture.point(15,15)
 await physics_frame;await physics_frame
 for rules in ["quake","doom"]:
  game.armory.select(rules);s.ammo=[0,0,0,100]
  for offset in [0.,.5]:
   game.fighters[-1].position=Fixture.point(offset,-5);game.players[-1].hp=1000;s.cooldown=0.
   game._fire(1)
   check(game.players[-1].hp==992,"Flame covers x=%.2f with exactly one 8-damage dose"%offset)
  var wall:=Fixture.box(game,Fixture.point(.65,-2.5)+Vector3.UP,Vector3(2,2,.05))
  await physics_frame;await physics_frame
  game.players[-1].hp=1000;s.cooldown=0.;game._fire(1)
  check(game.players[-1].hp==1000,"Thin cover blocks every flame sample")
  wall.free();game.fighters[-1].position=Fixture.point(0,-9);s.cooldown=0.;game._fire(1)
  check(game.players[-1].hp==1000,"Flame cannot exceed its eight-metre range")
  check(s.ammo[3]==96,"Cone costs one cell per attempt, not per ray")
 game.disconnect_game();game.free();await process_frame
 print("FLAME_COVERAGE_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
