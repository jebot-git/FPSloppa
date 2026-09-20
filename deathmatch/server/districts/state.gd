extends RefCounted
## Trusted local worker state. Never accepted directly from public clients.
const SCHEMA:=3
const DEADLINES=["respawn_at","invulnerable","last_input","melee_ready_at","offhand_melee_ready_at","use_at","chat_at"]
const BODY=["collision_height","stance","blast_velocity","jump_held","jump_queued","floor_grace","stepped_last_frame","water_boost","water_exit_grace","water_deep_time","was_in_water","in_water","underwater","water_jump_used","air_left"]
const MELEE=["melee_state","offhand_melee_state","left_kick","right_kick"]
static func shift(state: Dictionary,offset: float) -> void:
	for key in DEADLINES:
		if state.has(key):state[key]=float(state[key])+offset
	# -1 denotes no synchronized view timestamp; do not turn it into a valid clock.
	if float(state.get("view_time",-1))>=0 or state.get("district_view_valid",false):state.view_time=float(state.view_time)+offset
	var fire: Array=state.get("fire_pending",[])
	if fire.size()==3:fire[2]=float(fire[2])+offset
	for field in MELEE:
		var row: Dictionary=state.get(field,{})
		for key in ["time","ready_at","swing_until"]:
			if row.has(key):row[key]=float(row[key])+offset
static func actor(game,id: int) -> Dictionary:
	var body: Dictionary={}
	for key in BODY:body[key]=game.fighters[id].get(key)
	var state: Dictionary=game.players[id].duplicate(true)
	state.district_view_valid=float(state.get("view_time",-1))>=0
	shift(state,-game.clock)
	return {"schema":SCHEMA,"id":id,"state":state,"position":game.fighters[id].position,"velocity":game.fighters[id].velocity,"body":body,"avatar":game.avatars.choices.get(id,{}).duplicate(true),"charge":game.variant_combat.charging.get(id,{}).duplicate(true)}
static func valid(row: Dictionary) -> bool:
	return row.get("schema",0)==SCHEMA and row.get("id") is int and row.get("state") is Dictionary and row.get("body") is Dictionary and row.get("position") is Vector3 and row.position.is_finite() and row.get("velocity") is Vector3 and row.velocity.is_finite()
static func apply(game,row: Dictionary) -> void:
	assert(valid(row))
	var id: int=row.id
	var state: Dictionary=row.state.duplicate(true);shift(state,game.clock);state.erase("district_view_valid")
	if not game.players.has(id):game.players[id]=state;game._create_fighter(id)
	else:game.players[id]=state
	var fighter=game.fighters[id];fighter.position=row.position;fighter.velocity=row.velocity
	for key in BODY:
		if key!="collision_height":fighter.set(key,row.body[key])
	fighter.update_height(row.body.collision_height,true);fighter.rotation.y=state.yaw;fighter.show_alive(not state.dead,false)
	if not row.get("avatar",{}).is_empty():game.avatars.choices[id]=row.avatar.duplicate(true)
	if not row.get("charge",{}).is_empty():game.variant_combat.charging[id]=row.charge.duplicate(true)
	else:game.variant_combat.charging.erase(id)
	fighter.reset_physics_interpolation()
static func remove(game,id: int) -> void:
	# A migration is not a disconnect, death, team change or announcement.
	if game.fighters.has(id):game.fighters[id].free();game.fighters.erase(id)
	game.players.erase(id);game.avatars.choices.erase(id);game.variant_combat.cancel_player(id)
	if is_instance_valid(game.bots):game.bots.brains.erase(id)
	for frame in game.history:frame.positions.erase(id)
static func restore(game,row: Dictionary) -> void:
	assert(not game.players.has(row.id));apply(game,row)
	if is_instance_valid(game.bots) and row.id<0:game.bots.brains[row.id]=game.bots.new_brain(row.id)
static func district(point: Vector3) -> int:return preload("res://deathmatch/conquest/rules.gd").district(point)
static func snapshot(game,zone: int,sequence: int) -> Dictionary:
	var actors: Array=[];var items: Array=[];var projectiles: Array=[]
	for id in game.players:actors.append(actor(game,id))
	for item in game.pickups:items.append({"position":item.position,"available":item.available,"respawn":maxf(0,item.respawn-game.clock),"kind":item.kind,"item":item.item})
	for id in game.projectiles:
		var row: Dictionary=game.projectiles[id].duplicate(true);row.erase("node");row.id=id;projectiles.append(row)
	return {"schema":SCHEMA,"zone":zone,"sequence":sequence,"clock":game.clock,"actors":actors,"pickups":items,"projectiles":projectiles,"round_left":game.round_left}
