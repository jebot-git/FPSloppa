extends SceneTree
var g
var checks:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String):
 checks.append({"pass":ok,"name":label});print("PASS " if ok else "FAIL ",label)
func run():
 g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
 g.start_host("Heavy ordnance test",0,100,10,true,"tb","quake");g.set_physics_process(false);g.set_process(false)
 if is_instance_valid(g.bots):g.bots.free();g.bots=null
 var w=g.match_mode.fortress.walkers
 w.configure([{"id":"test","team":0,"points":[Vector3(1000,0,0),Vector3(1000,0,100)]}]);var r:Dictionary=w.robots.test
 for id in g.players:
  var s:Dictionary=g.players[id];s.dead=false;s.spectator=id in [-2,-3];s.team=0 if id==1 else 1;s.hp=10000;s.armor=0;s.invulnerable=0.;s.input_blocked=false
  g.fighters[id].position=Vector3(1010,0,-10)
 g.fighters[1].position=Vector3(1000,0,0);await physics_frame;await physics_frame
 check(w.try_board(1,"test") and g.players[1].hp==200,"Default exclusive boarding grants 200 HP")
 check(not w.pilot_regeneration,"Cockpit regeneration defaults off")
 var pilot:Dictionary=g.players[1];pilot.hp=10000
 var hp:int=pilot.hp
 g._damage(1,-1,50,"SHOTGUN",false,Vector3.INF,Vector3.ZERO,false,true)
 check(pilot.hp==hp and pilot.armor==200 and w.heavy_ordnance_only,"Default TB policy blocks shotguns without changing armour")
 for title in ["SHOTGUN","SUPER SHOTGUN","NAILGUN","SUPER NAILGUN","RAILGUN","FLAMETHROWER","BURN","NAPALM","AXE","FIST","KICK","LIGHTNING GUN","UNKNOWN"]:
  hp=pilot.hp;g._damage(1,-1,50,title,false,Vector3.INF,Vector3.ZERO,false,true)
  check(pilot.hp==hp and pilot.armor==200,"Heavy filter blocks "+title+" without consuming armour")
 for title in w.HEAVY_PILOT_WEAPONS:
  hp=pilot.hp;g._damage(1,-1,50,title,false,Vector3.INF,Vector3.ZERO,false,true)
  check(pilot.hp<hp and pilot.armor==200,"Verified contact permits "+title)
 hp=pilot.hp;g._damage(1,-1,100,"ROCKET LAUNCHER")
 check(pilot.hp==hp,"Eligible weapon still requires hull contact")
 var center:Vector3=(w.transform(r)*w._body_pose(r)).origin;var front:=center+Vector3(0,0,10);var back:=center-Vector3(0,0,10)
 for slot in [2,3,5,7,9]:
  g.players[-1].tf_class="medic"
  hp=pilot.hp
  if slot in [5,7]:
   g.variant_combat.launch(-1,slot,front,Vector3.FORWARD);g._update_projectiles(1.,{})
  else:
   var hit:Dictionary=g._trace(front,back,-1)
   check(hit.get("vehicle",false) and hit.id==1,"Trace identifies hull for slot %d"%slot)
   g._damage(hit.id,-1,60,g.match_mode.fortress.weapon_data(-1,slot).name,false,hit.position,Vector3.FORWARD,false,hit.vehicle)
  check(pilot.hp==hp,"Small-arm contact blocked through routing, slot %d"%slot)
 for slot in [4,6]:
  g.players[-1].tf_class="soldier";hp=pilot.hp
  g.variant_combat.launch(-1,slot,center+Vector3(0,0,5),Vector3.FORWARD);g._update_projectiles(.25,{})
  check(pilot.hp<hp,"Actual explosive projectile penetrates hull, slot %d"%slot)
 g.players[-1].tf_class="heavy";hp=pilot.hp
 var projectile:int=g.variant_combat.launch(-1,7,front,Vector3.FORWARD)
 check(g.projectiles[projectile].definition.get("heavy_automatic",false),"Heavy primary is classified at firing time")
 g.players[-1].tf_class="medic";g._update_projectiles(.5,{})
 check(pilot.hp<hp,"Heavy shot still penetrates after owner changes class")
 hp=pilot.hp;projectile=g.variant_combat.launch(-1,7,front,Vector3.FORWARD,{"heavy_automatic":true})
 check(not g.projectiles[projectile].definition.get("heavy_automatic",false),"Projectile extras cannot give Medic Heavy classification")
 g.players[-1].tf_class="heavy";g._update_projectiles(.5,{})
 check(pilot.hp==hp,"Medic shot stays blocked after owner changes to Heavy")
 var surface:Vector3=g._trace(front,back,-1).position
 for modern in [false,true]:
  hp=pilot.hp
  if modern:g.variant_combat.blast(surface,-1,100,5,"GRENADE LAUNCHER")
  else:g._blast(surface,-1,100,5)
  check(pilot.hp<hp,"Explosion on hull penetrates, modern=%s"%modern)
  hp=pilot.hp
  if modern:g.variant_combat.blast(surface+Vector3(0,0,.25),-1,100,5,"GRENADE LAUNCHER")
  else:g._blast(surface+Vector3(0,0,.25),-1,100,5)
  check(pilot.hp==hp,"Explosion 25 cm off hull remains blocked, modern=%s"%modern)
 # TF thrown grenade and pipe charge share the authoritative detonation path.
 for kind in ["grenade","pipe"]:
  g.match_mode.fortress.charges[-1]={"position":surface,"kind":kind,"team":1}
  hp=pilot.hp;g.match_mode.fortress.detonate(-1)
  check(pilot.hp<hp,"TF "+kind+" detonation on hull penetrates")
 g.match_mode.kind="tf";hp=pilot.hp;g._damage(1,-1,50,"SHOTGUN",false,Vector3.INF,Vector3.ZERO,false,true)
 check(pilot.hp<hp,"Heavy-ordnance restriction is scoped to TB")
 g.match_mode.kind="tb";g._damage(1,1,100000,"SUICIDE",true)
 check(pilot.dead and not w.mounted(1),"Administrative suicide still kills and ejects")
 pilot.dead=false;pilot.hp=100;pilot.invulnerable=0;hp=pilot.hp
 g._damage(1,-1,50,"SHOTGUN")
 check(pilot.hp<hp,"On-foot damage remains unchanged with TB rule enabled")
 var result:Dictionary={"checks":checks,"passed":checks.all(func(c):return c.pass)}
 FileAccess.open("res://test-results/titanball/heavy-ordnance-tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("HEAVY_ORDNANCE_RESULT ",JSON.stringify(result))
 g.disconnect_game();g.queue_free();await process_frame;await process_frame;quit(0 if result.passed else 1)
