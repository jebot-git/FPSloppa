extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
const Actions=preload("res://deathmatch/bot_service/actions.gd")
var g
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("Vehicle bot contracts",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	for i in 12:
		g._add_player(-i-1,"Pilot test");g.players[-i-1].team=i%2;g.players[-i-1].input_blocked=false
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame
	var rules=g.match_mode.tribes;var fleet=rules.vehicles;var pads=rules.stations();var ai=g.bots.tribes.vehicles
	var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==0)[0]
	var id:=-1;var s: Dictionary=g.players[id];var actor=g.fighters[id]
	rules.apply_equipment(id,"light",[3,2,0],"energy");actor.position=pads.rows[index].position
	ai.recruit()
	check(ai.plans.has(id),"Nearest eligible Light bot assigned to powered vehicle terminal")
	check(ai.plans.size()==2,"Six players per team reserve at most one pilot each")
	var brain: Dictionary=g.bots.new_brain(id)
	rules.energy[0]=599
	check(ai.tick(id,brain,1.0/60) and fleet.rows.is_empty() and rules.energy[0]==599,"Bot purchase respects insufficient real team funds")
	g.clock+=3;rules.energy[0]=5000
	ai.tick(id,brain,1.0/60)
	check(fleet.rows.size()==1 and rules.energy[0]==4400,"Bot buys Scout through authority and pays exactly 600 energy")
	if fleet.rows.is_empty():finish();return
	var key: int=fleet.rows.keys()[0]
	actor.position=fleet.frame(fleet.rows[key])*Vector3(2.7,0,0)
	check(not Actions.execute(g,"st_vehicle_board",[id,key]),"Bot cannot bypass vehicle construction delay")
	g.clock+=4;ai.tick(id,brain,1.0/60)
	check(fleet.piloting(id),"Bot boards the actual cockpit after construction")
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP,Vector3(700,2,700));await physics_frame
	fleet.rows[key].position=Fixture.ORIGIN+Vector3.UP*2;fleet.rows[key].velocity=Vector3.ZERO;fleet.bodies[key].position=fleet.rows[key].position
	ai.plans[id].progress=fleet.rows[key].position;ai.plans[id].last_position=fleet.rows[key].position;ai.plans[id].stuck_at=g.clock
	var start: Vector3=fleet.rows[key].position
	for frame in 360:
		g.clock+=1.0/60;s.last_input=g.clock;ai.tick(id,brain,1.0/60);fleet.tick(1.0/60)
	check(fleet.rows.has(key) and fleet.rows[key].position.y>start.y+10,"Bot ordinary jet input performs physical takeoff")
	check(ai.stats.distance>40 and fleet.rows[key].velocity.length()>5,"Bot cruises beyond the pad with actual hull movement")
	check(not s.jump and fleet.piloting(id),"Pilot steering does not accidentally trigger jump-to-eject")
	var roof=Fixture.box(g,Fixture.ORIGIN+Vector3.UP*10,Vector3(35,2,35));await physics_frame
	fleet.rows[key].position=Fixture.ORIGIN+Vector3.UP*2;fleet.rows[key].velocity=Vector3.ZERO;fleet.bodies[key].position=fleet.rows[key].position
	ai.plans[id].progress=fleet.rows[key].position;ai.plans[id].last_position=fleet.rows[key].position;ai.plans[id].stuck_at=g.clock
	var hp: float=fleet.rows[key].hp
	for frame in 600:
		g.clock+=1.0/60;s.last_input=g.clock;ai.tick(id,brain,1.0/60);fleet.tick(1.0/60)
	check(fleet.rows.has(key) and fleet.rows[key].hp==hp,"Covered-bay departure avoids damaging roof collisions")
	check(fleet.rows[key].position.distance_to(Fixture.ORIGIN)>40,"Pilot exits a covered bay horizontally before climbing")
	roof.free();await physics_frame
	fleet.rows[key].position=Fixture.ORIGIN+Vector3.UP*17;fleet.rows[key].velocity=Vector3.ZERO;fleet.rows[key].yaw=0;fleet.rows[key].pitch=0;fleet.bodies[key].position=fleet.rows[key].position
	ai.plans[id].progress=fleet.rows[key].position;ai.plans[id].last_position=fleet.rows[key].position;ai.plans[id].stuck_at=g.clock
	g.fighters[-2].position=Fixture.ORIGIN+Vector3(0,16,-100);g.fighters[-2].velocity=Vector3.ZERO;brain.enemy=-2;brain.visible=[-2]
	var rocket: int=fleet.next_rocket
	for frame in 120:
		g.clock+=1.0/60;s.last_input=g.clock;ai.tick(id,brain,1.0/60);fleet.tick(1.0/60)
	check(fleet.next_rocket>rocket,"Pilot fires actual vehicle weapon at a perceived exposed opponent")
	check(not Actions.valid("st_vehicle_buy",[1,"scout"]) and not Actions.valid("st_vehicle_board",[id,"1"]),"Worker vehicle actions reject human IDs and malformed seat keys")
	check(not Actions.execute(g,"st_vehicle_buy",[id,"invalid"]),"Unknown craft cannot be purchased by a bot")
	check(Actions.execute(g,"st_vehicle_leave",[id]) and not fleet.mounted(id),"Bot exits through normal safe ejection path")
	finish()
func finish():
	print("ST_VEHICLE_BOTS ",JSON.stringify({"checks":checks,"failures":failures}))
	g.disconnect_game();g.free();quit(0 if failures.is_empty() else 1)
