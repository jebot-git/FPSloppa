extends RefCounted
const Attribution=preload("res://deathmatch/server/attribution.gd")
## Server-owned visor state. Static glare scans are bounded to two fixture LOS rays plus one sun ray per wearer.
const Poses=preload("res://deathmatch/vr/poses.gd")
var game
var sequences:Dictionary={}
var cooldowns:Dictionary={}
var trigger_held:=false
var request_sequence:=0
var next_scan:=0.0
var cells:Dictionary={}
var indexed_map
func setup(arena) -> void:game=arena
static func above_forehead(pose:Dictionary) -> bool:
	if pose.is_empty():return false
	var hand:Transform3D=pose.right if pose.left_handed else pose.left
	var relative:Vector3=pose.head.basis.inverse()*(hand.origin-pose.head.origin)
	return absf(relative.x)<.23 and relative.y>.07 and relative.y<.45 and relative.z>-.25 and relative.z<.14
func enabled_for(id:int) -> bool:return game.classes.states.get(id,{}).get("nv",false) and game.classes.alive(id)
func blind_for(id:int) -> float:return maxf(0,game.classes.states.get(id,{}).get("nb",0.0)-game.clock)
func toggle(id:int,serial:int,epoch:int,seq:int,pose:Dictionary) -> bool:
	if not game.multiplayer.is_server() or not game.classes.alive(id) or serial!=game.players[id].serial or epoch!=game.map_epoch or seq<=sequences.get(id,-1) or game.clock<cooldowns.get(id,0.0) or game.players[id].get("input_blocked",false) or game.lobby.active() or game.intermission>0:return false
	var current:Dictionary=game.players[id].xr
	if not pose.is_empty():
		var checked:=Poses.validate(pose)
		if checked.is_empty() or current.is_empty() or checked.left_handed!=current.left_handed or game.clock-game.players[id].last_input>.35 or not above_forehead(checked):return false
		for part in ["head","left","right"]:
			if checked[part].origin.distance_to(current[part].origin)>.15:return false
	elif not current.is_empty() or game.players[id].get("vr_device",false):return false
	sequences[id]=seq;cooldowns[id]=game.clock+.35
	var state:Dictionary=game.classes.ensure(id);state["nv"]=not state.get("nv",false)
	return true
func request(pose:Dictionary={}) -> void:
	var id:int=game.multiplayer.get_unique_id()
	if not game.active or game.menu_open or not game.classes.alive(id):return
	request_sequence+=1
	if game.multiplayer.is_server():toggle(id,game.players[id].serial,game.map_epoch,request_sequence,pose)
	else:game._cq_nvg.rpc_id(1,game.players[id].serial,game.map_epoch,request_sequence,pose)
func local_input(command:Dictionary) -> void:
	var pressed:bool=game.bindings.vr_pressed(game.xr_rig,"offhand_fire") if game.is_vr() else false
	var edge:=pressed and not trigger_held;trigger_held=pressed
	var pose:Dictionary=command.get("xr",{})
	if edge and not command.get("input_blocked",false) and above_forehead(pose):request(pose)
func eye(id:int) -> Transform3D:
	var state:Dictionary=game.players[id];var base:=Transform3D(Basis(Vector3.UP,state.yaw),game.fighters[id].position)
	if not state.xr.is_empty():return base*state.xr.head
	return base*Transform3D(Basis(Vector3.RIGHT,state.pitch),Vector3.UP*game.fighters[id].eye_height())
func clear_line(a:Vector3,b:Vector3) -> bool:return Attribution.ray(game.get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(a,b,1),"query.night_vision.clear_line.ray").is_empty()
func flash(position:Vector3,radius:float,duration:float) -> void:
	if not game.multiplayer.is_server():return
	for id in game.players:
		if not enabled_for(id):continue
		var view:=eye(id);var offset:=position-view.origin;var distance:=offset.length()
		if distance>=radius or (distance>2 and (-view.basis.z).dot(offset.normalized())<.5):continue
		if not clear_line(view.origin,position):continue
		var state:Dictionary=game.classes.ensure(id)
		state["nb"]=maxf(state.get("nb",0.0),game.clock+duration*clampf(1-distance/radius,.2,1))
func tick() -> void:
	if game.clock<next_scan:return
	next_scan=game.clock+.1
	var map=game.battle_map
	if not map or not map.lighting:return
	if indexed_map!=map:
		indexed_map=map;cells.clear()
		for row in map.lighting.metadata.get("lamps",[]):
			var p:=Vector3(row.position[0],row.position[1],row.position[2]);var cell:=Vector2i(floori(p.x/24),floori(p.z/24))
			if not cells.has(cell):cells[cell]=[]
			cells[cell].append(p)
	for id in game.players:
		if not enabled_for(id):continue
		var view:=eye(id);var cell:=Vector2i(floori(view.origin.x/24),floori(view.origin.z/24));var candidates:Array=[]
		for z in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				for p in cells.get(Vector2i(x,z),[]):
					var offset:Vector3=p-view.origin
					if offset.length_squared()<196 and (-view.basis.z).dot(offset.normalized())>.85:candidates.append(p)
		candidates.sort_custom(func(a,b):return view.origin.distance_squared_to(a)<view.origin.distance_squared_to(b))
		for i in mini(2,candidates.size()):
			if clear_line(view.origin,candidates[i]):
				game.classes.ensure(id)["nb"]=game.clock+.8;break
		# The sky's sun is a bright direct source despite using no runtime lights.
		var sky=map.lighting.SkySource;var weights:Vector3=sky.sun_weights(map.lighting.sky_time(),map.lighting.CYCLE_SECONDS)
		var sun:Vector3=(sky.SUN_NOON if weights.x>.25 else sky.SUN_DUSK if weights.y>.25 else sky.SUN_DAWN if weights.z>.25 else Vector3.ZERO).normalized()
		if sun!=Vector3.ZERO and (-view.basis.z).dot(sun)>.985 and clear_line(view.origin,view.origin+sun*1500):game.classes.ensure(id)["nb"]=game.clock+.8
func forget(id:int) -> void:sequences.erase(id);cooldowns.erase(id)
