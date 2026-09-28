extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("ST deployables",0,100,30,true,"st")
	g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	for id in g.players.keys():
		if id!=1:g._peer_left(id)
	g._add_player(-1,"Enemy");g.players[-1].team=1;g.players[1].team=0
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(340,1,240))
	var r=g.match_mode.tribes;var d=r.deployables;var pads=r.stations();var s: Dictionary=g.players[1];var actor=g.fighters[1]
	pads.playable_bounds=AABB(Fixture.ORIGIN-Vector3(170,2,120),Vector3(340,60,240));g.fighters[-1].position=Fixture.point(130,90)
	await physics_frame;await physics_frame
	var keys: Dictionary={};var i:=0
	for kind in d.Data.KINDS:
		check(r.Arsenal.valid_loadout("light",[3,2,4],kind)==(kind not in ["turret","inventory","ammo_station"]),"Classic armour restriction: "+kind)
		r.apply_equipment(1,"medium",[3,2,4],kind);s.tribes_paid=10000;actor.position=Fixture.point(i*20-60,0);actor.velocity=Vector3.ZERO
		var origin: Vector3=actor.position+Vector3.UP*1.6;var direction: Vector3=(actor.position+Vector3(0,0,-2)-origin).normalized()
		var energy: float=actor.tribes_state.energy
		check(d.deploy(1,origin,direction),"Physical placement: "+kind)
		check(s.tribes_pack=="none" and actor.tribes_state.energy==energy,"Pack consumed without refilling personal energy: "+kind)
		if d.rows.is_empty():quit(1);return
		keys[kind]=d.next_id-1;i+=1
		await physics_frame
	check(d.valid(d.snapshot()),"Deployables snapshot validates")
	var maximum: Dictionary={"rows":{},"contacts":[[],[]]};var serial:=1
	for team in [0,1]:
		for kind in d.Data.KINDS:
			for slot in d.Data.KINDS[kind].limit:
				var row: Dictionary=d.rows[keys[kind]].duplicate();row.team=team;maximum.rows[serial]=row;serial+=1
	var codec=preload("res://deathmatch/network/codec.gd")
	check(maximum.rows.size()==150 and d.valid(maximum),"Both teams' maximum deployment counts fit the schema")
	var packet: PackedByteArray=codec.pack(maximum)
	check(not packet.is_empty() and d.valid(codec.unpack(packet)),"Maximum deployment state round-trips through bounded network codec")
	Fixture.box(g,Fixture.point(100,-2)+Vector3.UP*1.5,Vector3(4,3,.3));actor.position=Fixture.point(100,0)
	r.apply_equipment(1,"light",[3,2,4],"camera");await physics_frame
	check(d.deploy(1,actor.position+Vector3.UP*1.6,Vector3.FORWARD),"Camera mounts on a wall")
	var wall: Dictionary=d.rows[d.next_id-1]
	check(wall.aim.dot(wall.normal)>.99 and d.ray(d.Data.eye(wall),d.Data.eye(wall)+wall.aim*2).is_empty(),"Wall camera looks out from the surface, with an unobstructed lens")
	var bad: Dictionary=d.snapshot();bad.rows[keys.turret].normal=Vector3.ZERO;check(not d.valid(bad),"Reject malformed placement normal")
	bad=d.snapshot();bad.rows[keys.turret].energy=INF;check(not d.valid(bad),"Reject non-finite remote energy")
	bad=d.snapshot();bad.rows[keys.turret].team=3;check(not d.valid(bad),"Reject invalid owning team")
	var turret: Dictionary=d.rows[keys.turret];actor.position=turret.position+Vector3(3,0,0);r.apply_equipment(1,"medium",[3,2,4],"turret")
	check(not d.deploy(1,actor.position+Vector3.UP*1.6,Vector3(-1,-.8,0).normalized()),"Reject turret interference spacing")
	check(s.tribes_pack=="turret","Failed placement keeps backpack")
	var origin: Vector3=actor.position+Vector3.UP*1.6
	check(not d.deploy(1,origin+Vector3.RIGHT*5,Vector3.DOWN),"Reject forged distant placement origin")
	s.dead=true;check(not d.deploy(1,origin,Vector3.DOWN),"Dead player cannot deploy");s.dead=false
	# Independent station reserve and restricted remote inventory purchases.
	g.clock+=2;var station: Dictionary=d.rows[keys.inventory];actor.position=d.Data.frame(station)*Vector3(0,0,-1.25);actor.velocity=Vector3.ZERO
	pads.health[0]=0;r.energy[0]=20000
	check(d.station(1)==keys.inventory and r.can_refit(1),"Remote station works without base generator")
	check(not d.can_shop(1,"light","energy") and not d.can_shop(1,"medium","inventory"),"Remote inventory cannot change armour or buy another station")
	g.clock+=1;r.requests.clear();var reserve: float=station.energy;var team_energy: int=r.energy[0];var cost: int=r.refit_cost(1,"medium",[3,2,4],"energy")
	check(r.select_equipment(1,"medium",[3,2,4],"energy",true),"Remote inventory refits legal personal equipment")
	check(r.energy[0]==team_energy and station.energy==clampf(reserve-cost,0,3000),"Refit charges only the remote reserve, with capped trade-in")
	station.energy=0;s.tribes_ammo[3]=0;g.clock+=1;d.tick(.5)
	check(s.tribes_ammo[3]==0,"Empty remote reserve cannot create ammo")
	station.energy=100;g.clock+=1;d.tick(.5)
	check(s.tribes_ammo[3]>0 and station.energy<100 and r.energy[0]==team_energy,"Remote resupply consumes local energy")
	s.team=1;check(d.station(1)<0,"Enemy cannot use remote station");s.team=0
	# Shoot, repair and destroy the actual world fixture.
	var point: Vector3=turret.position+Vector3.UP*.5
	var hit: Dictionary=g._trace(point+Vector3(0,0,-4),point,1)
	check(hit.get("deployable",-1)==keys.turret,"Gun trace hits remote fixture")
	var health: float=turret.hp;g._damage_map_hit(hit,-1,20);check(turret.hp==health-20,"Weapon damage affects deployable durability")
	check(d.repair(keys.turret,1,10) and turret.hp==health-10,"Repair pack restores friendly equipment")
	check(not d.repair(keys.turret,-1,10),"Enemy cannot repair the fixture")
	# Sensor sharing, motion detection and jamming are distinct.
	var enemy=g.fighters[-1];var pulse: Dictionary=d.rows[keys.pulse];var motion: Dictionary=d.rows[keys.motion]
	enemy.position=pulse.position+Vector3(0,0,-20);enemy.velocity=Vector3.ZERO;actor.position=Fixture.point(-100,30)
	d.scan();check(-1 in d.contacts[0],"Pulse sensor shares stationary visible enemy")
	pulse.ready=g.clock+100;d.rows[keys.camera].ready=g.clock+100
	enemy.position=motion.position+Vector3(0,0,-20);d.scan();check(-1 not in d.contacts[0],"Motion sensor ignores stationary enemy")
	enemy.velocity=Vector3.RIGHT*2;d.scan();check(-1 in d.contacts[0],"Motion sensor shares moving enemy")
	var jammer: Dictionary=d.rows[keys.remote_jammer];jammer.team=1;jammer.position=enemy.position+Vector3(5,0,0);d.scan()
	check(d.jammed(-1) and -1 in d.contacts[0],"Jammer does not defeat unsuppressible motion sensor")
	pulse.ready=0;motion.ready=g.clock+100;enemy.velocity=Vector3.ZERO;d.scan();check(-1 not in d.contacts[0],"Jammer suppresses pulse detection")
	jammer.team=0;motion.ready=0;d.sync();await physics_frame
	# Turret fires a normal travelling projectile; no instant hitscan damage.
	enemy.position=turret.position+Vector3(0,0,-15);enemy.velocity=Vector3.RIGHT*2;var shots: int=g.projectiles.size()
	turret.aim=(enemy.position+Vector3.UP-turret.position-Vector3.UP*1.2).normalized();turret.energy=60
	d.tick(.4)
	check(g.projectiles.size()>shots and turret.energy<60,"Turret consumes energy and launches a bolt at moving enemy")
	var bolts: Array=g.projectiles.values().filter(func(p):return p.definition.get("name","")=="REMOTE TURRET")
	check(not bolts.is_empty() and bolts[0].definition.speed==80 and bolts[0].definition.damage==roundi(.1*r.Arsenal.UNIT),"Turret bolt uses classic speed and damage scale")
	var before: int=d.count(0,"turret");d.damage(keys.turret,-1,1000)
	check(d.count(0,"turret")==before-1 and not d.rows.has(keys.turret),"Destruction releases team deployment limit")
	check(d.valid(d.snapshot()),"Post-combat snapshot remains valid")
	var copy: Dictionary=d.snapshot();d.reset();await physics_frame;d.receive(copy)
	check(d.rows.size()==copy.rows.size() and d.nodes.size()==copy.rows.size(),"Late client restores fixture geometry and state")
	g.match_mode.kind="tdm";r.tick(.1);check(d.rows.is_empty(),"Leaving ST removes remote equipment")
	print("TRIBES_DEPLOYABLES ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
