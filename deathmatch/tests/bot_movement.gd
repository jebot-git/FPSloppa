extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const DT:=1.0/60
var failures: Array=[]
var game
var bots
var actor
var state: Dictionary
var brain: Dictionary
func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value:failures.append(label)
func _initialize():call_deferred("run")
func step() -> void:
	game.clock+=DT
	bots.steer(-1,brain,DT);game._update_crouch(-1,{})
	actor.simulate(state.move,state.yaw,state.slow,DT,state.jump,state.swim)
func settle(point: Vector3) -> void:
	actor.position=point;actor.velocity=Vector3.ZERO;actor.reset_view()
	for frame in 10:
		await physics_frame;actor.simulate(Vector2.ZERO,0,false,DT)
func run() -> void:
	game=load("res://deathmatch/arena.tscn").instantiate();root.add_child(game)
	game.start_host("AI movement",0,100,60,true,"dm");game.set_physics_process(false);game.set_process(false)
	Fixture.setup(game);bots=game.bots;actor=game.fighters[-1];state=game.players[-1]
	for id in [1,-2,-3]:game.players[id].spectator=true;game.fighters[id].position=Fixture.point(15,15)
	await settle(Fixture.point())
	brain=bots.new_brain(-1);brain.goal_kind="roam";brain.goal=Fixture.point(0,-16)
	var takeoffs:=0;var max_speed:=0.0
	for frame in 130:
		await physics_frame
		var grounded: bool=actor.is_supported()
		step()
		if grounded and actor.velocity.y>7:takeoffs+=1
		max_speed=maxf(max_speed,Vector2(actor.velocity.x,actor.velocity.z).length())
	check(takeoffs>=2 and max_speed>8.5,"Bot repeats real jump presses and runs at full movement speed")
	# An overhead duct uses prone input and actually reduces the shared collider.
	await settle(Fixture.point())
	var duct=Fixture.box(game,Fixture.point(0,-1)+Vector3.UP*1.2,Vector3(3,1,1))
	brain=bots.new_brain(-1);brain.goal=Fixture.point(0,-8)
	await physics_frame;step()
	check(state.prone and actor.collision_height<.8,"Prone clearance request changes the real player collider")
	duct.free();state.prone=false;game._update_crouch(-1,{})
	# Health/ammo limits gate a real rocket takeoff toward a raised platform.
	await settle(Fixture.point())
	var platform=Fixture.box(game,Fixture.point(0,-4)+Vector3.UP*1.5,Vector3(6,3,4))
	var launches:Array=[]
	for rules in ["doom","quake","ut99"]:
		game.armory.select(rules);game.variant_combat.reset()
		await settle(Fixture.point())
		actor.blast_velocity=Vector2.ZERO;actor.jump_held=false;actor.jump_queued=false
		brain=bots.new_brain(-1);brain.goal=Fixture.point(0,-4)+Vector3.UP*3;brain.goal_kind="objective";brain.rocket_route=true
		state.owned=[0,2,6];state.weapon=2;state.ammo=[50,0,5,0];state.hp=150;state.armor=100;state.tier=2;state.invulnerable=0;state.cooldown=0;state.charge=0;state.input_blocked=false;state.shots=0
		await physics_frame
		var expected:="hammer" if rules=="ut99" else "rocket"
		check(bots.boost_route(-1,brain,brain.goal)==expected,rules+": healthy bot recognizes a raised weapon-jump route")
		state.hp=30;check(bots.boost_route(-1,brain,brain.goal).is_empty(),rules+": low health prevents a suicidal route");state.hp=150
		var roof=Fixture.box(game,Fixture.point()+Vector3.UP*3,Vector3(2,.5,2))
		await physics_frame
		check(bots.boost_route(-1,brain,brain.goal).is_empty(),rules+": low ceiling blocks takeoff")
		roof.free();await physics_frame
		# With no ordinary route to this isolated platform, the real planner
		# must retain the chosen weapon boost rather than avoiding the goal.
		var saved_pickups:Array=game.pickups;var saved_spawns:Array=game.spawn_points
		game.pickups=[];game.spawn_points=[brain.goal]
		bots.plan(-1,brain)
		check(brain.rocket_route and brain.boost_kind==expected,rules+": planner selects an otherwise unreachable high-ground route")
		game.pickups=saved_pickups;game.spawn_points=saved_spawns
		state.ammo[2]=1
		if rules!="ut99":check(bots.boost_route(-1,brain,brain.goal).is_empty(),rules+": preserves a rocket for combat")
		state.ammo[2]=5
		actor.in_water=true;check(bots.boost_route(-1,brain,brain.goal).is_empty(),rules+": water prevents boost setup");actor.in_water=false
		game.match_mode.kind="ig";check(bots.boost_route(-1,brain,brain.goal).is_empty(),rules+": fixed loadout cannot weapon jump");game.match_mode.kind="dm"
		var peak:float=actor.position.y;var landed:=false;var shot_at:=-1.0;var began:float=game.clock
		for frame in 270:
			await physics_frame
			state.input_blocked=false;state.last_input=game.clock+DT
			bots.combat(-1,brain,DT);step()
			state.cooldown=maxf(0,state.cooldown-DT)
			if rules=="doom":
				if state.fire and state.cooldown<=0:game._fire(-1)
			else:game.variant_combat.tick_input(-1,DT)
			game._update_projectiles(DT)
			if state.shots>0 and shot_at<0:shot_at=game.clock-began
			peak=maxf(peak,actor.position.y)
			if actor.is_supported() and actor.position.y>Fixture.ORIGIN.y+2.5:landed=true
		check(state.shots==1 and state.hp<150,rules+": one real shot and ordinary self-damage")
		check(state.ammo[2]==(5 if rules=="ut99" else 4),rules+": normal ammunition cost")
		check(peak>Fixture.ORIGIN.y+4 and landed,rules+": real impulse and air control reach the raised platform")
		if rules=="ut99":check(shot_at>=1.5,rules+": bot holds piston charge before jump/release")
		launches.append({"rules":rules,"peak":peak-Fixture.ORIGIN.y,"landed":landed,"shot_at":shot_at,"hp":state.hp,"shots":state.shots,"position":str(actor.position)})
	# A threat arriving during the long charge cancels through normal input.
	await settle(Fixture.point());actor.blast_velocity=Vector2.ZERO;actor.jump_held=false;actor.jump_queued=false
	game.variant_combat.reset();state.hp=150;state.cooldown=0;state.shots=0;state.input_blocked=false
	brain=bots.new_brain(-1);brain.goal=Fixture.point(0,-4)+Vector3.UP*3;brain.rocket_route=true
	for frame in 25:
		await physics_frame;state.input_blocked=false;state.last_input=game.clock+DT
		bots.combat(-1,brain,DT);step();game.variant_combat.tick_input(-1,DT)
	check(game.variant_combat.charging.has(-1),"Piston setup is a real held weapon charge")
	brain.enemy=-2
	await physics_frame;state.last_input=game.clock+DT;bots.combat(-1,brain,DT);step();game.variant_combat.tick_input(-1,DT)
	check(state.input_blocked and state.shots==0 and state.hp==150 and not game.variant_combat.charging.has(-1),"New enemy cancels a piston setup without firing into the floor")
	print("BOT_MOVEMENT_METRICS ",JSON.stringify({"takeoffs":takeoffs,"max_speed":max_speed,"launches":launches}))
	platform.free();game.disconnect_game();game.free()
	print("BOT_MOVEMENT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
