extends SceneTree
const Fixture=preload("res://tools/ba2/gameplay/fixture.gd")
var g
var w
var checks: Array=[]
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks.append({"name":label,"pass":ok});print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func step(seconds: float) -> void:
	for i in ceili(seconds*60):g.clock+=1./60.;w.tick(1./60.)
func board() -> void:
	g.players[1].dead=false;g.players[1].hp=1000;g.players[1].input_blocked=false;g.players[1].invulnerable=0
	g.fighters[1].position=w.transform(w.robots.test)*w.LADDER;g.fighters[1].jump_held=false
	check(w.handle_player(1,true),"Jump boards parked robot")
	check(g.players[1].hp==g.match_mode.fortress.max_health(1),"Boarding restores the occupied cockpit health maximum")
	# This damage-routing fixture needs enough HP to exercise every weapon path.
	g.players[1].hp=1000
func _initialize():run.call_deferred()
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.mode_maplists["tb"]=["qsrc_dm1"];g.selected_map="qsrc_dm1";g.start_host("Pilot tests",0,100,60,true,"tb");g.set_physics_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	Fixture.build(g);g.match_mode.titanball.advance_time(60.);w=g.match_mode.fortress.walkers
	for id in g.players:
		g.players[id].dead=false;g.players[id].spectator=id in [-2,-3];g.players[id].team=0 if id==1 else 1;g.players[id].invulnerable=0;g.fighters[id].position=Vector3(10,0,-10)
	var s: Dictionary=g.players[1];s.weapon=6;s.armor=73;s.tier=1
	var inventory: Array=s.owned.duplicate();var ammo: Array=s.ammo.duplicate()
	await physics_frame;await physics_frame;board()
	check(s.weapon==0 and s.armor==200 and s.tier==2,"Boarding equips slot-zero fist and permanent 200 armour")
	check(g.match_mode.fortress.weapon_data(1,0).name=="FIST" and g.match_mode.fortress.art_rules(1,0)=="doom","Pilot uses the actual fist definition and art, not the Quake axe")
	check(s.owned==inventory and s.ammo==ammo,"Piloting preserves inventory and ammo")
	w.handle_player(1,true);check(w.mounted(1),"Held boarding jump does not immediately eject pilot")
	g._accept_input(1,{"seq":10000,"move":Vector2.ZERO,"yaw":0.,"pitch":0.,"fire":false,"weapon":6,"slow":false,"respawn":false,"jump":false})
	check(s.weapon==0,"Authoritative input rejects pilot weapon switching")
	g.desired_weapon=6;check(g._local_command().weapon==0,"Local command also locks weapon selection")
	check(not g.variant_combat.fire(1),"Pilot cannot bypass mounted combat guard by invoking experimental firing")
	var r: Dictionary=w.robots.test;var center: Vector3=(w.transform(r)*w._body_pose(r)).origin
	await physics_frame;await physics_frame
	var front: Vector3=center+Vector3(0,0,10);var back: Vector3=center-Vector3(0,0,10)
	var hit: Dictionary=g._trace(front,back,-1)
	check(hit.id==1 and hit.get("vehicle",false),"Round hull hits resolve to the seated pilot")
	var sweep: Dictionary=g._trace(front,back,-1,0.,.1,{},[])
	check(sweep.id==1 and sweep.vehicle,"Projectile sweeps hit hull even when player broadphase has no cockpit candidate")
	g._damage(hit.id,-1,40,"ASSAULT CANNON",false,hit.position,Vector3.FORWARD,false,hit.vehicle)
	check(s.hp==980 and s.armor==200,"Hull damage reduces pilot health with 200 armour protection")
	g._damage(1,-1,40,"ASSAULT CANNON",false,hit.position,Vector3.FORWARD,false,hit.vehicle);check(s.hp==960 and s.armor==200,"Consecutive hits each use full armour without depleting it")
	var friendly_hp: int=s.hp;g.players[-1].team=0;g._damage(1,-1,40,"ASSAULT CANNON",false,hit.position,Vector3.FORWARD,false,hit.vehicle);g.players[-1].team=1
	check(s.hp==friendly_hp,"Body damage still obeys friendly-fire rules")
	var tf=g.match_mode.fortress
	check(tf.sentry_target(front,1,18)==1,"Enemy sentries can acquire the occupied round body")
	tf.buildings[999]={"owner":-1,"team":1,"position":front-Vector3.UP*1.1,"kind":"sentry","hp":150,"ready":0.,"next":0.,"expires":g.clock+100.}
	var sentry_hp: int=s.hp;tf.tick_sentries();tf.buildings.erase(999)
	check(s.hp==sentry_hp-6 and s.armor==200,"Enemy sentry shots damage protected pilot")
	var ai=load("res://deathmatch/bots.gd").new();ai.game=g;g.add_child(ai)
	g.fighters[-1].position=front-Vector3.UP*g.fighters[-1].eye_height()
	check(ai.visible(-1,1),"Bot visibility recognizes occupied hull as its player target")
	g.players[-1].team=0
	check(not ai.safe_shot(-1,center),"Bot fire-safety rejects friendly occupied hull")
	g.players[-1].team=1;ai.free();g.fighters[-1].position=Vector3(10,0,-10)
	var gun_center: Vector3=w.bodies.test.get_node("CannonCollision0").global_position
	var gun_hit: Dictionary=g._trace(gun_center+Vector3(0,0,6),gun_center,-1)
	check(gun_hit.hit and gun_hit.id==0 and not gun_hit.vehicle,"Direct cannon hits remain invulnerable")
	var leg_hit: Dictionary=g._trace(Vector3(3.8,2.5,8),Vector3(3.8,2.5,1.1),-1)
	check(leg_hit.hit and leg_hit.id==0,"Leg hits do not masquerade as round-body hits")
	var wall:=StaticBody3D.new();var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12,12,.25);shape.shape=box;wall.add_child(shape);wall.position=center+Vector3(0,0,5);g.get_node("Map").add_child(wall)
	await physics_frame;await physics_frame
	check(g._trace(front,back,-1).id==0 and g._trace(front,back,-1,0.,.1).id==0,"Walls occlude hull hits for both rays and projectile sweeps")
	var blocked_hp: int=s.hp;g.variant_combat.blast(front,-1,100,15,"GRENADE LAUNCHER",0,true)
	check(s.hp==blocked_hp,"Wall blocks splash against robot hull")
	wall.free();await physics_frame;await physics_frame
	var nail_hp: int=s.hp
	g.variant_combat.launch(-1,5,front,Vector3.FORWARD);g._update_projectiles(.5,{})
	check(s.hp==nail_hp and s.armor==200,"Actual ordinary Quake nail projectile cannot penetrate pilot hull")
	var splash_hp: int=s.hp;g.variant_combat.blast(center+Vector3(0,0,3),-1,100,5,"GRENADE LAUNCHER",0,true)
	check(s.hp==splash_hp and s.armor==200,"Nearby Quake splash cannot damage the pilot")
	var legacy_hp: int=s.hp;g._blast(center+Vector3(0,0,3),-1,100,5)
	check(s.hp==legacy_hp and s.armor==200,"Nearby legacy splash cannot damage the pilot")
	var surface: Vector3=g._trace(front,back,-1).position
	check(w.surface_explosion(1,surface),"Contact probe recognizes the actual convex hull surface")
	g.variant_combat.blast(surface,-1,100,5,"GRENADE LAUNCHER",0,true)
	check(s.hp<legacy_hp,"Explosion on the actual hull surface still damages pilot")
	var indirect_hp: int=s.hp;g._damage(1,-1,40,"BURN");g._damage(1,-1,40,"FALL");g._damage(1,-1,40,"AXE")
	check(s.hp==indirect_hp,"Indirect burn, environment and melee damage do not reach seated pilot")
	step(10);w.handle_player(1,false);w.handle_player(1,true)
	check(not w.mounted(1) and s.weapon==6 and s.armor==73 and s.tier==1,"New jump exits and restores original weapon, armour and tier")
	check(s.owned==inventory and s.ammo==ammo and g.desired_weapon==6,"Exit restores local weapon selection without changing inventory")
	await physics_frame;await physics_frame
	check(g._trace(front,back,-1).id==0,"Empty robot body has no player damage recipient")
	step(8.1);board();step(5)
	var seat: Vector3=g.fighters[1].position;var life: int=s.serial
	g._damage(1,-1,5000,"ROCKET LAUNCHER",false,hit.position,Vector3.FORWARD,false,true)
	check(s.dead and not w.mounted(1),"Lethal hit immediately frees cockpit")
	check(g.fighters[1].position.distance_to(seat)>4 and g.fighters[1].position.y<1 and s.serial>life,"Dead pilot is physically ejected below the body")
	check(s.weapon==6 and s.armor==73 and s.tier==1 and not s.has("ba2_loadout"),"Death ejection restores saved equipment exactly once")
	await physics_frame;await physics_frame;step(1)
	check(r.speed>0 and r.speed<w.SPEED,"Forced ejection preserves gradual robot braking")
	step(7.1);board();w.reset()
	check(s.weapon==6 and s.armor==73 and s.tier==1,"Round reset restores pilot equipment")
	var report={"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/ba2/gameplay/pilot-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BA2_PILOT_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
