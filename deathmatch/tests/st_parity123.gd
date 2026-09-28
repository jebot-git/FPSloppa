extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Ballistics=preload("res://deathmatch/tribes/ballistics.gd")
const Codec=preload("res://deathmatch/network/codec.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	seed(2391);g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST parity",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Support");g._add_player(-2,"Opponent")
	g.players[1].team=0;g.players[-1].team=0;g.players[-2].team=1
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(500,1,500))
	for id in g.players:g.fighters[id].position=Fixture.ORIGIN+Vector3(100+id*10,0,100)
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame
	await fixed_cases()
	await offense_cases()
	await construction_cases()
	role_cases()
	await movement_skill_cases()
	print("ST_PARITY123 ",JSON.stringify({"checks":checks,"failures":failures,"offense":g.bots.tribes.offense.stats}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
func fixed_cases():
	var rules=g.match_mode.tribes;var pads=rules.stations();var fixed=pads.defences
	check(fixed.rows.size()==2 and fixed.rows.all(func(row):return row.kind=="fusion"),"Stonehenge sockets create two fusion turrets")
	var row: Dictionary=fixed.rows[0];var old: Vector3=row.position;row.position=Fixture.ORIGIN;row.aim=Vector3.FORWARD
	# Move its actual fixture to the isolated test floor, preserving its hitbox.
	var body
	for child in pads.get_children():
		if child is StaticBody3D and child.global_position.distance_to(old)<.01:body=child;break
	check(body!=null,"Fixed defence has a physical collision fixture")
	if body==null:return
	body.global_position=row.position
	g.players[1].team=row.team;g.players[-1].team=row.team;g.players[-2].team=1-row.team
	g.fighters[-2].position=row.position+Vector3(0,0,-20);g.fighters[-2].velocity=Vector3.ZERO
	await physics_frame
	var origin: Vector3=fixed.eye(0)+Vector3(0,0,-6);var hit: Dictionary=g._trace(origin,fixed.eye(0),-2)
	check(hit.get("fixed_turret",-1)==0,"Weapon trace identifies fixed turret collision")
	g._damage_map_hit(hit,1,10000);check(row.hp==fixed.Data.hp(row.kind),"Friendly fire protects fixed turret")
	g._damage_map_hit(hit,-2,10000);check(row.hp==0 and not fixed.active(0),"Enemy damage disables a fixed turret")
	check(not fixed.repair(0,-2,20),"Enemy cannot repair fixed turret")
	rules.apply_equipment(1,"light",[3,2,0],"repair")
	rules.combat.beam(1,8,origin,(fixed.eye(0)-origin).normalized(),1)
	check(row.hp>0,"Actual repair beam restores fixed turret")
	fixed.repair(0,1,10000);pads.health[row.team]=0
	check(not fixed.active(0),"Power outage disables fixed turret")
	pads.health[row.team]=pads.GENERATOR_HP
	check(fixed.acquire(0)==-2,"Fusion turret detects a stationary exposed opponent")
	var wall=Fixture.box(g,row.position+Vector3(0,2,-10),Vector3(10,8,1));await physics_frame
	check(fixed.acquire(0)==0,"World cover blocks automatic turret acquisition")
	wall.free();await physics_frame
	row.kind="missile";row.energy=100;row.hp=fixed.Data.hp("missile")
	check(fixed.acquire(0)==0,"Missile turret ignores a cold opponent")
	fixed.heat[-2]=g.clock+.75;check(fixed.acquire(0)==-2,"Missile turret acquires recent jet heat")
	g.clock+=1;check(fixed.acquire(0)==0,"Jet heat expires without permanent tracking")
	row.kind="mortar";row.energy=45;row.hp=fixed.Data.hp("mortar")
	check(fixed.acquire(0)==0,"Mortar turret waits for manual control")
	row.kind="fusion";row.energy=200;row.hp=fixed.Data.hp("fusion")
	check(not fixed.control(-2,0,g.map_epoch,g.players[-2].serial),"Enemy cannot seize a friendly fixed turret")
	check(not fixed.control(1,0,g.map_epoch-1,g.players[1].serial),"Stale-map turret claim rejected")
	check(fixed.control(1,0,g.map_epoch,g.players[1].serial),"Friendly live player can take manual control")
	check(not fixed.control(-1,0,g.map_epoch,g.players[-1].serial),"Turret has only one operator")
	check(not fixed.command(1,0,g.map_epoch,g.players[1].serial,Vector3(NAN,0,0),true),"Malformed aiming command rejected")
	check(fixed.command(1,0,g.map_epoch,g.players[1].serial,Vector3.FORWARD,true),"Live normalized aim and fire accepted")
	var ammo: int=rules.amount(1,3);g.players[1].weapon=3;g.players[1].cooldown=0
	check(not rules.combat.fire(1) and rules.amount(1,3)==ammo,"Remote operation cannot also fire the carried weapon")
	var count: int=g.projectiles.size();fixed.tick(.1)
	check(g.projectiles.size()>count and row.energy<200,"Manual fire creates a real projectile and consumes turret energy")
	row.fire_at=0;row.energy=0;check(not fixed.fire(0),"Empty turret cannot fire")
	row.energy=200;g.clock+=1;fixed.tick(.01)
	check(row.operator==0,"Lost manual commands release the turret lease")
	fixed.control(1,0,g.map_epoch,g.players[1].serial);g._use_for(1)
	check(row.operator==0,"Shared desktop/VR Use action releases turret without activating a backpack")
	fixed.control(1,0,g.map_epoch,g.players[1].serial);g.players[1].dead=true;fixed.tick(.01)
	check(row.operator==0,"Operator death releases control")
	g.players[1].dead=false
	var state: Dictionary=rules.snapshot()
	check(rules.valid_snapshot(state) and rules.valid_snapshot(Codec.unpack(Codec.pack(state))),"Fixed defence state survives the production network codec")
	var bad:=state.duplicate(true);bad.fixed_defences[0][2]=Vector3.INF;check(not rules.valid_snapshot(bad),"Nonfinite replicated turret aim rejected")
	bad=state.duplicate(true);bad.fixed_defences.resize(65);check(not rules.valid_snapshot(bad),"Unbounded fixed defence state rejected")
	for kind in fixed.Data.TYPES:
		var d: Dictionary=fixed.Data.projectile(kind,0,-2)
		check(d.damage>0 and d.turret_team==0 and d.fixed_turret==kind,"Distinct projectile definition: "+kind)
	row.kind="mini";row.hp=fixed.Data.hp("mini");row.energy=60;row.fire_at=0
	check(fixed.acquire(0)==0,"Indoor mini sensor ignores an unreported stationary opponent")
	rules.deployables.contacts[row.team]=[-2]
	check(fixed.acquire(0)==-2,"Reported opponent is available to indoor turret with physical LOS")
	rules.deployables.contacts[row.team]=[]
	row.kind="elf";row.hp=fixed.Data.hp("elf");row.energy=150;row.fire_at=0
	row.aim=(g.fighters[-2].position+Vector3.UP*g.fighters[-2].torso_height()-fixed.eye(0)).normalized()
	g.fighters[-2].tribes_state.energy=60;g.players[-2].invulnerable=0;g.players[-2].hp=100
	var initial: int=g.players[-2].hp
	for frame in 10:g.clock+=.11;fixed.fire(0)
	check(g.fighters[-2].tribes_state.energy==0 and g.players[-2].hp<initial and row.energy<150,"ELF beam drains real target energy and health, consuming its own energy")
	row.kind="mortar";row.energy=45;row.hp=fixed.Data.hp("mortar");row.fire_at=0;row.aim=Vector3(0,.7,-.7).normalized()
	check(fixed.fire(0) and row.energy==0,"Manual mortar launches a real shell and exhausts its capacitor")
	var shell: Dictionary=g.projectiles[g.projectiles.keys()[-1]];var start_velocity: Vector3=shell.velocity
	g._update_projectiles(.1)
	check(shell.velocity.y<start_velocity.y,"Fixed mortar shell follows ordinary projectile gravity")
	row.kind="missile";row.energy=100;row.hp=fixed.Data.hp("missile");row.fire_at=0;row.target=-2;row.aim=Vector3.FORWARD
	g.fighters[-2].position=row.position+Vector3(7,0,-35);fixed.heat[-2]=g.clock+.75
	check(fixed.fire(0),"Missile turret launches an actual guided projectile")
	var missile: Dictionary=g.projectiles[g.projectiles.keys()[-1]];var initial_direction:=Vector3(missile.velocity).normalized()
	g._update_projectiles(.02)
	check(missile.velocity.x>initial_direction.x+.01 and is_equal_approx(missile.velocity.length(),72),"Launched missile turns toward a hot target at normal missile speed")
	fixed.heat.clear();var unpowered_direction: Vector3=missile.velocity;g.fighters[-2].position+=Vector3(-20,0,0);g._update_projectiles(.02)
	check(missile.velocity.is_equal_approx(unpowered_direction),"Cold target ends guidance and leaves the missile on its current course")
	row.kind="fusion"
	row.position=old;body.global_position=old;fixed.reset()
	for key in g.projectiles.keys():g._projectile_end.rpc(key,g.projectiles[key].position,g.projectiles[key].weapon)
func offense_cases():
	var ai=g.bots;var st=ai.tribes;var rules=g.match_mode.tribes;var a=g.fighters[-1];var s: Dictionary=g.players[-1]
	for speed in [55.0,sqrt(275.0*20)]:
		for inherited in [Vector3.ZERO,Vector3(8,0,3)]:
			var solution:=Ballistics.solve(Vector3.ZERO,Vector3(100,12,0),speed,20,inherited)
			check(not solution.is_empty() and (solution.velocity-solution.direction*speed).distance_to(inherited)<.001 and (solution.velocity*solution.time-Vector3.UP*10*solution.time*solution.time).distance_to(Vector3(100,12,0))<.001,"Ballistic solution includes height, gravity and inherited velocity")
	check(Ballistics.solve(Vector3.ZERO,Vector3(1000,1000,0),10,20).is_empty(),"Out-of-range artillery has no imaginary firing solution")
	for team in [0,1]:
		s.team=team;rules.apply_equipment(-1,"light",[3,2,0],"energy");g.match_mode.flags[1-team].carrier=-1;a.position=g.match_mode.bases[1-team]
		var route: PackedVector3Array=st.offense.exit_route(-1,a.position,g.match_mode.bases[team],0,[])
		check(not route.is_empty() and route[1].y<a.position.y-3 and st.routes.clear(route[0],route[1]),"Carrier has a clear downhill exit from flag deck %d"%team)
		g.match_mode.return_flag(1-team)
	s.team=0;g.players[1].team=0;s.dead=false;s.hp=25;s.tribes_kit=false
	var direction: Vector3=(g.match_mode.bases[0]-Fixture.ORIGIN).normalized();direction.y=0;direction=direction.normalized()
	a.position=Fixture.ORIGIN;a.velocity=Vector3.ZERO;g.fighters[1].position=a.position+direction*8;g.fighters[1].velocity=Vector3.ZERO;g.players[1].hp=100
	ai.brains.erase(1);ai.brains[-1]=ai.new_brain(-1);g.match_mode.flags[1].carrier=-1
	check(st.offense.pass_flag(-1,ai.brains[-1]),"Injured carrier throws to a healthier human teammate without a bot brain")
	var caught:=false
	for frame in 90:
		g.clock+=1.0/60;g.match_mode.tick(1.0/60)
		if g.match_mode.flags[1].carrier==1:caught=true;break
	check(caught,"Flag pass is caught through real flight and ordinary flag touch rules")
	# Both players keep moving: the receiver must meet the led throw rather
	# than brake/turn toward its current position behind them.
	g.match_mode.return_flag(1);st.offense.passes.clear()
	var receiver=g.fighters[1];var rs: Dictionary=g.players[1]
	rules.apply_equipment(1,"light",[3,2,0],"energy")
	a.position=Fixture.ORIGIN;receiver.position=a.position+direction*8;a.velocity=Vector3.ZERO;receiver.velocity=Vector3.ZERO
	await physics_frame
	for frame in 4:
		for id in [-1,1]:g._configure_tribes(id,g.players[id]);g.fighters[id].simulate(Vector2.ZERO,0,false,1.0/60,false)
	a.velocity=direction*11;receiver.velocity=direction*11;s.hp=25;s.tribes_kit=false
	ai.brains[-1]=ai.new_brain(-1);ai.brains[1]=ai.new_brain(1);g.match_mode.flags[1].carrier=-1
	check(st.offense.pass_flag(-1,ai.brains[-1]),"Moving carrier plans a lead pass to a moving teammate")
	caught=false
	for frame in 90:
		g.clock+=1.0/60
		var rows: Array=[];st.offense.catch_goal(1,rows)
		if not rows.is_empty():
			var b: Dictionary=ai.brains[1];b.goal_key=rows[0].key;b.goal_kind=rows[0].kind;b.goal=rows[0].position;b.path=PackedVector3Array([b.goal]);b.step=0
			st.steer(1,b)
		g._configure_tribes(1,rs);receiver.simulate(rs.move,rs.yaw,false,1.0/60,rs.jump)
		g._configure_tribes(-1,s);a.simulate(st.movement(-1,direction),s.yaw,false,1.0/60,false)
		g.match_mode.tick(1.0/60)
		if g.match_mode.flags[1].carrier==1:caught=true;break
	check(caught,"Moving receiver catches with ordinary steering, flight and flag touches")
	for armour in ["medium","heavy"]:
		g.match_mode.return_flag(1);st.offense.passes.clear()
		rules.apply_equipment(-1,armour,[3,2,0],"energy");rules.apply_equipment(1,"light",[3,2,0],"energy")
		s.hp=rules.definition(-1).hp;s.tribes_kit=true
		a.position=Fixture.ORIGIN;receiver.position=a.position+direction*8;a.velocity=Vector3.ZERO;receiver.velocity=Vector3.ZERO
		await physics_frame
		for frame in 4:
			for id in [-1,1]:g._configure_tribes(id,g.players[id]);g.fighters[id].simulate(Vector2.ZERO,0,false,1.0/60,false)
		a.velocity=direction*rules.definition(-1).walk;receiver.velocity=direction*11
		ai.brains[-1]=ai.new_brain(-1);ai.brains[1]=ai.new_brain(1);g.match_mode.flags[1].carrier=-1
		check(st.offense.pass_flag(-1,ai.brains[-1]),"Healthy %s with a kit passes to a faster homeward Light"%armour)
		caught=false
		for frame in 120:
			g.clock+=1.0/60;s.last_input=g.clock;rs.last_input=g.clock
			var rows: Array=[];st.offense.catch_goal(1,rows)
			if not rows.is_empty():
				var b: Dictionary=ai.brains[1];b.goal_key=rows[0].key;b.goal_kind=rows[0].kind;b.goal=rows[0].position;b.path=PackedVector3Array([b.goal]);b.step=0;st.steer(1,b)
			g._configure_tribes(1,rs);receiver.simulate(rs.move,rs.yaw,false,1.0/60,rs.jump)
			g._configure_tribes(-1,s);a.simulate(st.movement(-1,direction),s.yaw,false,1.0/60,false)
			g.match_mode.tick(1.0/60)
			if g.match_mode.flags[1].carrier==1:caught=true;break
		check(caught,"Light catches %s relay through ordinary moving-body flag touches"%armour)
		check(not st.offense.pass_flag(1,ai.brains[1]),"Receiver keeps the flag instead of immediately passing back")
	# Armour alone must not make an already-fast carrier surrender momentum.
	g.match_mode.return_flag(1);st.offense.passes.clear();g.match_mode.flags[1].carrier=-1
	a.position=Fixture.ORIGIN;a.velocity=direction*25;receiver.position=a.position+direction*8;receiver.velocity=direction*11
	ai.brains[-1]=ai.new_brain(-1)
	check(not st.offense.pass_flag(-1,ai.brains[-1]),"Fast healthy Heavy retains flag when the Light would slow delivery")
	g.match_mode.return_flag(1);ai.brains.erase(1)
	st.assignments[-1]="escort";g.match_mode.flags[1].carrier=1;g.fighters[-2].position=g.fighters[1].position+Vector3(6,0,0)
	check(st.offense.escort_priority(-1,-2)>20,"Escort prioritizes an observed threat close to its carrier")
	g.match_mode.return_flag(1)
func construction_cases():
	var st=g.bots.tribes;var rules=g.match_mode.tribes;var pads=rules.stations();var deploy=rules.deployables
	g.players[-1].team=0;g.players[-1].dead=false;g.fighters[-1].position=pads.rows[0].position
	rules.energy[0]=20000
	for kind in st.construction.ORDER:
		rules.apply_equipment(-1,"medium",[3,2,4,1],kind);st.construction.plans.clear();st.construction.retry.clear()
		var row: Dictionary=st.construction.plan(-1)
		check(not row.is_empty() and row.kind==kind,"Construction finds a real map site for "+kind)
		if row.is_empty():continue
		g.fighters[-1].position=row.stand;g.fighters[-1].velocity=Vector3.ZERO
		g.players[-1].yaw=row.yaw;await physics_frame
		var brain: Dictionary=g.bots.new_brain(-1);brain.goal_kind="st_build";brain.goal=row.stand
		var before: int=deploy.count(0,kind);st.construction.build(-1,brain)
		check(deploy.count(0,kind)==before+1 and g.players[-1].tribes_pack=="none","Builder places and consumes actual "+kind)
		g.clock+=13
	var rows: Array=[];st.construction.remote_supply(-1,rows,false)
	check(rows.size()>=2,"Bots consider forward inventory and ammo stations for resupply")
	rows=[];st.construction.remote_supply(-1,rows,true);check(rows.is_empty(),"Injured bots do not expect armour repair from remote stations")
	var key: int=deploy.rows.keys().filter(func(k):return deploy.rows[k].kind=="motion")[0] if deploy.rows.values().any(func(row):return row.kind=="motion") else -1
	if key>=0:
		deploy.damage(key,0,10000);st.construction.plans.clear();st.construction.retry.clear();g.fighters[-1].position=pads.rows[0].position
		var plan: Dictionary=st.construction.plan(-1);check(not plan.is_empty() and plan.kind=="motion","Destroyed sensor produces a replacement construction plan")

func role_cases():
	var ai=g.bots;var st=ai.tribes;var rules=g.match_mode.tribes;var pads=rules.stations()
	for id in [-3,-4,-5]:g._add_player(id,"Role fixture")
	for id in [-1,-3,-4,-5]:
		g.players[id].team=0;g.players[id].dead=false;g.fighters[id].position=g.match_mode.bases[0]+Vector3(0,0,15*id)
		ai.brains[id]=ai.new_brain(id);rules.apply_equipment(id,"light",[3,2,0],"energy")
	g.players[-2].team=1;g.players[1].spectator=true;st.tactics.memory.clear();st.tactics.waves.clear();st.assignment_state.clear();st.assignments.clear();st.construction.plans.clear()
	rules.apply_equipment(-1,"heavy",[3,2,1,4,7],"energy");g.fighters[-1].position=g.match_mode.bases[0].lerp(g.match_mode.bases[1],.55)
	st.assign_roles(0,-1)
	check(st.assignments[-1]=="siege" and st.assignments.values().has("capper"),"Four surviving teammates preserve equipped Heavy offence and a capper")
	var fixed_key: int=pads.defences.rows[0].team
	for key in pads.defences.rows.size():
		if pads.defences.rows[key].team==0:fixed_key=key;break
	pads.defences.rows[fixed_key].hp=0
	check(st.equipment.damaged(0) and not st.equipment.essential_damage(0),"Lost elevated turret does not block construction while base service works")
	st.equipment.defer_fixed(0,fixed_key)
	check(not st.equipment.fixed_due(0,fixed_key),"Stalled fixed repair yields temporarily")
	g.clock+=121;check(st.equipment.fixed_due(0,fixed_key) and st.equipment.deferred.is_empty(),"Repair retry expires and clears stale state")
	rules.apply_equipment(-3,"medium",[3,2,4,1],"motion");g.fighters[-3].position=g.match_mode.bases[0].lerp(g.match_mode.bases[1],.4)
	st.construction.plans[-3]={"team":0,"until":g.clock+60,"kind":"motion"}
	g.fighters[-4].position=pads.generators[0].position;rules.apply_equipment(-4,"light",[3,2,0],"none")
	var pool: Array=[-3,-4];var roles: Dictionary={};st.allocate(pool,pads.generators[0].position,"repairer",roles)
	check(roles.get(-3,"")=="repairer","Outbound paid construction is retained over a nearer empty respawn")
	pads.health[0]=0;pool=[-3,-4];roles={};st.allocate(pool,pads.generators[0].position,"repairer",roles)
	check(roles.get(-4,"")=="repairer","Power failure interrupts construction retention for an available repairer")
	pads.health[0]=pads.GENERATOR_HP;pads.defences.reset();st.construction.plans.clear()
	for id in [-3,-4,-5]:g._peer_left(id)

func movement_skill_cases():
	var rules=g.match_mode.tribes;var ai=g.bots;var actor=g.fighters[-1];var state: Dictionary=g.players[-1]
	g.players[1].spectator=true;g.players[-2].dead=false
	g.fighters[1].position=Fixture.ORIGIN+Vector3(100,0,100);g.fighters[-2].position=Fixture.ORIGIN+Vector3(120,0,100)
	var origin: Vector3=Fixture.ORIGIN+Vector3(-100,.06,0)
	var ramp=Fixture.box(g,origin+Vector3(0,4,-16),Vector3(14,1,24));ramp.rotation.x=deg_to_rad(20)
	rules.apply_equipment(-1,"light",[3,2,0],"energy");state.team=0;state.invulnerable=0;state.cooldown=0;state.yaw=0;state.pitch=0
	actor.position=origin;actor.velocity=Vector3.ZERO;actor.jump_held=false
	await physics_frame
	for frame in 4:g._configure_tribes(-1,state);actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	actor.velocity=Vector3(0,0,-11)
	var brain: Dictionary=ai.new_brain(-1);brain.role="capper";brain.goal=origin+Vector3(0,30,-150)
	var ammo: int=rules.amount(-1,3)
	check(ai.tribes.offense.disc_jump(-1,brain),"Healthy equipped capper deliberately selects an uphill disc jump")
	check(rules.combat.fire(-1) and rules.amount(-1,3)==ammo-1,"Disc jump fires the carried gun and consumes real ammunition")
	var peak:=0.0
	for frame in 90:
		g.clock+=1.0/60;state.last_input=g.clock;state.ski=true;state.jet_held=false
		g._configure_tribes(-1,state);actor.simulate(Vector2(0,-1),state.yaw,false,1.0/60,frame==0)
		g._update_projectiles(1.0/60);peak=maxf(peak,actor.velocity.length())
	check(state.hp<100 and state.hp>0 and peak>12,"Disc jump receives ordinary self damage and blast impulse")
	ramp.free()
	# A healthy carrier may trade real health/ammo for escape speed on flat
	# ground, including after using its repair kit. No free impulse is granted.
	rules.apply_equipment(-1,"light",[3,2,0],"energy");state.tribes_kit=false;state.cooldown=0;state.yaw=0;state.pitch=0
	actor.position=origin;actor.velocity=Vector3.ZERO;actor.jump_held=false
	await physics_frame
	for frame in 4:g._configure_tribes(-1,state);actor.simulate(Vector2.ZERO,0,false,1.0/60,false)
	actor.velocity=Vector3(0,0,-11);actor.tribes_state.energy=20
	brain=ai.new_brain(-1);brain.role="capper";brain.goal=origin+Vector3(0,0,-150)
	g.match_mode.flags[1].carrier=-1;ammo=rules.amount(-1,3)
	check(ai.tribes.offense.disc_jump(-1,brain),"Healthy flag carrier can select an ordinary flat-ground escape disc jump")
	check(rules.combat.fire(-1) and rules.amount(-1,3)==ammo-1,"Carrier escape boost consumes actual disc ammunition")
	peak=0
	for frame in 90:
		g.clock+=1.0/60;state.last_input=g.clock;state.ski=true;state.jet_held=false
		g._configure_tribes(-1,state);actor.simulate(Vector2(0,-1),state.yaw,false,1.0/60,frame==0)
		g._update_projectiles(1.0/60);peak=maxf(peak,actor.velocity.length())
	check(state.hp<100 and state.hp>0 and peak>12,"Carrier pays normal self damage and gains only the real projectile impulse")
	state.hp=80;state.cooldown=0;brain.disc_jump_at=0
	check(not ai.tribes.offense.disc_jump(-1,brain),"Wounded carrier does not spend its remaining health on an escape boost")
	g.match_mode.return_flag(1)
	# Large fixed sensor markers instantiate a powered, damageable 400 m unit.
	var entity=preload("res://deathmatch/maps/entity.gd").new();entity.attributes={"classname":"info_tribes_sensor","team":"0","type":"large"};g.add_child(entity);entity.position=Fixture.ORIGIN+Vector3(0,.7,90)
	var assets=preload("res://deathmatch/tribes/base_assets.gd").new();assets.setup(rules.stations(),[entity]);var sensor: Dictionary=assets.rows[-1]
	check(sensor.range==400 and is_equal_approx(sensor.hp,1.5*assets.HP),"Large sensor marker uses documented range and durability")
	entity.free()
