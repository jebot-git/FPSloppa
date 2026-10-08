extends RefCounted
## Shared authority-to-query-world adapter. Never import a scene Object over the wire.
const VERSION:="fpsloppa-bot-1"
const BOOL_INPUTS=["fire","alt_fire","offhand_fire","melee","jump","crouch","prone","slow","ski","jet_held","input_blocked","reload","reload_grip","leg_assist"]
static func clean(value):
	if value is Object or value is RID or value is Callable or value is Signal:return null
	if value is Dictionary:
		var result: Dictionary={}
		for k in value:
			if k is String or k is int:result[k]=clean(value[k])
		return result
	if value is Array:
		var result: Array=[]
		for v in value:result.append(clean(v))
		return result
	return value
static func identity(game) -> String:
	var parts: Array=[VERSION,game.PROTOCOL]
	for name in ["bots.gd","counterstrike/penetration.gd","counterstrike/bsp_penetration.gd","arena.gd","fighter.gd","bot_service/state.gd","bot_service/actions.gd","bot_service/worker.gd","modes/match.gd","modes/defusal.gd","counterstrike/grenades.gd","modes/tribes.gd","modes/fortress.gd","modes/assault.gd","modes/titanball.gd","maps/loader.gd","maps/runtime.gd","maps/manifest.json","tribes/command_state.gd"]:parts.append(FileAccess.get_sha256("res://deathmatch/"+name))
	var names:=DirAccess.get_files_at("res://deathmatch/bot_ai");names.sort()
	for name in names:
		if name.ends_with(".gd"):parts.append(FileAccess.get_sha256("res://deathmatch/bot_ai/"+name))
	for row in game.map_catalog:
		if row.id==game.current_map:parts.append(FileAccess.get_sha256(row.path))
	var nav: String=preload("res://deathmatch/assets/paths.gd").folder("maps")+"navigation/"+game.current_map+".res"
	parts.append(FileAccess.get_sha256(nav) if FileAccess.file_exists(nav) else "bake")
	return str(parts).sha256_text()
static func capture(game,ticket: int) -> Dictionary:
	var actors: Dictionary={}
	for id in game.fighters:
		var f=game.fighters[id]
		actors[id]={"position":f.position,"velocity":f.velocity,"height":f.collision_height,"grounded":f.is_supported(),"prediction":f.prediction_state(),"tribes":f.tribes_state,"jetpack":f.jetpack_state,"speed":f.speed_multiplier}
	var items: Array=[]
	for p in game.pickups:items.append([p.available,p.respawn])
	var doors: Array=[]
	for g in game.gates:doors.append([g.open,g.node.position])
	var triggers: Array=[]
	var runtime=game.get_node_or_null("Map/MapRuntime")
	if runtime:
		for node in runtime.triggers.rows:
			var r: Dictionary=runtime.triggers.rows[node]
			if r.hp<=0 and r.gate<0 and not r.kind.begins_with("trigger_") and str(r.data.get("targetname","")).is_empty():continue
			triggers.append([runtime.get_path_to(node),r.hp,r.until,r.count,node.visible,node.collision_layer if node is CollisionObject3D else -1])
	return {"type":"state","ticket":ticket,"triggers":triggers,"epoch":game.map_epoch,"map":game.current_map,"mode":game.match_mode.kind,"weapons":game.armory.kind,"clock":game.clock,"intermission":game.intermission,"paused":game.intermission>0 or game.lobby.active(),"players":clean(game.players),"actors":actors,"rules":game.match_mode.snapshot(),"pickups":items,"gates":doors,"projectiles":clean(game.projectiles),"drops":game.dropped_weapons.snapshot(),"charging":clean(game.variant_combat.charging),"discs":game.variant_combat.discs.duplicate(),"cs":game.variant_combat.cs.snapshot(),"flights":clean(game.match_mode.st.flights)}
