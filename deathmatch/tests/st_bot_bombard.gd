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
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g)
	g.start_host("ST artillery observation",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	g.players[1].spectator=true;g.players[1].team=-1;g._spawn(1)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Artillery");g.players[-1].team=0
	while not g.bots.navigation.ready():await physics_frame
	var rules=g.match_mode.tribes;var ai=g.bots;var actor=g.fighters[-1];var s: Dictionary=g.players[-1]
	rules.apply_equipment(-1,"heavy",[7,3,2],"energy");actor.position=Fixture.ORIGIN;actor.velocity=Vector3.ZERO
	s.yaw=0;s.pitch=0;s.cooldown=0;s.weapon=7;s.invulnerable=0
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP*.5,Vector3(300,1,300))
	var fixed=rules.stations().defences;var row: Dictionary=fixed.rows[1];var original: Vector3=row.position
	for child in rules.stations().get_children():
		if child is StaticBody3D and child.global_position.distance_to(original)<.01:child.global_position=Fixture.ORIGIN+Vector3(0,0,-110);break
	row.position=Fixture.ORIGIN+Vector3(0,0,-110);row.energy=0
	await physics_frame
	var b: Dictionary=ai.new_brain(-1);ai.brains[-1]=b;b.role="siege";b.goal_kind="st_bombard";b.goal_key="st:bombard";b.support=0
	check(rules.targeting.targets(0).is_empty() and ai.teamplay.intel(-1).is_empty(),"Artillery starts without a designation or enemy-player report")
	for i in 120:
		g.clock+=1.0/60;ai.tribes.offense.bombard(-1,b,1.0/60)
		if s.fire:break
	check(b.has("bombard_solution") and s.fire and s.weapon==7,"Push artillery acquires an exposed enemy turret and aims its mortar")
	var ammo: int=rules.amount(-1,7);var before: float=row.hp
	check(rules.combat.fire(-1) and rules.amount(-1,7)==ammo-1,"Support fire consumes carried mortar ammunition")
	for i in 360:g.clock+=1.0/60;g._update_projectiles(1.0/60)
	check(row.hp<before,"The ordinary mortar projectile damages the observed turret")
	row.hp=fixed.Data.hp(row.kind);row.energy=0
	var wall=Fixture.box(g,Fixture.ORIGIN+Vector3(0,25,-55),Vector3(40,50,1));await physics_frame
	g.clock+=1;b.erase("bombard_solution");s.fire=false
	check(not ai.tribes.offense.bombard(-1,b,.2) and not b.has("bombard_solution"),"A hidden turret is not acquired through a wall")
	wall.free();await physics_frame
	row.team=0;g.clock+=1
	check(not ai.tribes.offense.bombard(-1,b,.2),"Support artillery never selects a friendly fixture")
	print("ST_BOT_BOMBARD ",JSON.stringify({"checks":checks,"failures":failures}));g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
