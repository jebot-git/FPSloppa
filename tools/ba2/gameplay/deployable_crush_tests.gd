extends "res://tools/ba2/gameplay/cannon_crush_tests.gd"
var tf
func building(key: int,at: Vector3,kind: String="sentry",team: int=1,map_owned: bool=false) -> void:
	tf.buildings[key]={"owner":-1,"team":team,"position":at,"kind":kind,"hp":150,"ready":g.clock+3,"next":g.clock+3,"expires":g.clock+120,"map_owned":map_owned,"invulnerable":map_owned}
func charge(key: int,at: Vector3,team: int=1,velocity: Vector3=Vector3.ZERO) -> void:
	tf.charges[key]={"owner":key,"team":team,"position":at,"kind":"pipe","velocity":velocity,"armed":g.clock+1,"until":g.clock+30}
func run() -> void:
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="qsrc_dm1";g.start_host("Deployable crush",0,100,10,true,"tb");g.set_physics_process(false);g.set_process(false)
	if is_instance_valid(g.bots):g.bots.free();g.bots=null
	Fixture.build(g);tf=g.match_mode.fortress;w=tf.walkers
	var r:=arrange();building(10001,Vector3(.7,0,0));building(10002,Vector3(-.7,0,0),"dispenser")
	building(10003,Vector3(0,0,1),"sentry",0);building(10004,Vector3(0,0,-1),"dispenser",-1,true)
	charge(-1,Vector3(0,.15,2));charge(-2,Vector3(0,.15,-2),0);charge(-3,Vector3(0,1,2),1,Vector3(0,0,8))
	g.match_mode.titanball.preparation_left=60.;await physics_frame;await physics_frame;w.tick(.1)
	check(tf.buildings.has(10001) and tf.buildings.has(10002) and tf.charges.has(-1),"Preparation does not crush Blue deployables")
	g.match_mode.titanball.advance_time(60.);w.tick(.1)
	check(not tf.buildings.has(10001),"Moving stomp destroys Blue sentry before build readiness")
	check(not tf.buildings.has(10002),"Moving stomp destroys Blue dispenser")
	check(tf.buildings.has(10003),"Red deployable survives the stomp")
	check(tf.buildings.has(10004),"Universal map resupply survives the stomp")
	check(not tf.charges.has(-1),"Settled Blue pipe charge is destroyed without detonation")
	check(tf.charges.has(-2) and tf.charges.has(-3),"Red charges and airborne Blue projectiles retain normal behavior")
	check(g.players[1].hp==tf.max_health(1),"Destroyed charge causes no secondary damage to the pilot")
	r=arrange();building(10005,Vector3(0,0,-7));building(10006,Vector3(0,3,0));building(10007,Vector3(0,-3,0));await physics_frame;await physics_frame;w.tick(.1)
	check(tf.buildings.has(10005) and tf.buildings.has(10006) and tf.buildings.has(10007),"Distant, elevated and below-floor deployables survive")
	r=arrange();building(10008,Vector3(2,0,0));var cover:=wall(Vector3(1,1.2,0),Vector3(.1,2.4,2));await physics_frame;await physics_frame;w.tick(.1)
	check(tf.buildings.has(10008),"Wall blocks stomp damage to a deployable")
	cover.free();await physics_frame
	r=arrange();building(10009,Vector3(.7,0,0));cover=wall(Vector3(0,5,1),Vector3(20,10,.5));await physics_frame;await physics_frame;w.tick(.1)
	check(r.state=="blocked" and tf.buildings.has(10009),"Blocked robot cannot crush deployables")
	cover.free();await physics_frame
	r=arrange();await physics_frame;await physics_frame;w.tick(1.);w.leave(1,true);building(10010,w.transform(r)*Vector3(.7,0,0));await physics_frame;await physics_frame;w.tick(.1)
	check(r.speed>0. and not tf.buildings.has(10010),"Unmanned braking still crushes Blue deployables")
	for i in 30:w.tick(.1)
	building(10011,w.transform(r)*Vector3(.7,0,0));charge(-1,w.transform(r)*Vector3(0,.15,1));w.tick(.1)
	check(r.speed==0. and tf.buildings.has(10011) and tf.charges.has(-1),"Stopped robot leaves Blue deployables intact")
	FileAccess.open("res://test-results/titanball/deployable-crush.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BA2_DEPLOYABLE_CRUSH_RESULT ",JSON.stringify(failures));g.free();quit(0 if failures.is_empty() else 1)
