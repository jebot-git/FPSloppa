extends RefCounted
const Attribution=preload("res://deathmatch/server/attribution.gd")
## Server-owned visor state. Static glare scans are bounded to two fixture LOS rays plus one sun ray per wearer.
const Exposure=preload("res://deathmatch/conquest/classes/nvg_exposure.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var game
var sequences:Dictionary={}
var cooldowns:Dictionary={}
var trigger_held:=false
var request_sequence:=0
var next_scan:=0.0
var cells:Dictionary={}
var local_flashes:Array=[]
var lightning_flash:Dictionary={}
var visual_sources:Array=[]
var next_visual_scan:=0.
var indexed_map
func setup(arena) -> void:game=arena
static func above_forehead(pose:Dictionary) -> bool:
	if pose.is_empty():return false
	for key in ["left","right"]:
		var relative:Vector3=pose.head.basis.inverse()*(pose[key].origin-pose.head.origin)
		if absf(relative.x)<.28 and relative.y>-.02 and relative.y<.45 and relative.z>-.38 and relative.z<.18:return true
	return false
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
	if game.native_session.active:game.native_session.action(1)
	elif game.multiplayer.is_server():toggle(id,game.players[id].serial,game.map_epoch,request_sequence,pose)
	else:game._cq_nvg.rpc_id(1,game.players[id].serial,game.map_epoch,request_sequence,pose)
func local_input(command:Dictionary) -> void:
	var pressed:bool=false
	var eligible:=false
	var pose:Dictionary=command.get("xr",{})
	if game.is_vr() and not pose.is_empty():
		for key in ["left","right"]:
			var relative:Vector3=pose.head.affine_inverse()*pose[key].origin
			if absf(relative.x)<.28 and relative.y>-.02 and relative.y<.45 and relative.z>-.38 and relative.z<.18:
				var controller:XRController3D=game.xr_rig.left if key=="left" else game.xr_rig.right
				pressed=pressed or controller.get_float("trigger")>.6
				if game.xr_rig.hand_empty(0 if key=="left" else 1) and controller.get_float("trigger")>.6:
					eligible=true;command.fire=false;command.offhand_fire=false
	var edge:=eligible and not trigger_held;trigger_held=pressed
	if edge and not command.get("input_blocked",false):request(pose)
func eye(id:int) -> Transform3D:
	var state:Dictionary=game.players[id];var base:=Transform3D(Basis(Vector3.UP,state.yaw),game.fighters[id].position)
	if not state.xr.is_empty():return base*state.xr.head
	return base*Transform3D(Basis(Vector3.RIGHT,state.pitch),Vector3.UP*game.fighters[id].eye_height())
func clear_line(a:Vector3,b:Vector3) -> bool:return Attribution.ray(game.get_world_3d().direct_space_state,PhysicsRayQueryParameters3D.create(a,b,1),"query.night_vision.clear_line.ray").is_empty()
func visual_eye()->Transform3D:
	var camera:Camera3D=game.world_view_camera()
	return camera.global_transform if camera else eye(game.multiplayer.get_unique_id())
func clear_local_effects()->void:local_flashes.clear();lightning_flash.clear();visual_sources.clear();next_visual_scan=0.
func flash(position:Vector3,radius:float,duration:float,size:float=.12,energy:float=1.) -> void:
	# Presentation only: no shared blindness timer or server-wide player scan.
	var id:int=game.multiplayer.get_unique_id()
	if game.headless or not game.active or not enabled_for(id) or not position.is_finite() or radius<=0 or duration<=0:return
	var view:=visual_eye();var offset:=position-view.origin;var distance:=offset.length()
	if distance>=radius or distance<.01 or (-view.basis.z).dot(offset/distance)<=0:return
	var strength:float=clampf(energy*(1-distance/radius),0.,1.)
	var priority:float=strength*minf(.35,size/maxf(.01,distance))
	if local_flashes.size()>=Exposure.MAX_SPOTS:
		local_flashes.sort_custom(func(a,b):return a.priority>b.priority)
		if priority<=local_flashes.back().priority:return
	if not clear_line(view.origin,position):return
	if local_flashes.size()>=Exposure.MAX_SPOTS:local_flashes.pop_back()
	local_flashes.append({"position":position,"radius":maxf(.01,size),"strength":strength,"priority":priority,"at":Time.get_ticks_msec()/1000.,"life":clampf(duration,.04,.8)})
func flash_samples(view:Transform3D,now:float=-1.)->Array:
	if now<0:now=Time.get_ticks_msec()/1000.
	var samples:Array=lightning_samples(view,now)
	for i in range(local_flashes.size()-1,-1,-1):
		var row:Dictionary=local_flashes[i];var age:float=(now-row.at)/row.life
		if age>=1:local_flashes.remove_at(i);continue
		if (-view.basis.z).dot(row.position-view.origin)<=0:continue
		samples.append({"position":row.position,"radius":row.radius,"strength":row.strength*pow(1-clampf(age,0.,1.),2)})
	return samples
func lightning_samples(view:Transform3D,now:float)->Array:
	# Visor view calls this only while worn; the normal clear path removes afterimages.
	var weather=game.get("weather") if game else null
	var source:Dictionary=weather.lightning_source(view.origin) if weather else {}
	if not source.is_empty() and (-view.basis.z).dot(source.position-view.origin)>0 and clear_line(view.origin,source.position):
		var retained:=0.
		if not lightning_flash.is_empty():retained=lightning_flash.strength*pow(maxf(0,1-(now-lightning_flash.at)/.65),2)
		if source.strength>=retained:
			lightning_flash={"position":source.position,"radius":source.radius,"strength":source.strength,"at":now}
	if lightning_flash.is_empty():return []
	var age:float=(now-lightning_flash.at)/.65
	if age>=1:lightning_flash.clear();return []
	if (-view.basis.z).dot(lightning_flash.position-view.origin)<=0:return []
	return [{"position":lightning_flash.position,"radius":lightning_flash.radius,"strength":lightning_flash.strength*pow(1-clampf(age,0.,1.),2)}]
func index_lamps(map)->void:
	if indexed_map==map:return
	indexed_map=map;cells.clear()
	for row in map.lighting.metadata.get("lamps",[]):
		var p:=Vector3(row.position[0],row.position[1],row.position[2]);var cell:=Vector2i(floori(p.x/24),floori(p.z/24))
		if not cells.has(cell):cells[cell]=[]
		cells[cell].append(p)
func static_glare(view:Transform3D)->float:
	var map=game.battle_map
	if not map or not map.lighting:return 0.
	index_lamps(map)
	var now:float=Time.get_ticks_msec()/1000.;var forward:Vector3=-view.basis.z
	if now>=next_visual_scan:
		next_visual_scan=now+.1;visual_sources.clear()
		var cell:=Vector2i(floori(view.origin.x/24),floori(view.origin.z/24));var candidates:Array=[]
		for z in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				for point in cells.get(Vector2i(x,z),[]):
					var offset:Vector3=point-view.origin
					if offset.length_squared()<196 and Exposure.alignment(forward,offset)>0:candidates.append(point)
		candidates.sort_custom(func(a,b):return view.origin.distance_squared_to(a)<view.origin.distance_squared_to(b))
		for i in mini(2,candidates.size()):
			if clear_line(view.origin,candidates[i]):visual_sources.append({"point":candidates[i],"sun":false})
		var sky=map.lighting.SkySource;var weights:Vector3=sky.sun_weights(map.lighting.sky_time(),map.lighting.CYCLE_SECONDS)
		var sun:Vector3=(sky.SUN_NOON if weights.x>.25 else sky.SUN_DUSK if weights.y>.25 else sky.SUN_DAWN if weights.z>.25 else Vector3.ZERO).normalized()
		if sun!=Vector3.ZERO and Exposure.alignment(forward,sun,true)>0 and clear_line(view.origin,view.origin+sun*1500):visual_sources.append({"point":sun,"sun":true})
	var amount:=0.
	for source in visual_sources:
		amount=maxf(amount,Exposure.alignment(forward,source.point if source.sun else source.point-view.origin,source.sun))
	return amount # Re-evaluate the live gaze every frame; turning away clears immediately.
func tick() -> void:
	if game.clock<next_scan:return
	next_scan=game.clock+.1
	var map=game.battle_map
	if not map or not map.lighting:return
	index_lamps(map)
	for id in game.players:
		if not enabled_for(id):continue
		var state:Dictionary=game.classes.ensure(id);state["nb"]=0.
		var view:=eye(id);var cell:=Vector2i(floori(view.origin.x/24),floori(view.origin.z/24));var candidates:Array=[]
		for z in range(cell.y-1,cell.y+2):
			for x in range(cell.x-1,cell.x+2):
				for p in cells.get(Vector2i(x,z),[]):
					var offset:Vector3=p-view.origin
					if offset.length_squared()<196 and Exposure.alignment(-view.basis.z,offset)>0:candidates.append(p)
		candidates.sort_custom(func(a,b):return view.origin.distance_squared_to(a)<view.origin.distance_squared_to(b))
		for i in mini(2,candidates.size()):
			if clear_line(view.origin,candidates[i]):
				game.classes.ensure(id)["nb"]=game.clock+.14;break
		# The sky's sun is a bright direct source despite using no runtime lights.
		var sky=map.lighting.SkySource;var weights:Vector3=sky.sun_weights(map.lighting.sky_time(),map.lighting.CYCLE_SECONDS)
		var sun:Vector3=(sky.SUN_NOON if weights.x>.25 else sky.SUN_DUSK if weights.y>.25 else sky.SUN_DAWN if weights.z>.25 else Vector3.ZERO).normalized()
		if sun!=Vector3.ZERO and Exposure.alignment(-view.basis.z,sun,true)>0 and clear_line(view.origin,view.origin+sun*1500):game.classes.ensure(id)["nb"]=game.clock+.14
func forget(id:int) -> void:sequences.erase(id);cooldowns.erase(id)