static func apply(game,data: Dictionary):
	data=data.duplicate(true)
	game.clock=data.clock;game.map_epoch=data.epoch;game.intermission=data.intermission
	for id in game.players.keys():
		if not data.players.has(id):
			game.fighters[id].free();game.fighters.erase(id);game.players.erase(id)
	for id in data.players:
		game.players[id]=data.players[id].duplicate(true)
		if not game.fighters.has(id):game._create_fighter(id)
		var f=game.fighters[id];var a: Dictionary=data.actors[id];var s: Dictionary=game.players[id]
		f.position=a.position;f.velocity=a.velocity;f.rotation.y=s.yaw;f.update_height(a.height,true);f.replay_grounded=int(a.grounded);f.restore_prediction_state(a.prediction)
		f.tribes_state=a.tribes;f.jetpack_state=a.jetpack;f.tribes_enabled=data.mode=="st";f.jetpack_enabled=data.rules.jetpacks;f.speed_multiplier=a.speed
		f.collision_layer=0 if s.dead or s.spectator else 2
	var previous_orders: Dictionary=game.match_mode.tribes.commander.orders.duplicate(true)
	game.match_mode.receive(data.rules);game.match_mode.st.flights=data.flights
	if is_instance_valid(game.bots):
		for id in game.match_mode.tribes.commander.orders:
			if game.bots.brains.has(id) and previous_orders.get(id,{})!=game.match_mode.tribes.commander.orders[id]:game.bots.brains[id].plan_at=0
	var runtime=game.get_node_or_null("Map/MapRuntime")
	if runtime:
		for row in data.triggers:
			var node=runtime.get_node_or_null(row[0])
			if node and runtime.triggers.rows.has(node):
				runtime.triggers.rows[node].hp=row[1];runtime.triggers.rows[node].until=row[2];runtime.triggers.rows[node].count=row[3];node.visible=row[4]
				if row[5]>=0:node.collision_layer=row[5]
	game.projectiles=data.projectiles;game.variant_combat.charging=data.charging;game.variant_combat.discs=data.discs
	game.dropped_weapons.receive(data.drops);game.variant_combat.cs.receive(data.cs)
	for i in mini(game.pickups.size(),data.pickups.size()):game.pickups[i].available=data.pickups[i][0];game.pickups[i].respawn=data.pickups[i][1]
	for i in mini(game.gates.size(),data.gates.size()):game.gates[i].open=data.gates[i][0];game.gates[i].node.position=data.gates[i][1]
static func intent(state: Dictionary) -> Dictionary:
	var result: Dictionary={"serial":state.serial,"move":state.move,"swim":state.get("swim",Vector3.ZERO),"yaw":state.yaw,"pitch":state.pitch,"weapon":state.weapon}
	for field in BOOL_INPUTS:result[field]=state.get(field,false)
	return result
static func valid_intent(row: Dictionary) -> bool:
	if not row.get("swim") is Vector3 or not row.swim.is_finite() or row.swim.length()>1.42:return false
	if not row.get("serial") is int or not row.get("weapon") is int or not row.get("move") is Vector2 or not row.move.is_finite() or row.move.length()>1.01:return false
	for field in ["yaw","pitch"]:
		if not (row.get(field) is float or row.get(field) is int) or not is_finite(float(row[field])):return false
	for field in BOOL_INPUTS:
		if not row.get(field) is bool:return false
	return true
static func accept(game,id: int,row: Dictionary):
	var s: Dictionary=game.players[id]
	for field in BOOL_INPUTS:s[field]=row[field]
	s.move=row.move.limit_length(1);s.yaw=wrapf(row.yaw,-PI,PI);s.pitch=clampf(row.pitch,-PI*.5,PI*.5)
	if row.weapon in s.owned:s.weapon=row.weapon
	s.room=Vector3.ZERO;s.swim=row.swim.limit_length(1.42);s.last_input=game.clock
static func neutral(state: Dictionary):
	state.move=Vector2.ZERO;state.room=Vector3.ZERO;state.swim=Vector3.ZERO
	for field in BOOL_INPUTS:state[field]=false
	state.fire_pending=[];state.jump_pending=false;state.jetpack_pending=false
	state.held=false;state.offhand_held=false;state.charge=0.0;state.want_respawn=false
