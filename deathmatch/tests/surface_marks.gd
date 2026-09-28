extends SceneTree
const Profiles=preload("res://deathmatch/effects/surface_marks.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func marked() -> bool:
	for e in g.demos.events:
		if e[0]=="_surface_marks" and not e[1][0].is_empty():return true
		if e[0]=="_impacts" and e[1].size()>=4:
			for normal in e[1][3]:
				if normal.length_squared()>.9:return true
	return false
func reset(rules: String,w: int):
	for id in g.projectiles.keys():g._projectile_end(id,g.projectiles[id].position,g.projectiles[id].weapon)
	g.match_mode.kind="dm";g.armory.select(rules);g.variant_combat.reset();g.clock+=10
	for id in g.players:
		g.players[id].spectator=id!=1;g.fighters[id].position=Fixture.point(15,15)
	var s: Dictionary=g.players[1]
	s.merge({"weapon":w,"owned":range(12),"ammo":[10000,10000,10000,10000],"hp":100000,"armor":0,"dead":false,"spectator":false,"invulnerable":0,"cooldown":0.0,"offhand_cooldown":0.0,"charge":0.0,"fire":false,"held":false,"alt_fire":false,"input_blocked":false,"last_input":g.clock,"yaw":0.0,"pitch":0.0,"vr_device":false,"xr":{},"melee":false,"melee_state":{},"offhand_melee_state":{},"melee_ready_at":0.0},true)
	g.fighters[1].position=Fixture.point(0,-.3);g.fighters[1].velocity=Vector3.ZERO;g.fighters[1].in_water=false
	g.demos.events.clear()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("Surface mark audit",0,100,60,true,"dm");g.set_process(false);g.set_physics_process(false);g.headless=true
	Fixture.box(g,Fixture.ORIGIN+Vector3(0,-.5,0),Vector3(40,1,40))
	Fixture.box(g,Fixture.ORIGIN+Vector3(0,3,-1.6),Vector3(40,6,.2))
	await physics_frame;await physics_frame
	g.demos.recording=true
	for rules in ["doom","quake","ut99","cs16","tribes"]:
		g.armory.select(rules)
		var count: int=g.armory.table.size()
		for w in count:
			for alternate in ([false,true] if rules=="ut99" and g.armory.data(w).has("alt") and not g.armory.data(w).get("scope",false) else [false]):
				reset(rules,w)
				var d: Dictionary=g.armory.data(w,alternate)
				var style:=Profiles.profile(d)
				var label: String=rules+" / "+d.name+(" alternate" if alternate else "")
				if style<0:
					check(d.name in ["TRANSLOCATOR","REPAIR GUN","TARGETING LASER"],label+" is intentionally non-marking utility");continue
				if rules=="tribes":
					g.match_mode.kind="st"
					if w in [5,6]:g.match_mode.tribes.combat.beam(1,w,Fixture.ORIGIN+Vector3.UP,Vector3.FORWARD,60)
					else:g.variant_combat.launch(1,w,Fixture.ORIGIN+Vector3.UP,Vector3.FORWARD)
				elif rules=="cs16" and w==0:
					g.players[1].melee=true;g._update_melee(1)
				elif rules=="doom":
					g._fire(1)
					if w==8:g._launch(1,w)
				else:g.variant_combat.fire(1,alternate,1.5)
				for frame in 600:
					if g.projectiles.is_empty():break
					g.clock+=1.0/60;g._update_projectiles(1.0/60)
				check(marked(),label+" produces authoritative static-surface marks")
	for item in [["pyro",6],["pyro",7],["engineer",2],["engineer",0],["spy",2],["spy",0],["heavy",7],["sniper",9]]:
		reset("quake",item[1]);g.match_mode.kind="tf";g.players[1].tf_class=item[0]
		g.variant_combat.fire(1)
		for frame in 600:
			if g.projectiles.is_empty():break
			g.clock+=1.0/60;g._update_projectiles(1.0/60)
		check(marked(),"TF "+item[0]+" / "+g.match_mode.fortress.weapon_data(1,item[1]).name+" marks surfaces")
	# Collision exclusions and radial explosion placement, through real physics.
	reset("ut99",3)
	var start:=Fixture.ORIGIN+Vector3.UP
	Profiles.contact(g,{"hit":true,"id":2,"position":start+Vector3.FORWARD},start,start+Vector3.FORWARD*3,{"name":"BLASTER"})
	check(not marked(),"Player impact cannot paint the wall behind the player")
	Profiles.blast(g,start+Vector3.UP*20,{"name":"ROCKET LAUNCHER","splash":100,"blast_radius":20})
	check(not marked(),"Distant airburst cannot stamp nearby-looking walls")
	Profiles.blast(g,start,{"name":"ROCKET LAUNCHER","splash":100,"blast_radius":5})
	check(marked(),"Nearby explosion projects an occluded scorch onto floor/wall")
	reset("doom",6);var id: int=g.variant_combat.launch(1,6,start,Vector3.FORWARD)
	g.demos.events.clear();g._projectile_end(id,start,6)
	check(not marked(),"Projectile cancellation/removal creates no scorch")
	g.demos.recording=false;g.free()
	print("SURFACE_MARKS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
