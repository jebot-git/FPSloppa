extends SceneTree
var g
var de
var u
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func reset_players():
	for id in g.players:
		g.players[id].dead=false;g.players[id].hp=100;g.players[id].armor=0;g.players[id].invulnerable=0;g.players[id].input_blocked=false;g.players[id].last_input=g.clock
	de.phase="live";de.carrier=0;de.held=false;de.defuser=0
func grenade(kind: int,pos: Vector3,owner_id: int=1):
	u.next_id+=1;u.flying[u.next_id]={"kind":kind,"owner":owner_id,"position":pos,"velocity":Vector3.ZERO,"age":1.5,"ground":true};u.detonate(u.next_id)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.start_host("DE utility",0,20,10,true,"de")
	g.bots.free();g.bots=null;g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	de=g.match_mode.defusal;u=de.utility;de.tick(0);de.credit(1,15000)
	var cash: int=de.account(1).cash
	check(de.buy(1,110) and de.account(1).cash==cash-300,"HE costs $300")
	check(not de.buy(1,110) and u.state(1).counts[0]==1,"HE carry limit one")
	check(de.buy(1,111) and de.buy(1,111) and not de.buy(1,111),"Flash costs $200 and carry limit two")
	check(de.buy(1,112) and not de.buy(1,112),"Smoke costs $300 and carry limit one")
	check(not u.equip(1,0),"Preparation cannot equip throwable")
	check(not de.offers(1).filter(func(row):return row.id==110)[0].usable,"Full grenade slot disabled in shop")
	reset_players();var id2: int=g.players.keys().filter(func(id):return id!=1)[0]
	var home: Vector3=de.starts[0][0];g.fighters[1].position=home;g.fighters[id2].position=home+Vector3(0,0,-3)
	check(u.equip(1,0) and de.combat_blocked(1),"Equipped grenade holsters gun and blocks firing")
	var s: Dictionary=g.players[1];s.fire=true;s.last_input=g.clock;u.sample_player(1)
	check(u.state(1).primed and u.flying.is_empty(),"Holding fire pulls pin without starting fuse")
	g.clock+=2;s.last_input=g.clock;u.sample_player(1)
	check(u.flying.is_empty() and u.state(1).counts[0]==1,"Grenades cannot be cooked in hand")
	s.fire=false;u.sample_player(1)
	check(u.flying.size()==1 and u.state(1).counts[0]==0 and u.selected(1)==-1,"Release consumes one grenade and restores gun")
	var shot: Dictionary=u.flying.values()[0]
	check(shot.age==0 and shot.velocity.length()<=28,"Authority starts bounded throw with fresh fuse")
	u.flying.clear();u.state(1).cooldown=0;u.state(1).counts=[1,2,1];u.equip(1,0);s.input_blocked=true;u.sample_player(1)
	check(u.selected(1)==-1 and u.state(1).counts[0]==1,"Opening menu safely cancels held grenade")
	s.input_blocked=false;u.equip(1,0);s.last_input=g.clock-1;u.sample_player(1)
	check(u.selected(1)==-1,"Stale input cannot release a grenade")
	s.last_input=g.clock;u.equip(1,0);s.dead=true
	check(not u.throw_grenade(1),"Dead players cannot throw")
	reset_players();u.cancel(1);s.weapon=1
	grenade(0,g.fighters[id2].position+Vector3.UP*.9+Vector3(0,0,1))
	check(g.players[id2].hp<100 and g.players[id2].hp>0,"HE applies distance-scaled blast damage")
	reset_players();g.fighters[id2].position=home+Vector3(0,0,-30);grenade(0,home+Vector3.UP)
	check(g.players[id2].hp==100,"HE does not damage beyond 350-unit radius")
	# A dedicated box shields both HE and flash, with players otherwise in range.
	g.fighters[id2].position=home+Vector3(0,0,-3)
	var wall:=StaticBody3D.new();wall.collision_layer=1;var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(5,5,.2);shape.shape=box;wall.add_child(shape);g.add_child(wall);wall.position=home+Vector3(0,1,-1.5)
	await physics_frame;await physics_frame
	grenade(0,home+Vector3.UP);check(g.players[id2].hp==100,"Solid walls shield HE")
	grenade(1,home+Vector3.UP);check(u.flash_amount(id2)==0,"Solid walls shield flash")
	wall.free();await physics_frame;reset_players();u.flashes.clear();g.players[id2].yaw=PI;g.players[id2].pitch=0
	grenade(1,home+Vector3.UP*1.4);var front: float=u.flash_amount(id2);var front_duration: float=u.flashes[id2].end-g.clock
	check(front>.99,"Facing flash fully blinds")
	u.flashes.clear();g.players[id2].yaw=0;grenade(1,home+Vector3.UP*1.4)
	check(u.flash_amount(id2)<front and u.flashes[id2].end-g.clock<front_duration,"Looking away reduces flash intensity and duration")
	u.flashes.clear();g.players[id2].team=g.players[1].team;grenade(1,home+Vector3.UP*1.4)
	check(u.flash_amount(id2)>0 and u.flash_amount(1)>0,"Flash affects teammates and thrower")
	var until: float=u.flashes[id2].end;g.clock=until+1;check(u.flash_amount(id2)==0,"Flash decays completely")
	grenade(2,home+Vector3.UP*.1);var cloud: Dictionary=u.clouds.values()[0];cloud.age=2
	check(u.obscured(home+Vector3(-5,1,0),home+Vector3(5,1,0)),"Smoke blocks bot sight through the cloud")
	check(not u.obscured(home+Vector3(-5,8,0),home+Vector3(5,8,0)),"Smoke does not block distant clear sightlines")
	check(u.smoke_amount(cloud.position)>.95,"Inside smoke receives dense view overlay")
	cloud.age=19;check(u.cloud_density(cloud.age)<.5,"Smoke fades before expiration")
	u.tick(1.1);check(u.clouds.is_empty(),"Smoke expires after twenty seconds")
	reset_players();u.state(1).counts=[1,2,1];u.state(1).cooldown=0;u.equip(1,2);u.throw_grenade(1,Vector3(0,4,0))
	u.tick(1.6);check(u.clouds.is_empty(),"Smoke waits until it lands after fuse")
	for step in 300:
		g.clock+=1.0/60;u.tick(1.0/60)
	check(not u.clouds.is_empty() and u.flying.is_empty(),"Bouncing smoke settles and emits")
	var data: Dictionary=u.snapshot();check(u.valid_snapshot(data),"Grenade and smoke snapshot is valid")
	var bad: Dictionary=data.duplicate(true);bad.inventory[1][0][0]=999;check(not u.valid_snapshot(bad),"Snapshot rejects excess inventory")
	bad=data.duplicate(true);bad.smoke[0][1]=Vector3(INF,0,0);check(not u.valid_snapshot(bad),"Snapshot rejects nonfinite smoke position")
	var before: Array=u.state(1).counts.duplicate();u.receive(data);check(u.state(1).counts==before and not u.clouds.is_empty(),"Snapshot round-trip restores inventory and smoke")
	u.on_death(1);check(u.state(1).counts==[0,0,0] and u.selected(1)==-1,"Death clears utility inventory and selection")
	u.new_round();check(u.clouds.is_empty() and u.flying.is_empty() and u.flashes.is_empty(),"Next round clears all grenade effects")
	# Simulated tracked controller input exercises primary/left-handed throws.
	for left in [false,true]:
		reset_players();s.vr_device=true;s.weapon=1;s.yaw=0.0;g.fighters[1].position=home
		var pose: Dictionary=load("res://deathmatch/vr/poses.gd").neutral();pose.left_handed=left
		pose.weapon=Transform3D(Basis.IDENTITY,Vector3(.15,1.25,-.35));pose["left" if left else "right"]=pose.weapon
		s.xr=load("res://deathmatch/vr/poses.gd").validate(pose)
		u.state(1).counts=[1,2,1];u.state(1).cooldown=0;u.equip(1,0);s.de_trigger=true;s.last_input=g.clock;u.sample_player(1)
		check(u.state(1).primed,"Tracked trigger primes grenade, handed="+str(left))
		for frame in 40:
			g.clock+=1.0/60;s.last_input=g.clock;s.xr.weapon.origin.z-=.008;s.xr["left" if left else "right"]=s.xr.weapon;u.sample_player(1)
		s.de_trigger=false;u.sample_player(1)
		check(u.flying.size()==1 and u.selected(1)==-1,"Tracked release throws once, handed="+str(left))
		check(u.flying.values()[0].velocity.z<-3 and u.flying.values()[0].velocity.length()<=28,"Controller motion contributes bounded velocity, handed="+str(left))
		u.flying.clear();u.state(1).cooldown=0;u.equip(1,1);s.xr={};s.last_input=g.clock;u.sample_player(1)
		check(u.selected(1)==-1 and u.state(1).counts[1]==2,"Tracking/input loss cancels without consumption, handed="+str(left))
	s.vr_device=false;s.xr={};u.state(987654);u.tick(0)
	check(not u.states.has(987654),"Disconnected players leave no utility snapshot entries")
	g.match_mode.kind="dm";check(u.inventory(1).is_empty() and not u.equip(1,0),"Arena modes do not expose DE utility")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/classic-de/grenades.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("DE_GRENADE_RESULT ",JSON.stringify(result));g.disconnect_game();g.free();await process_frame;quit(0 if failures.is_empty() else 1)
