extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
const Config=preload("res://deathmatch/server/config.gd")
var g
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func reset(rule: String,weapon: int=2) -> void:
	g.armory.select(rule);g.variant_combat.reset();g.match_mode.kind="dm";g.intermission=0
	for id in g.projectiles.keys():g._projectile_end(id,g.projectiles[id].position,g.projectiles[id].weapon)
	for id in g.players:
		var s: Dictionary=g.players[id]
		s.merge({"weapon":weapon,"owned":range(g.armory.table.size()),"ammo":[200,100,100,300],"hp":2000,"armor":0,"dead":false,"spectator":false,"invulnerable":0,"cooldown":0.0,"charge":0.0,"fire":false,"alt_fire":false,"input_blocked":false,"last_input":g.clock,"yaw":0.0,"pitch":0.0,"vr_device":false,"xr":{},"team":0 if id==1 else 1},true)
		g.fighters[id].position=Fixture.point(8,8);g.fighters[id].velocity=Vector3.ZERO
	g.fighters[1].position=Fixture.point();g.fighters[-1].position=Fixture.point(0,-3)
func advance(seconds: float,hz: int=120) -> void:
	for i in ceili(seconds*hz):g._update_projectiles(1.0/hz)
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	await physics_frame
	g.start_host("Variants",0,100,60,true);g.bots.free();g.bots=null;g.set_physics_process(false);g.set_process(false)
	await physics_frame;await physics_frame
	check(not Config.parse('set sv_weapon_rules quake').has("error") and not Config.parse('set sv_weapon_rules ut99').has("error"),"Config accepts both experimental rulesets")
	check(Config.parse('set sv_weapon_rules invalid').has("error"),"Config rejects unknown ruleset")
	reset("quake",0);g.players[1].vr_device=true
	check(not g.variant_combat.fire(1) and not g.variant_combat.fire(1,true),"VR axe cannot be fired with either trigger")
	g.players[1].vr_device=false
	check(g.variant_combat.fire(1),"Desktop axe retains primary attack")
	check(g.armory.vr_physical_only(0) and g.armory.vr_physical_only(1) and not g.armory.vr_physical_only(2),"Only axe slots require physical Quake VR melee")
	reset("ut99",0);check(not g.armory.vr_physical_only(0),"UT hammer retains its charged trigger mechanism")
	reset("quake")
	check(g.variant_combat.fire(1) and g.players[1].ammo[1]==99 and g.players[-1].hp==1976,"Quake shotgun: six 4-damage pellets, shell ammo")
	reset("quake",3);g.players[1].ammo[1]=1
	check(g.variant_combat.fire(1) and g.players[1].ammo[1]==0 and g.players[-1].hp==1976,"Quake SSG falls back to one-shell shotgun")
	reset("quake",5);g.variant_combat.fire(1)
	check(g.projectiles.size()==1 and g.players[-1].hp==2000,"Nails travel rather than hitscan")
	advance(.2)
	check(g.players[-1].hp==1991 and g.projectiles.is_empty(),"Nail collision damages target once")
	reset("quake",7);g.variant_combat.fire(1);advance(.2)
	check(g.players[-1].hp==1982 and g.players[1].ammo[0]==198,"Super nailgun doubles nail damage and ammo cost")
	reset("quake",4);g.fighters[-1].position=Fixture.point(8,8)
	var grenade: int=g.variant_combat.launch(1,4,Fixture.point()+Vector3.UP*1.5,Vector3(0,-.5,-1).normalized())
	advance(.5)
	check(g.projectiles.has(grenade) and g.projectiles[grenade].get("bounces",0)>0,"Quake grenade bounces off floor")
	advance(2.1);check(not g.projectiles.has(grenade),"Grenade fuse expires and removes projectile")
	reset("quake",6);g.players[1].pitch=-1.5;g.fighters[-1].position=Fixture.point(8,8);g.variant_combat.fire(1);advance(.15)
	check(g.fighters[1].velocity.y>0 and g.players[1].hp<2000,"Quake self splash enables rocket jumping")
	reset("quake",8);g.fighters[-1].position=Fixture.point(0,-19.5);g.variant_combat.fire(1)
	check(g.players[-1].hp==2000,"Lightning has finite reach")
	reset("quake",8);g.variant_combat.fire(1)
	check(g.players[-1].hp==1970 and g.players[1].ammo[3]==299,"Lightning deals continuous-cell damage")
	reset("quake",5)
	g.fighters[-1].position=Fixture.point(9,0)
	var old: Dictionary={-1:{"position":Fixture.point(-9,0),"serial":g.players[-1].serial,"height":1.65}}
	var nail: int=g.variant_combat.launch(1,5,Fixture.point(0,2)+Vector3.UP,Vector3.FORWARD)
	g.projectiles[nail].fresh=false;g._update_projectiles(.128,old)
	check(g.players[-1].hp==1991,"Swept nail detects fast crossing target")
	reset("ut99",2);g.variant_combat.fire(1,true)
	check(is_equal_approx(g.players[1].cooldown,.2) and g.players[1].ammo[0]==199,"UT Enforcer alternate fire changes cadence")
	reset("ut99",3);g.fighters[-1].position=Fixture.point(1,-4)
	var orb: int=g.variant_combat.launch(1,3,Fixture.point(0,-4)+Vector3.UP*1.45,Vector3.FORWARD,{"alternate":true})
	g.variant_combat.fire(1)
	check(not g.projectiles.has(orb) and g.players[-1].hp<1900,"Primary beam detonates shock orb into damaging combo")
	reset("ut99",4);g.variant_combat.fire(1)
	check(g.projectiles.size()==8 and g.players[1].ammo[1]==99,"Flak emits eight physical fragments per shell")
	advance(.2);check(g.players[-1].hp<2000,"Flak fragments hit target")
	reset("ut99",4);g.variant_combat.fire(1,true);advance(.2)
	check(g.players[-1].hp<2000 and g.projectiles.size()<=6,"Alternate flak shell bursts into shrapnel")
	reset("ut99",6);g.variant_combat.fire(1,false,2.5)
	check(g.projectiles.size()==6 and g.players[1].ammo[2]==94,"UT charged six-rocket volley spends six rockets")
	reset("ut99",6);g.players[1].ammo[2]=2;g.variant_combat.fire(1,true,3)
	check(g.projectiles.size()==2 and g.players[1].ammo[2]==0,"Grenade volley is bounded by available ammo")
	reset("ut99",6);g.players[1].fire=true;g.variant_combat.tick_input(1,.1)
	g.players[1].input_blocked=true;g.players[1].fire=false;g.variant_combat.tick_input(1,.1)
	check(g.projectiles.is_empty() and g.variant_combat.charging.is_empty(),"Opening menu cancels charged weapon")
	reset("ut99",1);g.variant_combat.fire(1,true,1)
	check(g.projectiles.size()==1 and g.players[1].ammo[3]==295 and g.projectiles.values()[0].definition.damage==100,"Charged bio combines five cells into one glob")
	reset("ut99",7);g.variant_combat.fire(1,true)
	check(g.projectiles.is_empty() and g.players[-1].hp==1988,"Pulse alternate is a short beam")
	reset("ut99",10);g.variant_combat.fire(1);check(g.projectiles.size()==1,"Ripper is selectable and launches blades")
	reset("ut99",11);g.fighters[-1].position=Fixture.point(8,8)
	var disc: int=g.variant_combat.launch(1,11,Fixture.point(0,-4)+Vector3.UP*.15,Vector3.FORWARD)
	g.projectiles[disc].stuck=true
	check(g.variant_combat.translocate(1) and g.fighters[1].position.z<Fixture.point().z-3,"Translocator safely relocates to clear destination")
	reset("ut99",11);g.match_mode.kind="as"
	check(not g.armory.valid(11) and not g.variant_combat.fire(1) and not g.variant_combat.translocate(1),"AS prevents translocator objective bypass")
	for mode in ["ig","if","cc"]:
		g.match_mode.kind=mode;check(not g.armory.experimental() and g.armory.data(8)==g.W.DATA[8],"Specialized "+mode+" keeps original combat")
	await tf_checks()
	await integration_checks()
	reset("doom");check(g.armory.table==g.W.DATA and g.armory.dual(),"Default Doom data remains unchanged after variants")
	check(g.W.next_owned(9,1,[0,2,9,10,11])==10 and g.W.next_owned(11,1,[0,2,9,10,11])==0,"Weapon cycling reaches extended UT slots and wraps")
	check(checks>=68,"All scenario groups completed")
	var result:={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://test-results/weapon-variants")
	FileAccess.open("res://test-results/weapon-variants/combat.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("VARIANTS_RESULT ",JSON.stringify(result));g.disconnect_game("Tests finished");g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
func tf_checks() -> void:
	reset("quake");g.match_mode.kind="tf"
	for role in g.match_mode.fortress.CLASSES:
		g.players[1].tf_next=role;g.match_mode.fortress.spawn(1)
		var s: Dictionary=g.players[1]
		check(s.owned.has(0) and s.owned==g.match_mode.fortress.definition(1).owned and s.owned.all(func(w):return g.armory.valid(w) and g.match_mode.fortress.can_fire(1,w)),"Quake TF "+role+" has usable class loadout")
		var before: Array=s.ammo.duplicate();s.ammo=[0,0,0,0];g.match_mode.fortress.resupply(1,1)
		check(s.ammo[0]>0 and s.ammo[1]>0 and s.ammo[3]>0,"Quake TF "+role+" resupplies correct ammo pools")
		if role=="pyro":check(g.match_mode.fortress.weapon_data(1,7).kind=="hitscan","TF pyro keeps flame and burn mechanics")
	g.match_mode.kind="dm"

func integration_checks() -> void:
	for rules in ["quake","ut99"]:
		reset(rules,6);g.fighters[1].rotation=Vector3.ZERO
		var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
		pose.right.origin=Vector3(.25,.45,-.3);pose.weapon=Transform3D(Basis(Vector3.RIGHT,-PI/2),pose.right.origin)
		g.players[1].vr_device=true;g.players[1].xr=pose
		var solution: Dictionary=g._shot_solution(1)
		check(not solution.blocked and g.variant_combat.fire(1),rules+" VR ground-pointed rocket fires safely")
		g._update_projectiles(.04)
		check(g.fighters[1].velocity.y>5 and g.players[1].hp<2000,rules+" VR rocket jump retains impulse")
		reset(rules,2);g.fighters[1].position=Fixture.point(9.5,0);g.fighters[1].rotation=Vector3.ZERO
		pose.right.origin=Vector3(.8,1.1,0);pose.weapon=Transform3D(Basis(Vector3.UP,-PI/2),pose.right.origin)
		g.players[1].vr_device=true;g.players[1].xr=pose
		var blocked_all:=true
		for weapon in g.armory.table.size():
			g.players[1].weapon=weapon;g.players[1].cooldown=0
			blocked_all=blocked_all and g._shot_solution(1).blocked and not g.variant_combat.fire(1)
		check(blocked_all,rules+" every weapon rejects hand-through-wall firing")
	reset("ut99",9);g.variant_combat.fire(1)
	check(g.players[-1].hp==1900,"UT sniper rewards a head hit")
	reset("ut99",6);g.players[1].fire=true
	g.variant_combat.tick_input(1,.6);g.players[1].fire=false;g.variant_combat.tick_input(1,.01)
	check(g.projectiles.size()==2 and g.variant_combat.charging.is_empty(),"Releasing held trigger fires accumulated rockets")
	reset("ut99",1)
	for i in g.variant_combat.MAX_PROJECTILES:g.variant_combat.launch(1,1,Fixture.point(0,-6)+Vector3.UP,Vector3.FORWARD)
	var ammo: Array=g.players[1].ammo.duplicate()
	check(not g.variant_combat.fire(1) and g.players[1].ammo==ammo,"Projectile ceiling rejects shots without charging ammo")
	g._update_projectiles(9)
	check(g.projectiles.is_empty(),"All bounded bio projectiles expire")
	for rules in ["quake","ut99"]:
		reset(rules,5 if rules=="quake" else 3)
		var path:="user://variants-%s-%d.fpsdemo"%[rules,Time.get_ticks_usec()]
		check(g.demos.start_record(path),rules+" demo recording starts")
		g.variant_combat.fire(1,rules=="ut99");g._send_snapshot();g.demos.stop_record()
		g.demos.input=FileAccess.open(path,FileAccess.READ);g.demos.input.seek(g.demos.MAGIC.length())
		var frame: Dictionary=g.demos.read_frame()
		check(not frame.is_empty() and frame.snapshot[10].weapon_rules==rules and not frame.snapshot[10].ordnance.is_empty(),rules+" demo preserves projectile definitions and events")
		if not frame.is_empty():
			frame.snapshot[10].weapon_rules="invalid";check(not g.demos.valid_frame(frame),"Demo rejects unknown weapon rules")
		g.demos.input.close();g.demos.input=null
