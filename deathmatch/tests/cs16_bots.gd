extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const DT:=1.0/60
var game
var failures: Array=[]
var trials: Array=[]
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run() -> void:
 seed(7129)
 game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
 game.start_host("Weapon trials",0,100,60,true,"dm");game.set_physics_process(false);game.set_process(false)
 Fixture.box(game,Fixture.ORIGIN+Vector3(0,-.5,0),Vector3(150,1,150))
 for id in [-2,-3]:game.players[id].spectator=true;game.fighters[id].position=Fixture.point(60,60)
 var s: Dictionary=game.players[-1];var target: Dictionary=game.players[1]
 for rules in ["cs16"]:
  game.armory.select(rules)
  for weapon in 12:
   var data: Dictionary=game.armory.data(weapon)
   var distance: float=45 if rules=="ut99" and weapon==8 else minf(12,float(data.get("range",100))*.65)
   for key in game.projectiles.keys():game._projectile_end.rpc(key,game.projectiles[key].position,game.projectiles[key].weapon)
   game.variant_combat.reset()
   s.owned=[weapon];s.weapon=weapon;s.ammo=[10000,10000,10000,10000];s.dead=false;s.hp=100000;s.armor=0;s.invulnerable=0;s.cooldown=0;s.charge=0;s.input_blocked=false;s.yaw=0;s.pitch=0;s.alt_fire=false
   target.dead=false;target.spectator=false;target.hp=1000000;target.armor=0;target.invulnerable=0
   game.fighters[-1].position=Fixture.point();game.fighters[-1].velocity=Vector3.ZERO
   game.fighters[1].position=Fixture.point(0,-distance);game.fighters[1].velocity=Vector3.ZERO
   # These are standing accuracy trials. A teleported CharacterBody has no
   # floor contact until it simulates; otherwise every shot gets airborne spread.
   for settle in 10:
    await physics_frame
    for id in [-1,1]:game.fighters[id].simulate(Vector2.ZERO,0,false,DT)
   var brain: Dictionary=game.bots.new_brain(-1);brain.enemy=1;brain.seen_at=game.clock-1;brain.seen_position=game.fighters[1].position
   game.bots.brains[-1]=brain
   var initial: int=s.shots;var alt_ticks:=0
   for frame in 180:
    await physics_frame
    game.clock+=DT;s.last_input=game.clock;s.input_blocked=false;s.cooldown=maxf(0,s.cooldown-DT)
    if s.charge>0:
     s.charge-=DT
     if s.charge<=0:game._launch(-1,8)
    game.bots.combat(-1,brain,DT)
    if s.alt_fire:alt_ticks+=1
    if game.armory.experimental():game.variant_combat.tick_input(-1,DT)
    elif s.fire and s.cooldown<=0:game._fire(-1)
    game._update_projectiles(DT)
   var row: Dictionary={"rules":rules,"weapon":weapon,"name":data.name,"shots":s.shots-initial,"damage":1000000-target.hp,"alt_ticks":alt_ticks}
   trials.append(row);print("BOT_WEAPON_TRIAL ",JSON.stringify(row))
   check((weapon==0 or row.shots>0) and row.damage>0,"%s %s fires and damages through ordinary combat"%[rules,data.name])
 var result: Dictionary={"trials":trials,"failures":failures}
 FileAccess.open("res://test-results/cs16/bots.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 game.disconnect_game();game.free();print("CS16_BOTS_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
