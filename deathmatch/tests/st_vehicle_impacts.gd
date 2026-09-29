extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var c
var checks:=0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func create(kind: String) -> int:
	c.reset();var d: Dictionary=c.Data.definition(kind);var key: int=c.next_id;c.next_id+=1
	c.rows[key]={"kind":kind,"position":Fixture.ORIGIN+Vector3.UP*3,"velocity":Vector3.ZERO,"yaw":0.0,"pitch":0.0,"bank":0.0,"hp":d.hp,"pilot":0,"life":-1,"team":0,"owner_team":0,"ready":0.0,"next_fire":0.0,"idle_until":g.clock+120,"passengers":[],"passenger_lives":[]}
	c.rows[key].passengers.resize(d.seats.size()-1);c.rows[key].passengers.fill(0)
	c.rows[key].passenger_lives.resize(d.seats.size()-1);c.rows[key].passenger_lives.fill(-1)
	c.make_body(key)
	g.fighters[1].position=c.seat_position(c.rows[key],0)+Vector3.RIGHT*2.5;g.players[1].dead=false;g.players[1].serial+=1;g.players[1].hp=100
	c.locks.clear();check(c.board(1,key),kind+" fixture pilot boards")
	return key
func reset_victim():
	var s: Dictionary=g.players[-1];s.dead=false;s.spectator=false;s.hp=1000;s.invulnerable=0;s.team=1;s.serial+=1
	g.fighters[-1].show_alive(true,false);g.fighters[-1].velocity=Vector3.ZERO;g.fighters[-1].blast_velocity=Vector2.ZERO
	g.fighters[-1].position=Fixture.ORIGIN+Vector3(0,2.15,-7)
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("Vehicle impact regression",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	g._add_player(-1,"Pedestrian");g.players[1].team=0;g.players[1].input_blocked=false;g.players[1].vr_device=true
	g.players[1].move=Vector2(0,-1);g.players[1].yaw=0;g.players[1].pitch=0;g.players[1].fly=0;g.players[1].fire=false
	c=g.match_mode.tribes.vehicles;Fixture.box(g,Fixture.ORIGIN-Vector3.UP,Vector3(100,2,100))
	g.fighters[-1].configure_tribes(true,false)
	await physics_frame;await physics_frame
	for kind in c.Data.KINDS:
		var key:=create(kind);reset_victim();c.rows[key].velocity=Vector3(0,0,-18)
		await physics_frame;await physics_frame
		for i in 30:
			g.clock+=1.0/60;g.players[1].last_input=g.clock;c.tick(1.0/60)
			if g.players[-1].hp<1000:break
		check(g.players[-1].hp<1000,kind+" swept moving hull damages pedestrian")
		check(g.fighters[-1].velocity.z < -5 and g.fighters[-1].velocity.y>0,kind+" impact pushes pedestrian away and upward")
		var hp: int=g.players[-1].hp;var speed: Vector3=g.fighters[-1].velocity
		check(not c.impact_player(key,-1,Vector3(0,0,-25),Vector3.FORWARD,g.fighters[-1].position) and g.players[-1].hp==hp and g.fighters[-1].velocity==speed,kind+" repeated contact cannot double-hit in same impact window")
	# Lower-speed physical impacts, stationary/grazing safeguards and life resets.
	var key:=create("hpc");reset_victim()
	check(not c.impact_player(key,-1,Vector3.ZERO,Vector3.FORWARD,Fixture.ORIGIN),"Parked hull cannot damage or launch player")
	check(not c.impact_player(key,-1,Vector3.RIGHT*20,Vector3.FORWARD,Fixture.ORIGIN),"Tangential moving contact does not count as impact")
	check(c.impact_player(key,-1,Vector3.FORWARD*5,Vector3.FORWARD,Fixture.ORIGIN) and g.players[-1].hp<1000 and g.fighters[-1].velocity.z<0,"Slow moving hull still damages and pushes on closing contact")
	reset_victim();g.players[-1].invulnerable=g.clock+5
	check(not c.impact_player(key,-1,Vector3.FORWARD*20,Vector3.FORWARD,Fixture.ORIGIN),"Spawn protection also prevents collision knockback")
	reset_victim();g.players[-1].team=0
	check(not c.impact_player(key,-1,Vector3.FORWARD*20,Vector3.FORWARD,Fixture.ORIGIN),"Friendly-fire-off protects teammates from ram damage and push")
	g.match_mode.friendly_fire=true
	check(c.impact_player(key,-1,Vector3.FORWARD*20,Vector3.FORWARD,Fixture.ORIGIN),"Friendly-fire-on permits friendly impact")
	check(not c.impact_player(key,1,Vector3.FORWARD*20,Vector3.FORWARD,Fixture.ORIGIN),"Pilot is excluded from own hull impacts")
	g.match_mode.friendly_fire=false
	reset_victim();g.fighters[-1].tribes_state.armour="heavy"
	check(c.impact_player(key,-1,Vector3.FORWARD*10,Vector3.FORWARD,Fixture.ORIGIN) and absf(g.fighters[-1].velocity.z+4)<.01,"Knockback uses heavy armour's existing mass")
	# A player's move_and_slide can be the side that detects the impact first.
	reset_victim();g.fighters[-1].tribes_state.armour="light"
	c.rows[key].velocity=Vector3.FORWARD*6
	g.fighters[-1].position=c.rows[key].position+Vector3(0,-.85,-c.definition(c.rows[key]).half.z-.35)
	g.fighters[-1].velocity=Vector3.BACK*10
	await physics_frame;await physics_frame
	g.fighters[-1].move_and_slide()
	check(g.fighters[-1].get_slide_collision_count()>0,"Pedestrian movement makes actual hull contact")
	g.clock+=1.0/60;g.players[1].last_input=g.clock;c.tick(1.0/60)
	check(g.players[-1].hp<1000 and g.fighters[-1].velocity.z<0,"Player-initiated hull contact applies damage and push")
	# Cooldown is per life and never replicated as mutable vehicle schema data.
	check(c.valid(c.snapshot()),"Impact bookkeeping preserves vehicle wire schema")
	c.reset();check(c.impact_locks.is_empty(),"Vehicle reset clears impact contact history")
	var report:={"checks":checks,"failures":failures}
	FileAccess.open("res://test-results/st-hands-impacts/vehicle-impacts.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("ST_VEHICLE_IMPACTS ",JSON.stringify(report));g.disconnect_game();g.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
