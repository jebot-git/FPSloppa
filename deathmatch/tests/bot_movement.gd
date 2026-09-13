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
	brain=bots.new_brain(-1);brain.goal=Fixture.point(0,-4)+Vector3.UP*3;brain.goal_kind="objective";brain.rocket_route=true
	state.owned=[2,6];state.weapon=6;state.ammo=[50,0,5,0];state.hp=150;state.armor=100;state.tier=2;state.invulnerable=0;state.cooldown=0
	await physics_frame
	check(bots.can_rocket_jump(-1,brain,brain.goal),"Healthy armed bot recognizes a clear raised rocket route")
	state.hp=30;check(not bots.can_rocket_jump(-1,brain,brain.goal),"Low health prevents a suicidal rocket route");state.hp=150
	var peak: float=actor.position.y;var landed:=false
	for frame in 240:
		await physics_frame;step()
		state.cooldown=maxf(0,state.cooldown-DT)
		if state.fire and state.cooldown<=0:game._fire(-1)
		game._update_projectiles(DT)
		peak=maxf(peak,actor.position.y)
		if actor.is_supported() and actor.position.y>Fixture.ORIGIN.y+2.5:landed=true
	check(state.ammo[2]==4 and state.hp<150,"Rocket jump spends one real rocket and normal self-damage")
	check(peak>Fixture.ORIGIN.y+4 and landed,"Rocket impulse and air control reach the raised platform")
	print("BOT_MOVEMENT_METRICS ",JSON.stringify({"takeoffs":takeoffs,"max_speed":max_speed,"rocket_peak":peak-Fixture.ORIGIN.y,"landed":landed,"position":str(actor.position)}))
	platform.free();game.disconnect_game();game.free()
	print("BOT_MOVEMENT_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
