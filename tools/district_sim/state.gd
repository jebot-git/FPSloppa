extends RefCounted
const SCHEMA:=1
const DEADLINES=["respawn_at","invulnerable","last_input","melee_ready_at","offhand_melee_ready_at","use_at","chat_at"]
const BODY=["collision_height","stance","blast_velocity","jump_held","jump_queued","floor_grace","stepped_last_frame","water_boost","water_exit_grace","water_deep_time","was_in_water","in_water","underwater","water_jump_used","air_left"]
static func district(point: Vector3) -> int:
	return clampi(int(floor((point.x+500)/250)),0,3)+4*clampi(int(floor((point.z+500)/250)),0,3)
static func actor(game,id: int) -> Dictionary:
	var body: Dictionary={}
	for key in BODY:body[key]=game.fighters[id].get(key)
	var state: Dictionary=game.players[id].duplicate(true)
	for key in DEADLINES:
		if state.has(key):state[key]=float(state[key])-game.clock
	return {"schema":SCHEMA,"id":id,"state":state,"position":game.fighters[id].position,"velocity":game.fighters[id].velocity,"body":body,"avatar":game.avatars.choices.get(id,{}).duplicate(true)}
static func restore(game,row: Dictionary) -> void:
	var id: int=row.id
	assert(not game.players.has(id) and row.schema==SCHEMA)
	game._add_player(id,row.state.name)
	var state: Dictionary=row.state.duplicate(true)
	for key in DEADLINES:
		if state.has(key):state[key]=float(state[key])+game.clock
	game.players[id]=state
	var fighter=game.fighters[id];fighter.position=row.position;fighter.velocity=row.velocity
	for key in BODY:
		if key!="collision_height":fighter.set(key,row.body[key])
	fighter.update_height(row.body.collision_height,true);fighter.rotation.y=state.yaw;fighter.show_alive(not state.dead,false)
	if not row.avatar.is_empty():game.avatars.choices[id]=row.avatar
	game.bots.brains[id]=game.bots.new_brain(id)
	fighter.reset_physics_interpolation()
static func snapshot(game,zone: int,sequence: int) -> Dictionary:
	var actors: Array=[];var items: Array=[];var projectiles: Array=[]
	for id in game.players:actors.append(actor(game,id))
	for item in game.pickups:items.append({"position":item.position,"available":item.available,"respawn":maxf(0,item.respawn-game.clock),"kind":item.kind,"item":item.item})
	for id in game.projectiles:
		var row: Dictionary=game.projectiles[id].duplicate(true);row.erase("node");row.id=id;projectiles.append(row)
	return {"schema":SCHEMA,"zone":zone,"sequence":sequence,"clock":game.clock,"actors":actors,"pickups":items,"projectiles":projectiles,"round_left":game.round_left}
