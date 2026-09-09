extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var failures: Array = []

func check(value: bool,label: String) -> void:
	print("PASS " if value else "FAIL ",label)
	if not value: failures.append(label)

func _initialize() -> void:
	call_deferred("run")

func reset_combat() -> void:
	for id in g.projectiles.keys(): g._projectile_end.rpc(id,g.projectiles[id].position,7)
	g.intermission = 0
	for id in g.players:
		var s: Dictionary = g.players[id]
		s.hp = 1000
		s.armor = 0
		s.dead = false
		s.invulnerable = 0
		s.cooldown = 0
		s.charge = 0
		s.fire = false
		s.held = false
		s.last_input = g.clock
		s.owned = range(9)
		s.ammo = [200,50,50,300]
		s.yaw = 0
		s.pitch = 0
	g.fighters[1].position = Fixture.point()
	g.fighters[-1].position = Fixture.point(0,-2.7)
	g.fighters[-2].position = Fixture.point(5,0)

func run() -> void:
	g = load("res://deathmatch/arena.tscn").instantiate()
	root.add_child(g)
	Fixture.setup(g)
	await physics_frame
	g.start_host("Tester",0,100,60,true)
	g.bots.free();g.bots=null
	g.set_physics_process(false)
	await physics_frame
	await physics_frame
	reset_combat()
	g.players[-1].invulnerable = g.clock+1
	g._damage(-1,1,50,"PISTOL")
	check(g.players[-1].hp==1000,"Spawn protection prevents damage")
	g.players[-1].invulnerable = 0
	g.players[1].weapon = 2
	g._fire(1)
	check(g.players[-1].hp<1000 and g.players[1].ammo[0]==199,"Pistol hitscan and one-bullet cost")
	reset_combat()
	g.players[1].weapon = 1
	g.fighters[-1].position = g.fighters[1].position+Vector3(0,0,-1.8)
	g._fire(1)
	check(g.players[-1].hp<1000 and g.players[1].ammo[0]==200,"Chainsaw melee damages without ammo")
	reset_combat()
	g.players[1].weapon = 5
	g.players[1].fire = true
	for i in range(60): g._server_tick(.01)
	check(g.players[1].ammo[0]>=194 and g.players[1].ammo[0]<=195,"Chaingun cadence bounded during held fire")
	reset_combat()
	g.players[1].weapon = 7
	g._fire(1)
	for i in range(20): g._update_projectiles(.01)
	check(g.players[-1].hp<1000 and g.players[1].ammo[3]==299,"Plasma travels and damages target")
	check(g.projectiles.is_empty(),"Projectile removed after impact")
	reset_combat()
	g.players[1].weapon = 6
	g._fire(1)
	for i in range(25): g._update_projectiles(.01)
	check(g.players[-1].hp<980,"Rocket direct and radial damage")
	check(g.players[1].hp<1000,"Rocket splash can damage shooter")
	reset_combat()
	# A starting-room wall separates these two positions.
	g.fighters[-1].position = Fixture.point(8,0)
	var behind_wall: Vector3 = Fixture.point(12,0)
	g._blast(behind_wall,1,128,5.76)
	check(g.players[-1].hp==1000,"Walls block radial damage")
	reset_combat()
	g.players[1].weapon = 8
	g._fire(1)
	check(g.projectiles.is_empty() and g.players[1].charge>.8 and g.players[1].ammo[3]==260,"BFG consumes forty cells and charges before release")
	g._server_tick(.87)
	check(g.players[-1].hp<1000 or not g.projectiles.is_empty(),"BFG releases its projectile after charge")
	for i in range(30): g._update_projectiles(.01)
	check(g.players[-1].hp<800,"BFG impact and tracer spray deal heavy damage")
	reset_combat()
	var pickup: Dictionary = g.pickups[0]
	pickup.kind = "health"
	pickup.item = 25
	pickup.available = true
	pickup.position = g.fighters[1].position
	g.fighters[-1].position = g.fighters[1].position
	g.players[1].hp = 50
	g.players[-1].hp = 50
	g._collect(1)
	g._collect(-1)
	check(g.players[1].hp==75 and g.players[-1].hp==50,"Contested pickup is awarded exactly once")
	print("COMBAT_RESULT ",JSON.stringify({"failures":failures}))
	g.disconnect_game("Combat tests complete")
	g.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
