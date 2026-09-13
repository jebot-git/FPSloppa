extends SceneTree
var g
var checks: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:checks.append({"pass":ok,"name":label});print("PASS " if ok else "FAIL ",label)
func run() -> void:
 for profile in ["quake","ut99","doom"]:
  g=load("res://deathmatch/arena.tscn").instantiate()
  g.match_mode.fortress.free();g.match_mode.fortress=preload("res://tools/titanball/simulation/classless.gd").new();g.armory=preload("res://tools/titanball/simulation/rules.gd").new()
  root.add_child(g);g.start_host("Hull contact test",0,100,10,true,"tb",profile);g.set_physics_process(false);g.set_process(false)
  if is_instance_valid(g.bots):g.bots.free();g.bots=null
  var w=g.match_mode.fortress.walkers;w.configure([{"id":"test","team":0,"points":[Vector3(1000,0,0),Vector3(1000,0,100)]}]);var r: Dictionary=w.robots.test
  for id in g.players:
   g.players[id].dead=false;g.players[id].spectator=id in [-2,-3];g.players[id].hp=10000;g.players[id].armor=0;g.players[id].team=0 if id==1 else 1;g.players[id].input_blocked=false;g.players[id].invulnerable=0.
   g.fighters[id].position=Vector3(1010,0,-10)
  g.fighters[1].position=Vector3(1000,0,0);await physics_frame;await physics_frame
  check(w.try_board(1,"test"),profile+": normal boarding")
  # Keep this multi-hit routing fixture alive after the mandatory boarding heal.
  g.players[1].hp=10000
  var center: Vector3=(w.transform(r)*w._body_pose(r)).origin;var front:=center+Vector3(0,0,10);var back:=center-Vector3(0,0,10)
  var hp: int=g.players[1].hp
  g.variant_combat.launch(-1,6,front,Vector3.FORWARD);g._update_projectiles(1.,{})
  check(g.players[1].hp<hp and g.players[1].armor==200,profile+": actual direct rocket/hull impact survives the filter")
  hp=g.players[1].hp
  g.variant_combat.launch(-1,7 if profile!="quake" else 5,front,Vector3.FORWARD);g._update_projectiles(1.,{})
  check(g.players[1].hp<hp,profile+": non-explosive projectile hull impact damages pilot")
  hp=g.players[1].hp;var surface: Vector3=g._trace(front,back,-1).position
  g._blast(surface,-1,100,5)
  check(g.players[1].hp<hp,profile+": legacy explosion on convex hull surface damages pilot")
  hp=g.players[1].hp;g._blast(surface+Vector3(0,0,.25),-1,100,5);g.variant_combat.blast(surface+Vector3(0,0,.25),-1,100,5,"TEST SPLASH")
  check(g.players[1].hp==hp,profile+": both splash paths reject an explosion 25 cm off the hull")
  g.fighters[-1].position=surface+Vector3(0,0,1);g.players[-1].armor=0;hp=g.players[-1].hp
  g._blast(surface+Vector3(0,0,.25),1,100,5)
  check(g.players[-1].hp<hp,profile+": the same nearby explosion still hurts ordinary players")
  # Exercise real collection: shared rack gives one weapon grant per life,
  # stays available for another player, and cannot be farmed for ammunition.
  g.fighters[-1].position=Vector3(1010,0,-10);g.fighters[-2].position=g.fighters[-1].position;g.players[-2].spectator=false
  g.players[-1].owned=[0,2];g.players[-2].owned=[0,2];g.players[-1].ammo=[50,0,0,0];g.players[-2].ammo=[50,0,0,0]
  g.pickups=[{"kind":"weapon","item":3,"position":g.fighters[-1].position,"available":true,"respawn":0.,"weapon_stay":true,"amount":20,"node":null}]
  g._collect(-1);var ammo: Array=g.players[-1].ammo.duplicate();g._collect(-1);g._collect(-2)
  check(g.players[-1].owned.has(3) and g.players[-2].owned.has(3) and g.pickups[0].available,profile+": both players can collect a shared basic weapon rack")
  check(g.players[-1].ammo==ammo,profile+": owned weapon-stay rack does not refill ammunition repeatedly")
  g.disconnect_game();g.queue_free();await process_frame;await process_frame
 var armor_equal:=true
 for damage in [12,40,100,120,200,400]:
  var weapon=preload("res://deathmatch/weapons.gd")
  if weapon.armor_damage(damage,200,2).x!=weapon.armor_damage(damage,400,2).x:armor_equal=false
 check(armor_equal,"200 versus 400 tier-two armour gives identical health damage for hits up to 400")
 FileAccess.open("res://test-results/ba2/gameplay/contact-tests.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
 quit(0 if checks.all(func(c):return c.pass) else 1)
