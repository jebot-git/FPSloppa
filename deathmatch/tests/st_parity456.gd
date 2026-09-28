extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
const Health=preload("res://deathmatch/tribes/equipment_health.gd")
var g
var r
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	seed(456);g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST field systems",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false);r=g.match_mode.tribes
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Receiver");g._add_player(-2,"Enemy")
	g.players[1].team=0;g.players[-1].team=0;g.players[-2].team=1
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(500,1,500))
	for id in g.players:g.fighters[id].position=Fixture.ORIGIN+Vector3(30*id,0,100);g.fighters[id].velocity=Vector3.ZERO
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame
	await power_cases()
	await recovery_cases()
	await target_cases()
	await physical_cases()
	state_cases()
	print("ST_PARITY456 ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
func marker(kind: String,team: int,offset: Vector3,extra: Dictionary={}):
	var node:=Node3D.new();node.set_script(load("res://deathmatch/tests/st_power_marker.gd"));node.attributes={"classname":"info_tribes_"+kind,"team":str(team)};node.attributes.merge(extra);g.add_child(node);node.position=Fixture.ORIGIN+offset+Vector3.UP*.7;return node
func power_cases():
	var hp:=Health.UNIT
	for pair in [["",1.0],["Grenade",.5],["Mortar",.25],["Blaster",2.0]]:
		var row:={"hp":hp,"energy":10.0};Health.hit(row,hp,100,true,pair[0]);var absorbed: float=10*.03*hp*pair[1]
		check(is_equal_approx(row.hp,hp-100+absorbed) and row.energy==0,"Shield absorption and energy conservation "+str(pair[0]))
	var row:={"hp":hp,"energy":100.0};Health.hit(row,hp,hp*.5,false)
	check(not Health.enabled(row.hp,hp) and row.hp>0 and row.energy==100,"Half damage disables without destruction or unpowered shielding")
	Health.hit(row,hp,hp*.25,false);check(row.hp==0,"Three-quarter damage destroys and sets full damage")
	var fixtures: Array=[marker("generator",0,Vector3(0,0,0),{"targetname":"main"}),marker("solar",0,Vector3(15,0,0),{"targetname":"solar"}),marker("generator",1,Vector3(30,0,0),{"targetname":"enemy"}),marker("inventory",0,Vector3(0,0,10),{"power_sources":"main,solar"}),marker("ammo",0,Vector3(10,0,10),{"power_sources":"solar"}),marker("command",0,Vector3(20,0,10),{"power_group":"isolated"}),marker("vehicle",0,Vector3(30,0,10),{"power_sources":"enemy"})]
	var pads=preload("res://deathmatch/tribes/stations.gd").new();g.add_child(pads);pads.configure(g,fixtures);pads.reset();await physics_frame
	check(pads.generators.size()==3 and pads.rows.size()==4,"Map creates multiple power sources and distinct station kinds")
	check(pads.assets.active(0) and pads.assets.active(1) and not pads.assets.active(2) and not pads.assets.active(3),"Explicit connections, isolated circuits and cross-team rejection")
	pads.damage_source(0,-2,151)
	check(not pads.source_active(pads.generators[0]) and pads.powered(0) and pads.assets.active(0),"Solar backup sustains consumers after primary generator disables")
	pads.damage_source(1,-2,10000)
	check(not pads.powered(0) and not pads.assets.active(0) and not pads.assets.active(1),"Losing last connected source disables both consumers")
	check(not pads.restore_source(1,-2,10000),"Enemy cannot repair power source")
	pads.restore_source(1,1,30);check(not pads.powered(0),"Partial repair below threshold keeps circuit offline")
	pads.restore_source(1,1,100);check(pads.powered(0) and pads.assets.active(1),"Repair above enabled threshold restores solar circuit")
	g.fighters[1].position=pads.rows[1].position;await physics_frame
	check(pads.at(1)<0 and pads.at(1,["ammo"])==1,"Ammo station does not offer armour/loadout refits")
	var state: Dictionary=pads.power_snapshot();check(pads.valid_power(Codec.unpack(Codec.pack(state))),"Power and sensor capacitor state survives network codec")
	var sensor: Dictionary=r.stations().assets.rows.filter(func(v):return v.kind=="pulse")[0]
	sensor.energy=0;r.stations().assets.tick(1);check(sensor.energy==10,"Powered sensor shield recharges at 10 energy per second")
	r.stations().health[sensor.team]=0;r.stations().assets.tick(1);check(sensor.energy==10,"Disabled base power stops sensor recharge")
	r.stations().reset();pads.free()
	for node in fixtures:node.free()
func recovery_cases():
	var recover=r.recovery;recover.reset();r.apply_equipment(1,"heavy",[3,2,7],"ammo");r.apply_equipment(-1,"light",[3,2,0],"none")
	var s: Dictionary=g.players[1];var friend: Dictionary=g.players[-1]
	s.tribes_paid=r.Arsenal.cost("heavy",[3,2,7],"ammo");s.tribes_beacons=13
	g.fighters[1].position=Fixture.ORIGIN+Vector3(0,0,70);g.fighters[-1].position=g.fighters[1].position+Vector3(0,0,-.6)
	var point: Vector3=g.fighters[1].position+Vector3.UP*.7
	check(recover.drop(1,"pack",point,Vector3.ZERO),"Ammo pack can be dropped through ordinary transfer")
	var key: int=recover.rows.keys()[0];var payload: Dictionary=recover.rows[key].payload
	check(s.tribes_pack=="none" and s.tribes_ammo[2]==200 and payload.ammo[2]==150 and s.tribes_beacons==3 and payload.beacons==10,"Dropped ammo pack stores only extra capacity and removes exact counts")
	friend.tribes_ammo[2]=0;var paid: int=r.carried_value(-1)
	check(recover.pickup(-1,key),"Another player can equip transferred ammo pack")
	check(friend.tribes_pack=="ammo" and friend.tribes_ammo[2]==150 and friend.tribes_beacons==10,"Receiver gains actual stored rounds and beacons")
	check(r.carried_value(-1)<=paid,"Salvage cannot mint refundable team energy")
	check(recover.rows.has(key) and recover.rows[key].payload.ammo[7]==10,"Incompatible mortar ammunition remains for another player")
	var count: int=friend.tribes_ammo[2];recover.pickup(-1,key)
	check(friend.tribes_ammo[2]==count,"Repeated pickup cannot duplicate ammunition")
	s.weapon=2;s.tribes_ammo[2]=17
	check(recover.drop(1,"ammo",point,Vector3.ZERO) and s.tribes_ammo[2]==0,"Chaingun ammo transfer may give final rounds")
	s.weapon=3;s.tribes_ammo[3]=1
	check(not recover.drop(1,"ammo",point,Vector3.ZERO) and s.tribes_ammo[3]==1,"Active disc launcher keeps its last round")
	s.weapon=7
	check(recover.drop(1,"weapon",point,Vector3.ZERO) and 7 not in s.owned and s.weapon in s.owned,"Weapon transfer removes ownership and selects another weapon")
	r.apply_equipment(1,"light",[5],"energy");s.weapon=5
	check(recover.drop(1,"pack",point,Vector3.ZERO) and s.weapon==11,"Dropping lone sniper's energy pack leaves a valid tool selection")
	r.apply_equipment(1,"heavy",[3,2,7],"repair");s.tribes_ammo[2]=31;s.tribes_ammo[7]=4;s.tribes_beacons=2;s.dead=true
	recover.death(1);key=recover.rows.keys()[-1]
	check(recover.rows[key].payload.guns==[3,2,7] and recover.rows[key].payload.ammo[2]==31 and recover.rows[key].payload.pack=="repair","Corpse preserves all carried guns, ammo and pack")
	check(s.tribes_ammo.all(func(v):return v==0) and not s.tribes_kit and s.tribes_beacons==0,"Corpse inventory is removed from dead owner")
	s.dead=false;r.apply_equipment(-1,"heavy",[0],"none");friend.tribes_ammo.fill(0)
	g.fighters[-1].position=g.fighters[1].position
	check(recover.pickup(-1,key) and 7 in friend.owned and friend.tribes_ammo[7]==4 and friend.tribes_pack=="repair" and 8 in friend.owned,"Compatible looter recovers full arsenal and repair tool within armour gun limit")
	var patch: Dictionary=recover.empty_payload();patch.patch=true;key=recover.create(0,patch,point,Vector3.ZERO,"patch")
	friend.hp=r.definition(-1).hp;check(not recover.pickup(-1,key) and recover.rows.has(key),"Full-health player leaves repair patch for teammates")
	friend.hp-=50;var hp: int=friend.hp
	check(recover.pickup(-1,key) and friend.hp==hp+roundi(.125*r.Arsenal.UNIT),"World repair patch restores original normalized damage amount")
	var payload2: Dictionary=recover.empty_payload();payload2.ammo[2]=10;key=recover.create(0,payload2,point+Vector3(5,0,0),Vector3.ZERO,"ammo")
	check(not recover.pickup(-1,key),"Pickup rejects out-of-reach remote inventory")
	g.fighters[-1].position=point+Vector3(5,0,0)-Vector3.UP*.7
	var wall=Fixture.box(g,point+Vector3(5,0,.25),Vector3(2,2,.1));g.fighters[-1].position.z+=.6;await physics_frame
	check(not recover.pickup(-1,key),"Pickup cannot reach through solid cover")
	wall.free();await physics_frame
	g.clock+=40;recover.tick(.01);check(recover.rows.is_empty(),"Expired corpse/drop inventories are bounded and cleaned")
func target_cases():
	r.targeting.reset();r.recovery.reset();r.stations().playable_bounds=AABB(Fixture.ORIGIN-Vector3(200,10,200),Vector3(400,200,400))
	r.apply_equipment(1,"heavy",[3,4,7],"energy");g.fighters[1].position=Fixture.ORIGIN+Vector3(0,0,30);g.fighters[1].velocity=Vector3.ZERO
	g.players[1].tribes_beacons=3
	var start: Vector3=g.fighters[1].position+Vector3.UP*.7+Vector3.RIGHT*.8
	check(not r.targeting.place(1,g.fighters[1].position+Vector3.UP*.7,Vector3.DOWN),"Occupied player volume blocks beacon placement")
	check(r.targeting.place(1,start,Vector3.DOWN),"Beacon mounts to a clear terrain surface within three metres")
	check(g.players[1].tribes_beacons==2 and r.targeting.targets(0).size()==1 and r.targeting.targets(1).is_empty(),"Beacon consumption and team-only artillery targets")
	check(not r.targeting.place(1,start,Vector3.DOWN),"Overlapping beacon placement rejected without consumption")
	check(not r.targeting.place(1,start+Vector3(30,0,0),Vector3.DOWN),"Forged remote beacon origin rejected")
	var key: int=r.targeting.beacons.keys()[0];r.targeting.damage(key,1,100)
	check(r.targeting.beacons.has(key),"Friendly fire protects deployed beacon")
	var saved: Vector3=g.fighters[1].position;g.fighters[1].position+=Vector3(20,0,0)
	var beacon: Vector3=r.targeting.beacons[key].position
	check(g._trace(beacon+Vector3(0,0,-2),beacon,0).get("beacon",-1)==key,"Beacon participates in ordinary projectile trace")
	g.variant_combat.launch(0,0,beacon+Vector3(0,0,-2),Vector3.BACK,{"fixed_turret":"fusion","turret_team":0})
	for frame in 15:g._update_projectiles(1.0/120)
	check(r.targeting.beacons.has(key) and r.targeting.beacons[key].hp==.1*r.Arsenal.UNIT,"Orphaned friendly turret projectile respects beacon team")
	g.fighters[1].position=saved
	r.targeting.damage(key,-2,.05*r.Arsenal.UNIT);check(r.targeting.targets(0).is_empty(),"Damaged beacon stops providing solutions at disable threshold")
	r.targeting.damage(key,-2,100);check(r.targeting.beacons.is_empty(),"Enemy damage destroys beacon")
	g.players[1].weapon=11;g.players[1].fire=true;g.players[1].cooldown=0;g.fighters[1].tribes_state.energy=4
	check(not r.combat.fire(1),"Targeting laser cannot run below five energy")
	g.fighters[1].tribes_state.energy=20;g.players[1].cooldown=0
	check(r.combat.fire(1) and is_equal_approx(g.fighters[1].tribes_state.energy,17),"Sustained targeter trace consumes three energy per .2 second")
	var target: Vector3=start+Vector3(0,0,-100)
	r.targeting.designate(1,{"hit":true,"position":target});check(r.targeting.targets(0).size()==1,"Held targeting laser publishes shared designation")
	g.players[1].fire=false;r.targeting.tick();check(r.targeting.lasers.is_empty(),"Laser designation clears immediately after release")
	g.players[1].fire=true;r.targeting.designate(1,{"hit":true,"position":target});g.clock+=.5;r.targeting.tick()
	check(r.targeting.lasers.is_empty(),"Stale designation expires when updates stop")
	g.players[1].weapon=7;g.players[1].yaw=0;g.players[1].pitch=0
	for w in [4,7]:
		g.fighters[1].velocity=Vector3(3,0,0)
		var solution: Dictionary=r.targeting.solution(1,target,w)
		check(not solution.is_empty(),"Artillery solution exists for "+r.Arsenal.NAMES[w])
		if not solution.is_empty():
			var endpoint: Vector3=g._shot_solution(1).origin+solution.velocity*solution.time-Vector3.UP*10*solution.time*solution.time
			check(endpoint.distance_to(target)<.01,"Solution reaches marker including inherited motion "+str(w))
	g.fighters[1].velocity=Vector3.ZERO
	var wall=Fixture.box(g,start+Vector3(0,20,-30),Vector3(300,320,2));await physics_frame
	check(r.targeting.solution(1,target,7).is_empty(),"Blocked low and high trajectories suppress misleading aiming markers")
	wall.free();await physics_frame
func physical_cases():
	r.apply_equipment(1,"light",[3,2,0],"ammo");var s: Dictionary=g.players[1];s.physical=true;s.yaw=0
	var pose: Dictionary={"head":Transform3D(Basis.IDENTITY,Vector3(0,1.65,0)),"left":Transform3D.IDENTITY,"right":Transform3D.IDENTITY,"left_handed":false}
	pose.left.origin=preload("res://deathmatch/tribes/equipment.gd").mount(pose,"pack").origin
	check(r.combat.physical_request(1,"hold_pack",pose,Vector3.ZERO),"VR offhand can grab ammo backpack from tracked chest point")
	var before: int=r.recovery.rows.size()
	check(r.combat.physical_request(1,"transfer",pose,Vector3(1,0,0)) and s.tribes_pack=="none" and r.recovery.rows.size()==before+1,"VR transfer uses checked held item and ordinary ammo pack contents")
	check(not r.combat.physical_request(1,"transfer",pose,Vector3(1,0,0)),"Repeated physical transfer cannot duplicate backpack")
	s.weapon=2;s.tribes_ammo[2]=40;pose.left.origin=preload("res://deathmatch/tribes/equipment.gd").Hip.pouch(pose).origin
	check(r.combat.physical_request(1,"hold_ammo",pose,Vector3.ZERO),"Offhand trigger can request ammo from full tracked hip recovery region")
	check(r.combat.physical_request(1,"transfer",pose,Vector3.ZERO) and s.tribes_ammo[2]==20,"Hip ammo transfer removes exactly one chunk")
	s.physical=false
	r.recovery.reset();r.recovery.spawn_patches([g.fighters[1].position+Vector3.UP*.7])
	s.hp=50;var patch_key: int=r.recovery.rows.keys()[0]
	check(r.recovery.pickup(1,patch_key),"Authored repair-patch marker provides a pickup")
	r.recovery.tick(.01);g.clock+=29;r.recovery.tick(.01)
	check(r.recovery.rows.is_empty(),"Repair patch waits its full respawn interval")
	s.hp=r.definition(1).hp;g.clock+=1.1;r.recovery.tick(.01)
	check(r.recovery.rows.size()==1,"Repair-patch marker replenishes after thirty seconds")
	r.recovery.reset()
func state_cases():
	var data: Dictionary=r.snapshot();check(r.valid_snapshot(data),"Complete field state accepted by production validator")
	check(r.valid_snapshot(Codec.unpack(Codec.pack(data))),"Field state survives production compressed codec")
	var old:=data.duplicate(true)
	for key in ["power","targeting","recovery"]:old.erase(key)
	for row in old.players.values():row.erase("beacons")
	check(r.valid_snapshot(old),"Previous protocol's recording state remains readable")
	var bad:=data.duplicate(true);bad.players[1].beacons=14;check(not r.valid_snapshot(bad),"Oversized beacon inventory rejected")
	bad=data.duplicate(true);bad.power.sources[0]=NAN;check(not r.valid_snapshot(bad),"Nonfinite power state rejected")
	bad=data.duplicate(true);bad.recovery[999]={};check(not r.valid_snapshot(bad),"Malformed recovery inventory rejected")
	bad=data.duplicate(true);bad.targeting.lasers[1]={};check(not r.valid_snapshot(bad),"Malformed designation rejected")
	var s: Dictionary=g.players[1];var ammo: int=s.tribes_ammo[2];s.weapon=2
	check(not r.perform_field(1,"ammo",g.map_epoch-1,s.serial,1),"Stale-map transfer request rejected")
	check(not r.perform_field(1,"ammo",g.map_epoch,s.serial-1,1),"Stale-life transfer request rejected")
	check(r.perform_field(1,"ammo",g.map_epoch,s.serial,1) and s.tribes_ammo[2]==ammo-20,"Valid sequenced transfer consumes inventory once")
	g.clock+=1;check(not r.perform_field(1,"ammo",g.map_epoch,s.serial,1),"Duplicate field request sequence rejected")
	var saved: Dictionary=r.recovery.snapshot();r.recovery.reset();r.recovery.receive(saved)
	check(r.recovery.rows==saved,"Recovered inventory replays without reapplying pickups")
	r.receive(old);check(r.recovery.rows.is_empty() and r.targeting.beacons.is_empty(),"Legacy replay clears newer transient equipment state")
