extends SceneTree
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var g
var c
var rules
var checks:=0
var failures: Array=[]
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():run.call_deferred()
func warp(key: int,at: Vector3):c.rows[key].position=at;c.rows[key].velocity=Vector3.ZERO;c.bodies[key].position=at;c.pin(key)
func approach(id: int,key: int,slot: int):
	g.fighters[id].position=c.seat_position(c.rows[key],slot)+Vector3(0,0,1.0);g.fighters[id].velocity=Vector3.ZERO
func run():
	g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);g.selected_map="ctf_raindance"
	g.start_host("Transport integration",0,100,60,true,"st");g.set_process(false);g.set_physics_process(false);g.match_mode.tribes.set_process(false)
	for id in g.players.keys():
		if id<0:g._peer_left(id)
	rules=g.match_mode.tribes;c=rules.vehicles
	Fixture.box(g,Fixture.ORIGIN-Vector3.UP,Vector3(1000,2,1000))
	for id in [-1,-2,-3,-4,-5,-6]:g._add_player(id,"Passenger%d"%-id)
	for id in g.players:
		g.players[id].team=0;g.players[id].input_blocked=false;g.players[id].spectator=false
		g.fighters[id].position=Fixture.ORIGIN+Vector3(id*4,0,100)
	var pads=rules.stations();var index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==0)[0]
	while not g.bots.navigation.ready():await physics_frame
	await physics_frame
	for kind in ["lpc","hpc"]:
		c.reset();g.clock+=4;rules.energy[0]=10000
		for id in g.players:
			g.players[id].dead=false;g.players[id].input_blocked=false;g.players[id].fire=false;g.players[id].jump=false;g.players[id].jet_held=false;g.players[id].move=Vector2.ZERO
			g.fighters[id].position=Fixture.ORIGIN+Vector3(id*4,0,100)
		g.fighters[1].position=pads.rows[index].position
		await physics_frame;await physics_frame
		var d: Dictionary=c.Data.definition(kind)
		check(c.purchase(1,g.map_epoch,g.players[1].serial,kind),kind+" purchased on real Raindance pad")
		if c.rows.is_empty():continue
		var key: int=c.rows.keys()[0];var row: Dictionary=c.rows[key]
		check(rules.energy[0]==10000-d.price and c.count(0,kind)==1,kind+" exact cost and type reservation")
		check(c.bodies[key].get_child(0).shape.size==d.half*2,kind+" physical hull matches vehicle size")
		g.clock+=4;warp(key,Fixture.ORIGIN+Vector3.UP*3)
		rules.apply_equipment(1,"heavy",[3,2,0],"energy");approach(1,key,0)
		check(not c.board(1,key,0),kind+" heavy armour cannot take pilot slot")
		rules.apply_equipment(1,"light",[3,2,0],"energy");approach(1,key,0)
		check(c.board(1,key,0) and c.piloting(1),kind+" Light pilot takes controls")
		check(not c.fire(key) and c.rockets.is_empty(),kind+" transport has no Scout rockets")
		for slot in range(1,d.seats.size()):
			var id: int=-slot;var armour: String=["medium","heavy","light"][slot%3]
			rules.apply_equipment(id,armour,[3,2,0],"energy");approach(id,key,slot)
			if slot==1:
				g.match_mode.flags[1].carrier=id
				check(not c.board(id,key,slot),kind+" flag carrier denied passenger slot")
				g.match_mode.return_flag(1)
			check(c.board(id,key,slot) and c.mounted(id) and not c.piloting(id),kind+" passenger %d (%s) boards"%[slot,armour])
			check(not rules.can_refit(id) and not g.match_mode.st.can_take(id,1),kind+" passenger cannot refit or pick up a flag %d"%slot)
		approach(-6,key,1);check(not c.board(-6,key),kind+" full transport rejects an extra passenger")
		g.fighters[-6].position=Fixture.ORIGIN+Vector3(100,0,100)
		check(c.valid(c.snapshot()) and rules.valid_snapshot(rules.snapshot()),kind+" all occupants pass production snapshot validation")
		var bad: Dictionary=c.snapshot();bad.rows[key].passengers[0]=1
		check(not c.valid(bad),kind+" pilot cannot also occupy passenger seat")
		bad=c.snapshot();bad.rows[key].passengers.append(-6);bad.rows[key].passenger_lives.append(1)
		check(not c.valid(bad),kind+" oversized passenger list rejected")
		bad=c.snapshot();bad.rows[key].kind="bogus"
		check(not c.valid(bad),kind+" unknown hull kind rejected")
		var s: Dictionary=g.players[1];s.move=Vector2.ZERO;s.yaw=0;s.pitch=0;s.jet_held=true;s.fire=true
		for f in 180:
			g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
		check(row.position.y>Fixture.ORIGIN.y+12 and c.rockets.is_empty(),kind+" pilot input gives VTOL without transport rockets")
		s.move=Vector2(0,-1);s.jet_held=false
		for f in 300:
			g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
		check(row.velocity.length()>24 and row.velocity.length()<26,kind+" reaches 25 m/s cruise")
		var attached:=true
		for slot in d.seats.size():attached=attached and g.fighters[c.occupants(row)[slot]].position.distance_to(c.seat_position(row,slot))<.001
		check(attached,kind+" all seats remain attached through flight")
		# Passenger inputs cannot steer; personal weapons use the normal combat path.
		var passenger: Dictionary=g.players[-1];passenger.move=Vector2.ONE;passenger.yaw=PI/2;passenger.pitch=0;passenger.jet_held=true;passenger.fire=true;passenger.weapon=0;passenger.cooldown=0;passenger.last_input=g.clock
		var shots: int=passenger.shots;var missiles: int=g.projectiles.size();var at: Vector3=g.fighters[-1].position
		check(c.handle_player(-1,false,1.0/60),kind+" passenger infantry movement suppressed")
		check(passenger.shots==shots+1 and g.projectiles.size()==missiles+1,kind+" passenger fires personal weapon")
		check(g.fighters[-1].position==at and row.pilot==1,kind+" passenger cannot move out of seat or take controls")
		var energy: float=g.fighters[-1].tribes_state.energy
		g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
		check(g.fighters[-1].tribes_state.energy>energy,kind+" passenger armour energy recharges without jet drain")
		var pose:=preload("res://deathmatch/vr/poses.gd").neutral();pose.left_handed=false
		passenger.physical=true;passenger.tribes_grenade=9;pose.left.origin=Vector3(-.25,1.55,.35)
		check(rules.combat.physical_request(-1,"arm",pose,Vector3.ZERO),kind+" passenger can grab shoulder grenade")
		pose.left.origin=Vector3(-.3,1.4,-.3)
		var grenade_count: int=rules.amount(-1,9)
		check(rules.combat.physical_request(-1,"throw",pose,Vector3(0,1,-3)) and rules.amount(-1,9)==grenade_count-1 and c.mounted(-1),kind+" guided passenger throw consumes grenade without ejection")
		g.players[1].physical=true
		check(not rules.combat.physical_request(1,"arm",pose,Vector3.ZERO),kind+" pilot cannot bypass vehicle controls with physical item RPC")
		passenger.tribes_pack="shield";g.fighters[-1].tribes_state.pack="shield"
		pose.left=preload("res://deathmatch/tribes/equipment.gd").mount(pose,"pack")
		check(rules.combat.physical_request(-1,"hold_pack",pose,Vector3.ZERO) and rules.combat.physical_request(-1,"activate",pose,Vector3.ZERO) and g.fighters[-1].tribes_state.pack_on and c.mounted(-1),kind+" chest pack activation retains passenger seat")
		rules.combat.cancel(-1)
		passenger.fire=false;s.move=Vector2.ZERO;s.pitch=.5;s.jet_held=true
		for f in 240:
			g.clock+=1.0/60;s.last_input=g.clock;c.tick(1.0/60)
		check(row.position.y-Fixture.ORIGIN.y<16 and absf(row.pitch)<=.1751,kind+" 15 m ceiling and pitch bound enforced")
		var velocity: Vector3=row.velocity
		check(c.handle_player(-1,true)==false and not c.mounted(-1),kind+" passenger jump ejects")
		check(g.fighters[-1].velocity==velocity+Vector3.UP*5 and c.piloting(1),kind+" passenger eject preserves momentum without ejecting pilot")
		check(not c.board(-1,key,1),kind+" passenger cannot immediately reboard")
		g.clock+=4;approach(-1,key,1);check(c.board(-1,key,1),kind+" passenger can reboard after cooldown")
		g.players[-1].serial+=1;c.tick(1.0/60)
		check(not c.mounted(-1) and c.mounted(-2),kind+" stale passenger life releases only that seat")
		g.clock+=4;approach(-1,key,1);c.board(-1,key,1)
		g.players[1].dead=true;c.tick(1.0/60)
		check(not c.mounted(1) and c.mounted(-1) and row.pilot==0,kind+" pilot death preserves passenger occupancy")
		g.players[1].dead=false;g.clock+=4;approach(1,key,0);check(c.board(1,key,0),kind+" replacement pilot boards occupied transport")
		c.departed(-1);check(not c.mounted(-1) and c.mounted(-2),kind+" disconnect releases only departing passenger")
		var hp: float=row.hp;g.players[-6].team=1;c.damage(key,-6,10,"Laser Rifle")
		check(is_equal_approx(row.hp,hp-5),kind+" half laser damage follows original vehicle scale")
		check(c.repair(key,1,1000) and row.hp==d.hp,kind+" repairs cap at type-specific hull health")
		c.damage(key,0,10000,"IMPACT")
		check(c.rows.is_empty() and c.bodies.is_empty() and not c.mounted(-2),kind+" destruction ejects every passenger and frees hull")
		g.players[-6].team=0
	# Check the opposite authored pad and independent reservations by type.
	c.reset();var blue_index: int=range(pads.rows.size()).filter(func(i):return pads.rows[i].kind=="vehicle" and pads.rows[i].team==1)[0]
	g.players[-6].team=1;g.players[-6].input_blocked=false;rules.energy[1]=10000
	for kind in ["lpc","hpc"]:
		g.clock+=4;g.fighters[-6].position=pads.rows[blue_index].position
		await physics_frame;await physics_frame
		check(c.purchase(-6,g.map_epoch,g.players[-6].serial,kind),kind+" fits the blue Raindance pad")
		c.reset()
	g.fighters[-6].position=Fixture.ORIGIN+Vector3(100,0,100);g.players[-6].team=0
	g.fighters[1].position=pads.rows[index].position;rules.energy[0]=10000
	for n in 3:
		g.clock+=1;await physics_frame;await physics_frame
		check(c.purchase(1,g.map_epoch,g.players[1].serial,"hpc"),"HPC reservation %d"%(n+1))
		if c.rows.size()>n:warp(c.rows.keys()[-1],Fixture.ORIGIN+Vector3(n*15,10,0))
	g.clock+=1;await physics_frame;await physics_frame
	var before_limit: int=rules.energy[0]
	check(not c.purchase(1,g.map_epoch,g.players[1].serial,"hpc") and rules.energy[0]==before_limit,"Fourth HPC rejected without spending")
	g.clock+=1
	check(c.purchase(1,g.map_epoch,g.players[1].serial,"lpc"),"HPC limit does not consume LPC allocation")
	c.reset()
	# Distinct type limits, old recordings and malformed purchase protection.
	g.players[1].input_blocked=false;g.fighters[1].position=pads.rows[index].position;g.clock+=4;rules.energy[0]=10000
	await physics_frame;await physics_frame
	var balance: int=rules.energy[0]
	check(not c.purchase(1,g.map_epoch,g.players[1].serial,"unknown") and rules.energy[0]==balance,"Invalid kind cannot spend energy")
	check(c.purchase(1,g.map_epoch,g.players[1].serial,"scout"),"Scout still purchasable alongside transports")
	var key: int=c.rows.keys()[0];var saved: Dictionary=c.snapshot()
	for field in ["kind","passengers","passenger_lives"]:saved.rows[key].erase(field)
	check(c.valid(saved),"Legacy 13-field Scout snapshot remains readable")
	c.reset();c.receive(saved);check(c.rows[key].kind=="scout" and c.rows[key].passengers.is_empty(),"Legacy snapshot normalizes into new vehicle state")
	c.reset();g.disconnect_game();g.free()
	print("ST_TRANSPORTS ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
