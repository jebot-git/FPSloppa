extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance";g.start_host("Command checks",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	var r=g.match_mode.tribes;r.set_process(false);var s: Dictionary=g.players[1];s.team=0;s.dead=false;s.spectator=false;s.input_blocked=false
	for id in [21,22,-31]:
		g._add_player(id,"Unit %d"%id);g.players[id].team=1 if id==22 else 0;g.players[id].dead=false;g.players[id].spectator=false;g.players[id].input_blocked=false;g.fighters[id].position=Fixture.ORIGIN+Vector3(id,0,20)
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(200,1,200));g.fighters[1].position=Fixture.ORIGIN+Vector3(0,0,10)
	var d=r.deployables;var remote=r.remote;var cmd=r.commander;var pads=r.stations();pads.playable_bounds=AABB(Fixture.ORIGIN-Vector3(100,1,100),Vector3(200,50,200))
	await physics_frame;await physics_frame
	for key in [1,2]:
		var kind: String="camera" if key==1 else "turret"
		d.rows[key]={"kind":kind,"team":0,"owner":1,"position":Fixture.ORIGIN+Vector3(key*3,0,0),"normal":Vector3.UP,"yaw":0.0,"hp":d.Data.hp(kind),"energy":float(d.Data.KINDS[kind].reserve),"ready":0.0,"aim":Vector3.FORWARD}
	d.sync();await physics_frame
	check(not remote.control(22,1,g.map_epoch,g.players[22].serial),"Enemy cannot claim camera")
	check(not remote.control(1,1,g.map_epoch-1,s.serial) and not remote.control(1,1,g.map_epoch,s.serial-1),"Stale map and life cannot claim")
	check(remote.control(1,1,g.map_epoch,s.serial),"Friendly camera can be claimed")
	check(not remote.control(21,1,g.map_epoch,g.players[21].serial),"Camera claim is exclusive")
	check(not remote.command(21,1,g.map_epoch,g.players[21].serial,Vector3.RIGHT,true),"Another player cannot command occupied camera")
	check(not remote.command(1,1,g.map_epoch,s.serial,Vector3(NAN,0,0),true),"Nonfinite aim rejected")
	check(remote.command(1,1,g.map_epoch,s.serial,Vector3.RIGHT,true),"Owner can aim camera")
	var shots: int=g.projectiles.size()
	for i in 60:remote.advance(1,1.0/60)
	check(d.rows[1].aim.dot(Vector3.RIGHT)>.99 and g.projectiles.size()==shots,"Camera rotates without firing")
	check(remote.control(1,2,g.map_epoch,s.serial) and remote.operated(1)==2 and not remote.operators.has(1),"Claim transfer releases prior device")
	remote.command(1,2,g.map_epoch,s.serial,Vector3.FORWARD,true);var before: float=d.rows[2].energy;d.tick(.1)
	check(g.projectiles.size()>shots and d.rows[2].energy<before,"Manual deployed turret fires and spends real capacitor")
	var count: int=g.projectiles.size();d.tick(.1);check(g.projectiles.size()==count,"Manual turret respects fire cycle")
	s.input_blocked=true;g.clock+=1;d.tick(.1);check(g.projectiles.size()==count,"Blocked input suppresses held remote fire");s.input_blocked=false
	remote.tick();check(remote.operated(1)<0,"Lost control packets expire lease")
	remote.control(1,2,g.map_epoch,s.serial);s.dead=true;remote.tick();check(remote.operated(1)<0,"Death releases device");s.dead=false
	remote.control(1,1,g.map_epoch,s.serial);d.rows[1].hp=d.Data.hp("camera")*.4;remote.tick();check(remote.operated(1)<0,"Disabled camera releases device");d.rows[1].hp=d.Data.hp("camera")
	var fixed: int=range(pads.defences.rows.size()).filter(func(i):return pads.defences.rows[i].team==0)[0]
	pads.defences.control(1,fixed,g.map_epoch,s.serial);remote.control(1,1,g.map_epoch,s.serial)
	check(pads.defences.operated(1)<0 and r.operating(1),"Remote claim releases fixed turret")
	r.turret_control(fixed,g.map_epoch,s.serial);check(remote.operated(1)<0 and pads.defences.operated(1)==fixed,"Fixed turret claim releases remote device");pads.defences.release(1)
	var point:=Fixture.ORIGIN+Vector3(10,0,-10)
	check(cmd.request(1,g.map_epoch,s.serial,1,"move",[1],point),"Self waypoint accepted")
	g.clock+=.2;check(not cmd.request(1,g.map_epoch,s.serial,2,"attack",[21],point),"Human orders require voluntary command relationship")
	check(cmd.follow(21,1) and not cmd.follow(1,21),"Commander relationship rejects cycles")
	g.clock+=.2;check(cmd.request(1,g.map_epoch,s.serial,3,"attack",[21],point) and cmd.orders[21].status=="pending","Team command awaits human acknowledgement")
	check(cmd.request(21,g.map_epoch,g.players[21].serial,1,"accept",[],Vector3.ZERO) and cmd.orders[21].status=="accepted","Recipient acknowledges order")
	g.clock+=.2;check(cmd.request(21,g.map_epoch,g.players[21].serial,2,"complete",[],Vector3.ZERO) and cmd.orders[21].status=="complete","Recipient completes order")
	g.clock+=.2;check(not cmd.request(1,g.map_epoch,s.serial,4,"attack",[22],point),"Enemy units cannot receive team commands")
	g.clock+=.2;check(cmd.request(1,g.map_epoch,s.serial,5,"defend",[-31],point) and cmd.commanders[-31]==1 and cmd.orders[-31].status=="accepted","Unassigned bot accepts human commander")
	var goals: Array=[];check(cmd.bot_goal(-31,g.bots,goals) and not goals.is_empty(),"Accepted bot order enters existing objective planner")
	g.clock+=.2;check(not cmd.request(1,g.map_epoch,s.serial,5,"move",[1],point),"Replayed order sequence rejected")
	check(not cmd.request(1,g.map_epoch,s.serial,6,"move",[1],Vector3.INF),"Invalid waypoint rejected")
	g.clock+=.2;check(not cmd.request(1,g.map_epoch,s.serial,7,"move",[1],Vector3.ZERO),"Off-map waypoint rejected")
	g.players[-31].serial+=1;cmd.tick();check(not cmd.orders.has(-31),"Respawn expires old-life order")
	check(cmd.valid(cmd.snapshot()) and remote.valid(remote.snapshot()),"Current command state validates")
	check(not cmd.valid({"commanders":{1:21,21:1},"orders":{}}),"Cyclic snapshot rejected")
	check(not cmd.valid({"commanders":{1:21,21:"bad"},"orders":{}}),"Malformed hierarchy rejected without indexing unsafe data")
	check(r.valid_snapshot(r.snapshot()),"New full ST snapshot validates")
	var old: Dictionary=r.snapshot();old.erase("command");old.erase("remote");check(r.valid_snapshot(old),"Previous ST recording schema remains readable")
	# Actual Scout launch uses checked controller aim, never cosmetic hull pitch.
	r.vehicles.rows[1]={"kind":"scout","position":Fixture.ORIGIN+Vector3.UP*10,"velocity":Vector3.ZERO,"yaw":0.0,"pitch":-.12,"bank":0.0,"hp":r.vehicles.Data.HP,"pilot":1,"life":s.serial,"passengers":[],"passenger_lives":[],"team":0,"owner_team":0,"ready":0.0,"next_fire":0.0,"idle_until":1000.0}
	r.vehicles.make_body(1);s.vr_device=true;s.xr=Poses.neutral();s.xr.weapon.basis=Basis(Vector3.UP,.35)*Basis(Vector3.RIGHT,.2);s.yaw=0
	check(r.vehicles.fire(1),"Scout rocket launches with controller aim")
	if not r.vehicles.rockets.is_empty():check(r.vehicles.rockets.values()[0].direction.is_equal_approx(-s.xr.weapon.basis.z),"Rocket direction is independent of cosmetic hull pitch")
	for kind in ["scout","lpc","hpc"]:
		var row={"kind":kind,"velocity":Vector3(0,0,-15),"yaw":0.0,"pitch":0.0,"bank":0.0}
		var control=r.vehicles.Data.controls({"vr_device":true,"fly":0.0,"move":Vector2(0,-1)})
		r.vehicles.Data.advance(row,control,5,.1)
		check(row.pitch<0 and row.velocity.y==0,kind+" forward nose tilt cannot alter altitude")
		row.velocity=Vector3.ZERO;control.move=Vector2.ZERO;control.lift=1
		for i in 10:r.vehicles.Data.advance(row,control,5,.1)
		check(row.pitch>0 and row.velocity.y>0,kind+" pure ascent noses up")
		control.move=Vector2.RIGHT
		for i in 10:r.vehicles.Data.advance(row,control,5,.1)
		check(row.pitch<=.0001,kind+" ascending strafe does not nose up")
	r.vehicles.reset();g.disconnect_game();g.free();print("ST_COMMAND ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
