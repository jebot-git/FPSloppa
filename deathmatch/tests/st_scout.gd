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
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("Scout integration",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g.players[1].team=0;g.players[1].spectator=false;g.players[1].input_blocked=false
	g._add_player(-1,"Other");g.players[-1].team=1;g.players[-1].input_blocked=false
	var rules=g.match_mode.tribes;var c=rules.vehicles;var pads=rules.stations();var s: Dictionary=g.players[1];var actor=g.fighters[1]
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame
	check(pads.rows.filter(func(row):return row.kind=="vehicle").size()==2,"Both Raindance vehicle pads have powered purchase terminals")
	var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==0)[0]
	actor.position=pads.rows[index].position;actor.velocity=Vector3.ZERO;rules.energy[0]=5000
	rules.apply_equipment(1,"light",[3,2,0],"energy")
	check(c.station(1)==index,"Friendly terminal reachable on actual pad")
	var before: int=rules.energy[0]
	check(not c.purchase(1,g.map_epoch+1,s.serial) and rules.energy[0]==before,"Stale map purchase rejected without spending")
	pads.health[0]=0
	check(not c.purchase(1,g.map_epoch,s.serial),"Unpowered vehicle terminal rejects purchases")
	pads.health[0]=300;g.clock+=1
	check(c.purchase(1,g.map_epoch,s.serial),"Scout bought from actual Raindance pad")
	check(rules.energy[0]==before-600 and c.rows.size()==1,"Purchase spends exactly 600 energy")
	if c.rows.is_empty():finish();return
	var key: int=c.rows.keys()[0]
	check(not c.purchase(1,g.map_epoch,s.serial) and rules.energy[0]==before-600,"Repeated purchase cannot duplicate or double-charge")
	g.clock+=4;actor.position=c.frame(c.rows[key])*Vector3(2.7,0,0)
	check(c.board(1,key),"Light pilot boards through clear cockpit approach")
	check(not c.board(-1,key),"Occupied seat cannot be stolen")
	check(c.valid(c.snapshot()) and rules.valid_snapshot(rules.snapshot()),"Production snapshot accepts Scout state")
	var bad: Dictionary=c.snapshot();bad.rows[key].velocity=Vector3(NAN,0,0);check(not c.valid(bad),"Non-finite flight snapshot rejected")
	bad=c.snapshot();bad.rows[key].hp=-1;check(not c.valid(bad),"Invalid hull health rejected")
	check(not g.match_mode.st.can_take(1,1),"Mounted pilot cannot acquire a flag during flight")
	check(pads.defences.warm(1),"Occupied Scout presents a hot target to missile turrets")
	check(not rules.can_refit(1),"Mounted pilot cannot refit to heavier armour")
	# Open synthetic pad isolates flight/control tests from natural terrain.
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP,Vector3(700,2,700));await physics_frame
	c.rows[key].position=Fixture.ORIGIN+Vector3.UP*2;c.rows[key].velocity=Vector3.ZERO;c.bodies[key].position=c.rows[key].position
	s.move=Vector2.ZERO;s.yaw=0;s.pitch=0;s.jet_held=true;s.fire=false;s.jump=false
	var start: Vector3=c.rows[key].position
	for f in 120:
		g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
	check(c.rows.has(key) and c.rows[key].position.y>start.y+12,"Held jet produces real vertical takeoff")
	s.jet_held=false;s.move=Vector2(0,-1)
	for f in 240:
		g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
	check(-c.rows[key].velocity.z>45 and c.rows[key].velocity.length()<51,"Scout accelerates toward original 50 m/s cruise")
	check(actor.position.distance_to(c.frame(c.rows[key])*c.Data.SEAT)<.001,"Pilot remains attached during sustained flight")
	check(c.fire(key),"Scout fires a rocket")
	check(not c.fire(key) and c.rockets.size()==1,"Two-second rocket reload prevents repeated fire")
	check(c.valid(c.snapshot()),"Rocket state passes production snapshot validation")
	var rocket: Dictionary=c.rockets.values()[0]
	check(absf(rocket.velocity.z-(c.rows[key].velocity.z*.5-65))<.01,"Rocket inherits half of vehicle velocity")
	c.rockets.clear()
	var flying_velocity: Vector3=c.rows[key].velocity
	check(c.leave(1),"Pilot can eject from open flight")
	check(not c.mounted(1) and actor.velocity.z==flying_velocity.z and actor.velocity.y>flying_velocity.y,"Ejection retains momentum and supplies upward separation")
	check(not c.board(1,key),"Ejection cooldown prevents immediate reboarding")
	g.clock+=4;actor.position=c.frame(c.rows[key])*Vector3(2.7,0,0)
	rules.apply_equipment(1,"heavy",[3,2,0],"energy")
	check(not c.board(1,key),"Heavy armour cannot pilot Scout")
	rules.apply_equipment(1,"light",[3,2,0],"energy");g.match_mode.flags[1].carrier=1
	check(not c.board(1,key),"Flag carrier cannot board Scout")
	g.match_mode.return_flag(1)
	g.fighters[-1].position=actor.position;rules.apply_equipment(-1,"light",[3,2,0],"energy")
	check(c.board(-1,key) and c.rows[key].team==1 and c.rows[key].owner_team==0,"Enemy can steal an empty Scout while original purchase limit remains charged")
	c.leave(-1,true);g.fighters[-1].position=Fixture.ORIGIN+Vector3(200,0,100)
	var hp: float=c.rows[key].hp;c.damage(key,1,10,"Blaster")
	check(is_equal_approx(c.rows[key].hp,hp-5),"Scout takes half blaster damage")
	hp=c.rows[key].hp;c.damage(key,-1,10,"DISC LAUNCHER")
	check(c.rows[key].hp==hp,"Friendly fire policy protects friendly hull")
	c.blast(c.rows[key].position,0,10,5,1)
	check(c.rows[key].hp==hp,"Friendly autonomous turret blast cannot damage its Scout")
	check(c.repair(key,-1,3) and c.rows[key].hp>hp,"Repair gun restores friendly hull")
	var at: Vector3=c.rows[key].position
	var hit: Dictionary=g._trace(at+Vector3(0,0,-20),at+Vector3(0,0,20),1)
	check(hit.get("scout",0)==key,"Ordinary combat trace identifies Scout hull")
	g._damage_map_hit(hit,1,1000,"Disc")
	check(not c.rows.has(key),"Destruction removes hull and releases team limit")
	# Stale/disconnected/blocked pilot input must stop sustained fire and lift.
	actor.position=pads.rows[index].position;s.input_blocked=false;g.clock+=1
	await physics_frame;await physics_frame
	check(c.purchase(1,g.map_epoch,s.serial),"Replacement purchase succeeds after destruction")
	if c.rows.is_empty():finish();return
	key=c.rows.keys()[0];g.clock+=4;actor.position=c.frame(c.rows[key])*Vector3(2.7,0,0);check(c.board(1,key),"Replacement craft can be boarded")
	c.rows[key].position=Fixture.ORIGIN+Vector3.UP*15;c.bodies[key].position=c.rows[key].position;c.rows[key].velocity=Vector3.ZERO
	s.jet_held=true;s.fire=true;s.last_input=g.clock-1;g.clock+=1.0/60;c.tick(1.0/60)
	check(c.rockets.is_empty() and c.rows[key].velocity.y<0,"Lost input releases vehicle thrust and weapons")
	c.departed(1);check(not c.mounted(1),"Disconnect releases seat")
	# A destroyed pilot and a clear-air ceiling use the same authority path.
	g.clock+=4;actor.position=c.frame(c.rows[key])*Vector3(2.7,0,0);s.last_input=g.clock;s.fire=false;s.jet_held=true
	check(c.board(1,key),"Reboarding works after cooldown")
	c.rows[key].position=Fixture.ORIGIN+Vector3.UP*24;c.rows[key].velocity=Vector3.ZERO;c.bodies[key].position=c.rows[key].position
	var peak:=0.0
	for f in 240:
		g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60);peak=maxf(peak,c.rows[key].position.y-Fixture.ORIGIN.y)
	check(peak<26 and peak>24,"Scout respects low 25 m terrain-relative ceiling")
	s.dead=true;c.tick(1.0/60);check(not c.mounted(1),"Pilot death releases the seat")
	s.dead=false
	c.reset();check(c.rows.is_empty() and c.bodies.is_empty() and c.rockets.is_empty(),"Reset clears all vehicle state")
	actor.position=pads.rows[index].position;s.input_blocked=false;g.clock+=1
	await physics_frame;await physics_frame
	rules.energy[0]=599
	check(not c.purchase(1,g.map_epoch,s.serial) and rules.energy[0]==599,"Insufficient team funds reject without partial charge")
	rules.energy[0]=5000;g.clock+=1
	var blocker=Fixture.box(g,c.spawn_frame(index).origin,Vector3.ONE)
	await physics_frame;await physics_frame
	check(not c.purchase(1,g.map_epoch,s.serial) and rules.energy[0]==5000,"Blocked pad cannot create an overlapping hull or spend energy")
	blocker.free();await physics_frame;await physics_frame
	for n in 3:
		g.clock+=1;check(c.purchase(1,g.map_epoch,s.serial),"Team Scout reservation %d"%(n+1))
		var new_key: int=c.rows.keys()[-1];c.rows[new_key].position=Fixture.ORIGIN+Vector3(n*10,8,0);c.bodies[new_key].position=c.rows[new_key].position
		await physics_frame;await physics_frame
	var money: int=rules.energy[0];g.clock+=1
	check(not c.purchase(1,g.map_epoch,s.serial) and rules.energy[0]==money,"Three-Scout team limit is enforced atomically")
	var saved: Dictionary=c.snapshot();var malformed: Dictionary=saved.duplicate(true);malformed.rows[malformed.rows.keys()[0]].erase("pilot");malformed.rows[malformed.rows.keys()[0]]["fake"]=0
	check(not c.valid(malformed),"Renamed snapshot fields reject without script errors")
	c.reset();c.receive(saved);check(c.rows.size()==3 and c.bodies.size()==3,"Replay snapshot recreates unoccupied hulls")
	# A thin solid wall must stop a full-speed hull and a rocket sweep.
	for remove_key in c.rows.keys().slice(1):c.remove(remove_key)
	key=c.rows.keys()[0];c.rows[key].position=Fixture.ORIGIN+Vector3(0,5,0);c.bodies[key].position=c.rows[key].position;c.rows[key].yaw=0;c.rows[key].velocity=Vector3(0,0,-50)
	var wall=Fixture.box(g,Fixture.ORIGIN+Vector3(0,5,-5),Vector3(15,12,.2))
	await physics_frame;await physics_frame
	for f in 12:
		g.clock+=1.0/60;c.tick(1.0/60)
		if not c.rows.has(key):break
	check(not c.rows.has(key),"Swept high-speed impact stops and destroys hull at a thin wall")
	wall.free();await physics_frame;await physics_frame
	actor.position=pads.rows[index].position;g.clock+=1;check(c.purchase(1,g.map_epoch,s.serial),"Rocket collision fixture purchase succeeds")
	key=c.rows.keys()[0];g.clock+=4;c.rows[key].position=Fixture.ORIGIN+Vector3(0,5,0);c.bodies[key].position=c.rows[key].position
	actor.position=c.frame(c.rows[key])*Vector3(2.7,0,0);c.board(1,key)
	wall=Fixture.box(g,Fixture.ORIGIN+Vector3(0,5,-8),Vector3(15,12,.2));g.fighters[-1].position=Fixture.ORIGIN+Vector3(0,5,-10);g.players[-1].invulnerable=0
	await physics_frame;await physics_frame
	var enemy_hp: int=g.players[-1].hp;s.fire=false;s.jet_held=false;s.move=Vector2.ZERO
	check(c.fire(key),"Rocket can launch toward a world obstacle")
	for f in 20:
		g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
	check(c.rockets.is_empty(),"Rocket sweep detonates on solid BSP-compatible collision")
	check(g.players[-1].hp==enemy_hp,"Rocket splash cannot damage a player behind solid cover")
	c.reset();wall.free();finish()
func finish():
	print("ST_SCOUT ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
