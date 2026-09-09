extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var failures: Array=[]
func check(ok: bool,label: String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g)
	await physics_frame
	g.start_host("Rocket jumper",0,100,60,true);g.bots.free();g.bots=null;g.set_physics_process(false)
	var actor=g.fighters[1]
	for id in g.players:
		g.players[id].invulnerable=0;g.fighters[id].position=Fixture.point(0,10)
	actor.position=Fixture.point();actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO
	for i in range(4):
		await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
	check(actor.is_on_floor(),"Rocket-jump fixture starts grounded")
	var floor_y:float=actor.position.y
	g._blast(actor.position+Vector3(0,.1,0),1,128,5.76)
	check(actor.velocity.y>10 and g.players[1].hp>0 and g.players[1].hp<100,"Floor blast launches a healthy player with self damage")
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
	check(actor.velocity.y>10 and not actor.is_on_floor(),"Floor snap and movement do not cancel upward blast")
	var peak:=0.0
	for i in range(65):
		await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60);peak=maxf(peak,actor.position.y-floor_y)
	check(peak>3,"Rocket jump reaches a ledge above normal jump height")
	actor.position=Fixture.point()+Vector3.UP*4;actor.velocity=Vector3.ZERO;actor.blast_velocity=Vector2.ZERO
	actor.apply_blast(Vector3(10,1,0));var x:float=actor.position.x
	for i in range(15):
		await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
	check(actor.position.x-x>2 and actor.blast_velocity.x>9,"Airborne horizontal knockback persists without movement input")
	actor.apply_blast(Vector3(1000,1000,1000))
	check(actor.blast_velocity.length()<=20.001 and actor.velocity.y<=20,"Stacked explosions have bounded velocity")
	actor.apply_blast(Vector3(NAN,INF,0));check(actor.velocity.is_finite(),"Invalid impulses cannot poison movement")
	g._spawn(1)
	check(actor.velocity==Vector3.ZERO and actor.blast_velocity==Vector2.ZERO,"Respawn clears rocket momentum")
	actor.position=Fixture.point(8,0);g.players[1].invulnerable=0
	g._blast(Fixture.point(12,0)+Vector3.UP,1,128,5.76)
	check(actor.velocity==Vector3.ZERO,"World walls block explosion knockback")
	g.match_mode.configure({"sv_gametype":"tdm"});g.players[1].team=0;g.players[-1].team=0
	g.fighters[-1].position=Fixture.point();g.fighters[-1].velocity=Vector3.ZERO;g.fighters[-1].blast_velocity=Vector2.ZERO
	g._blast(Fixture.point()+Vector3.UP*.1,1,128,5.76)
	check(g.fighters[-1].velocity==Vector3.ZERO,"Friendly-fire protection also prevents teammate launch griefing")
	g.disconnect_game("Rocket jump checks complete");g.free()
	print("ROCKET_JUMP_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
