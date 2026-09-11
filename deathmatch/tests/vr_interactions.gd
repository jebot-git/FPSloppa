extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
const Gesture=preload("res://deathmatch/vr/ability_gesture.gd")
const Clearance=preload("res://deathmatch/vr/weapon_clearance.gd")
var g
var tf
var physical
var failures: Array=[]
var sequence:=0
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize():call_deferred("run")
func role(name: String) -> void:
	g.match_mode.kind="tf";g.players[1].tf_next=name;g._spawn(1);tf.cooldowns[1]=0
	g.players[1].invulnerable=0;g.players[1].yaw=0;g.players[1].physical=true;g.players[1].vr_device=true
	g.fighters[1].position=Fixture.point();g.players[1].xr=Poses.neutral();g.fighters[1].velocity=Vector3.ZERO
func hand(position: Vector3,dt:=.033,left:=true) -> void:
	g.clock+=dt;g.players[1].xr["left" if left else "right"].origin=position
	physical.sample(1)
func request(kind: String,velocity:=Vector3.ZERO,pose: Dictionary={}) -> bool:
	sequence+=1
	return physical.request_for(1,g.map_epoch,g.players[1].serial,sequence,kind,Poses.neutral() if pose.is_empty() else pose,velocity)
func run() -> void:
	test_gesture()
	var unconfigured=preload("res://deathmatch/modes/fortress.gd").new();var child=weakref(unconfigured.physical);unconfigured.free()
	check(child.get_ref()==null,"Freeing unconfigured rules also frees physical interaction node")
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);await physics_frame
	g.start_host("Physical test",0,100,60,true,"tf");g.bots.free();g.bots=null;g.set_physics_process(false)
	tf=g.match_mode.fortress;physical=tf.physical
	for id in g.players:g.fighters[id].position=Fixture.point(-12,-12);g.players[id].team=0
	role("engineer")
	tf.buildings[42]={"owner":1,"team":0,"hp":30,"position":Fixture.point(0,-1),"kind":"sentry","ready":g.clock+100,"next":g.clock+100,"expires":g.clock+120}
	hand(Vector3(0,.8,-.3));hand(Vector3(0,.8,-.55))
	check(tf.buildings[42].hp==70 and g.players[1].ammo[3]==110,"Fresh hand slap repairs 40 HP for 10 cells")
	hand(Vector3(0,.8,-.8),1.1);hand(Vector3(0,.8,-.8))
	check(tf.buildings[42].hp==70,"Resting contact never repeats after cooldown")
	hand(Vector3(0,.8,-.25));hand(Vector3(0,.8,-.6))
	check(tf.buildings[42].hp==110,"Withdraw and slap repairs again")
	hand(Vector3(0,.8,-.25));hand(Vector3(0,.8,-.6))
	check(tf.buildings[42].hp==110,"Repeated rapid slap obeys cooldown")
	tf.cooldowns[1]=0;tf.buildings[42].team=1;hand(Vector3(0,.8,-.25));hand(Vector3(0,.8,-.6))
	check(tf.buildings[42].hp==110,"Enemy building cannot be repaired")
	tf.buildings[42].team=0;physical.history.clear();hand(Vector3(0,.8,-.6))
	check(tf.buildings[42].hp==110,"Initial tracking contact is not a slap")
	hand(Vector3(0,.8,-.25));hand(Vector3(0,.8,-.6),.5)
	check(tf.buildings[42].hp==110,"Stale pose is not a slap")
	physical.history.clear();hand(Vector3(0,.8,-.25));g.players[1].xr.head.origin.z-=.35;hand(Vector3(0,.8,-.6))
	check(tf.buildings[42].hp==110,"Head and hand translation cannot manufacture slap speed")
	g.players[1].xr=Poses.neutral();physical.history.clear();g.players[1].physical=false;hand(Vector3(0,.8,-.25));hand(Vector3(0,.8,-.6))
	check(tf.buildings[42].hp==110,"Disabled physical controls cannot repair")
	role("medic");g.fighters[-2].position=Fixture.point(0,-.9);g.players[-2].hp=40;g.players[-2].dead=false
	hand(Vector3(0,1.15,-.3));hand(Vector3(0,1.15,-.6))
	check(g.players[-2].hp==75,"Medic hand contact heals a teammate")
	g.fighters[-2].position=Fixture.point(-12,-12)
	for name in ["soldier","demoman","pyro"]:
		role(name);var ammo: int=g.players[1].ammo[3 if name=="pyro" else 2]
		check(request("arm") and physical.armed.has(1),name+" arms in offhand")
		check(request("throw",Vector3(0,2,-4)) and tf.charges.has(1),name+" releases server projectile")
		check(tf.charges[1].velocity.distance_to(Vector3(0,2,-4))<.001 and tf.charges[1].position.distance_to(Fixture.point()+Poses.neutral().left.origin)<.02,name+" inherits hand origin and throw motion")
		check(g.players[1].ammo[3 if name=="pyro" else 2]==ammo-(20 if name=="pyro" else 1),name+" consumes exactly one charge cost")
		check(not request("throw",Vector3(0,2,-4)),name+" duplicate release cannot spawn another charge")
		if name=="demoman":
			check(not request("ability"),"Pipe respects arming delay");g.clock+=.71
			check(request("ability") and not tf.charges.has(1),"Offhand action detonates an armed pipe")
	role("soldier");request("arm");check(request("throw") and tf.charges[1].velocity==Vector3.ZERO,"Stationary grip release drops instead of shooting forward")
	role("soldier");request("arm");check(request("throw",Vector3(1000,0,0)) and tf.charges[1].velocity.length()<=12.001,"Throw speed is bounded")
	role("soldier");request("arm");check(request("cancel") and not request("throw") and g.players[1].ammo[2]==12,"Cancellation removes armed state without consuming ammo")
	role("soldier");request("arm");check(not request("throw",Vector3(NAN,0,0)) and not physical.armed.has(1),"Nonfinite throw rejected and disarmed")
	role("soldier");var life: int=g.players[1].serial;var epoch: int=g.map_epoch
	check(not physical.request_for(1,epoch-1,life,sequence+1,"arm",Poses.neutral(),Vector3.ZERO),"Old map request rejected")
	check(not physical.request_for(1,epoch,life-1,sequence+1,"arm",Poses.neutral(),Vector3.ZERO),"Old life request rejected")
	check(request("arm") and not physical.request_for(1,epoch,life,sequence,"throw",Poses.neutral(),Vector3.ZERO),"Replayed request sequence rejected")
	g.clock+=11;check(not request("throw"),"Expired held grenade cannot release")
	role("soldier");g.players[1].dead=true;check(not request("arm"),"Dead players cannot arm")
	role("soldier");g.players[1].spectator=true;check(not request("arm"),"Spectators cannot arm");g.players[1].spectator=false
	role("soldier");g.intermission=5;check(not request("arm"),"Intermission prevents abilities");g.intermission=0
	role("soldier");var left:=Poses.neutral();left.left_handed=true;left.weapon=left.left
	check(request("arm",Vector3.ZERO,left) and request("throw",Vector3.RIGHT,left) and tf.charges[1].position.distance_to(Fixture.point()+left.right.origin)<.02,"Left-handed players throw with right support hand")
	await test_walls_and_rockets()
	await test_assault()
	print("VR_INTERACTIONS_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
func test_gesture() -> void:
	var gesture=Gesture.new();var p:=Vector3(-.3,-.5,-.3)
	check(gesture.sample(p,.02,false,true,true)=="" and not gesture.held,"Offhand trigger alone remains pistol fire")
	check(gesture.sample(p,.02,true,true,true)=="arm","Grip plus offhand trigger arms")
	check(gesture.sample(p,.02,true,true,true)=="","Held chord does not rearm")
	check(gesture.sample(p,.02,false,true,true)=="throw" and gesture.velocity==Vector3.ZERO,"Grip release drops stationary grenade")
	check(gesture.sample(p,.02,true,true,true)=="","Release needs a fresh chord before rearming")
	gesture.sample(p,.02,false,false,true);gesture.sample(p,.02,true,true,true)
	gesture.sample(p+Vector3(0,0,-.12),.03,true,true,true)
	check(gesture.sample(p+Vector3(0,0,-.24),.03,true,false,true)=="throw" and gesture.velocity.z< -1.4,"Throwing stroke plus trigger release throws without grip release")
	gesture.sample(p,.02,false,false,true);gesture.sample(p,.02,true,true,true)
	check(gesture.sample(p,.02,true,true,false)=="cancel" and not gesture.held,"Menu/focus/tracking loss cancels armed grenade")
	check(gesture.sample(p,.02,true,true,true)=="","Returning focus with buttons held cannot arm")
	gesture.sample(p,.02,false,false,true);gesture.sample(p,.02,true,true,true)
	check(gesture.sample(p+Vector3(0,0,-2),.02,true,true,true)=="cancel","Tracking discontinuity cancels throw")
	for hz in [30,60,90,144]:
		var motion=Gesture.new();var dt: float=1.0/hz
		motion.sample(p,dt,true,true,true)
		for i in range(1,roundi(hz*.12)+1):motion.sample(p+Vector3(0,0,-3.0*i*dt),dt,true,true,true)
		var end: Vector3=p+Vector3(0,0,-3.0*(roundi(hz*.12)+1)*dt)
		check(motion.sample(end,dt,false,true,true)=="throw" and absf(motion.velocity.z+3)<.01,"Throw velocity uses elapsed tracking time at %d Hz"%hz)

func test_walls_and_rockets() -> void:
	role("soldier");g.fighters[1].position=Fixture.point(9.5,0)
	var pose:=Poses.neutral();pose.left.origin=Vector3(.8,1.1,0)
	check(not request("arm",Vector3.ZERO,pose),"Hand through a wall cannot arm")
	var space=g.get_world_3d().direct_space_state
	var chest: Vector3=Fixture.point()+Vector3.UP*1.25
	var solution:=Clearance.solve(space,chest,Fixture.point()+Vector3(0,.45,-.3),Fixture.point()+Vector3(0,-.2,-.3),.14)
	check(not solution.blocked and solution.clipped and solution.origin.y>Fixture.ORIGIN.y+.14,"Ground-clipped muzzle is retracted above floor by rocket radius")
	solution=Clearance.solve(space,Fixture.point(9,0)+Vector3.UP*1.25,Fixture.point(9.5,0)+Vector3.UP,Fixture.point(10.5,0)+Vector3.UP,.14)
	check(not solution.blocked and solution.clipped and solution.origin.x<1009.75,"Muzzle through thin wall fires from near side")
	role("soldier");g.match_mode.kind="dm";g.players[1].hp=100;g.players[1].armor=0;g.players[1].cooldown=0
	var down:=Poses.neutral();down.right.origin=Vector3(.25,.45,-.3);down.weapon=Transform3D(Basis(Vector3.RIGHT,-PI/2),down.right.origin)
	g.players[1].xr=down;g.players[1].weapon=6;g.players[1].ammo[2]=10
	var raw: Vector3=g.Art.held_transform(g._weapon_transform(1),6)*g.Art.muzzle(6)
	check(raw.y<Fixture.ORIGIN.y and not g._weapon_blocked(1),"Actual downward rocket muzzle crosses floor yet firing remains enabled")
	g._fire(1);check(g.players[1].ammo[2]==9 and not g.projectiles.is_empty(),"Ground-facing VR rocket fires and consumes one rocket")
	g._update_projectiles(.04)
	check(g.fighters[1].velocity.y>5 and g.players[1].hp>0 and g.players[1].hp<100,"Clamped rocket explodes on floor and launches player with self damage")
	g.fighters[1].position=Fixture.point(9.5,0);down.right.origin=Vector3(.8,1.1,0);down.weapon.origin=down.right.origin;g.players[1].xr=down;g.players[1].cooldown=0
	g._fire(1);check(g._weapon_blocked(1) and g.players[1].ammo[2]==9,"Tracked weapon hand behind wall blocks shot before ammo consumption")
	# Cover above the player still bounds the firing point; close-range fire remains on this side.
	var roof:=Fixture.box(g,Fixture.point()+Vector3.UP*2.3,Vector3(4,.1,4));await physics_frame
	solution=Clearance.solve(space,chest,Fixture.point()+Vector3.UP*1.9,Fixture.point()+Vector3.UP*2.5,.14)
	check(not solution.blocked and solution.clipped and solution.origin.y<Fixture.ORIGIN.y+2.11,"Ceiling-clipped muzzle retracts to safe side")
	roof.queue_free()
func test_assault() -> void:
	g.match_mode.kind="as";g.intermission=0;g.players[1].dead=false;g.players[1].team=0;g.players[1].vr_device=true;g.players[1].physical=true;g.players[1].xr=Poses.neutral();g.fighters[1].position=Fixture.point();g.players[1].yaw=0
	physical.reset();var rules=g.match_mode.assault;rules.stage=0;rules.switching=false;rules.finished=false;rules.attacking=0
	rules.objectives=[{"position":Fixture.point(0,-.75),"title":"First"},{"position":Fixture.point(0,-3),"title":"Final"}]
	rules.tick(.02);check(rules.stage==0,"VR proximity alone does not activate AS console")
	hand(Vector3(0,1.1,-.3));hand(Vector3(0,1.1,-.6))
	check(rules.stage==1,"VR hand press activates current AS button")
	rules.stage=0;physical.reset();g.players[1].team=1;hand(Vector3(0,1.1,-.3));hand(Vector3(0,1.1,-.6))
	check(rules.stage==0,"Defender hand cannot press attacker objective")
	g.players[1].team=0;g.players[1].use_at=0;g._use_for(1)
	check(rules.stage==1,"VR Use fallback activates reachable objective")
	rules.stage=0;g.players[1].vr_device=false;rules.tick(.02)
	check(rules.stage==1,"Desktop proximity activation remains available")
	rules.stage=0;g.players[1].vr_device=true;physical.reset()
	var wall:=Fixture.box(g,Fixture.point()+Vector3(0,1.1,-.42),Vector3(2,2,.05));await physics_frame
	hand(Vector3(0,1.1,-.3));hand(Vector3(0,1.1,-.6))
	check(rules.stage==0,"AS hand press cannot reach through environment")
	wall.queue_free()
	var visuals:=Node3D.new();g.add_child(visuals);rules.draw_button(visuals,0)
	check(visuals.get_child_count()==3 and visuals.get_child(1).position==rules.button_position(0),"Visible button cap matches authoritative touch position")
	visuals.queue_free()
