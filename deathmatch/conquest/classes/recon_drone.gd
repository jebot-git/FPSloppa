extends Node
## Authority scans a swept ground circle at 10 Hz. Clients animate compact flight records.
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
const RADIUS:=100.0
const SPEED:=120.0
const COOLDOWN:=120.0
const CLEARANCE:=60.0
var game
var flights:Dictionary={}
var alerts:Dictionary={}
var marks:Dictionary={}
var seen:Dictionary={}
var scan_time:Dictionary={}
var models:Dictionary={}
var next_id:=0
var next_alert:=0
var next_scan:=0.0
var heard:Dictionary={}
var warning:AudioStreamPlayer
var warning_count:=0
func setup(arena) -> void:game=arena
static func route(origin:Vector3,look:Vector3,limit:float=Landscape.EXTENT/2) -> Dictionary:
	if not origin.is_finite() or not look.is_finite() or absf(origin.x)>limit or absf(origin.z)>limit:return {}
	var direction:=Vector3(look.x,0,look.z)
	if direction.length_squared()<.000001:return {}
	direction=direction.normalized();var lo:=-INF;var hi:=INF
	for axis in [0,2]:
		if absf(direction[axis])<.000001:continue
		var a:float=(-limit-origin[axis])/direction[axis];var b:float=(limit-origin[axis])/direction[axis]
		lo=maxf(lo,minf(a,b));hi=minf(hi,maxf(a,b))
	if hi-lo<1:return {}
	var start:=origin+direction*lo;var end:=origin+direction*hi
	start.y=0;end.y=0
	return {"start":start,"end":end,"direction":direction,"length":hi-lo}
static func position(row:Dictionary,clock:float) -> Vector3:
	return row.start+row.direction*clampf((clock-row.at)*SPEED,0,row.length)
func activate(id:int) -> bool:
	if not game.multiplayer.is_server() or not game.classes.alive(id) or game.classes.role(id)!="scout":return false
	var state:Dictionary=game.classes.ensure(id)
	if state.get("equipped_utility","recon")!="recon_drone" or state.xp.scout<game.classes.progression.UTILITY_XP or state.get("drone_ready",0.0)>game.clock:return false
	if game.players[id].get("input_blocked",false) or game.lobby.active() or game.intermission>0:return false
	var eye:Transform3D=game.night_vision.eye(id)
	# Looking almost vertically still uses the scout's head/body horizontal bearing.
	var look:Vector3=-eye.basis.z
	if Vector2(look.x,look.z).length_squared()<.000001:look=Basis(Vector3.UP,game.players[id].yaw)*Vector3.FORWARD
	var path:=route(game.fighters[id].position,look)
	if path.is_empty() or game.players[id].team not in [0,1]:return false
	var ceiling:=-INF
	for i in ceili(path.length/16.0)+1:
		var p:Vector3=path.start+path.direction*minf(path.length,i*16.0)
		ceiling=maxf(ceiling,Landscape.surface(p.x,p.z).x)
	path.start.y=ceiling+CLEARANCE
	next_id+=1
	flights[next_id]={"owner":id,"team":game.players[id].team,"start":path.start,"direction":path.direction,"length":path.length,"at":game.clock,"until":game.clock+path.length/SPEED}
	seen[next_id]={};scan_time[next_id]=game.clock;state["drone_ready"]=game.clock+COOLDOWN;state.cloak_until=0.0
	return true
func tick() -> void:
	if not game.multiplayer.is_server() or game.clock<next_scan:return
	next_scan=game.clock+.1
	for target in alerts.keys():
		if alerts[target].until<=game.clock or not game.players.has(target) or game.players[target].dead or game.players[target].serial!=alerts[target].life:alerts.erase(target)
	for target in marks.keys():
		if not game.players.has(target) or game.players[target].dead or maxf(marks[target][0],marks[target][1])<=game.clock:marks.erase(target)
	for key in flights.keys():
		var row:Dictionary=flights[key]
		var a:Vector3=position(row,scan_time.get(key,row.at));var b:Vector3=position(row,game.clock);scan_time[key]=game.clock
		var begin:=Vector2(a.x,a.z);var end:=Vector2(b.x,b.z);var segment:=end-begin;var length_squared:=segment.length_squared()
		for target in game.players:
			var player:Dictionary=game.players[target]
			if player.dead or player.spectator or player.team not in [0,1] or player.team==row.team or not game.fighters.has(target):continue
			var p:Vector3=game.fighters[target].position;var point:=Vector2(p.x,p.z)
			var t:=clampf((point-begin).dot(segment)/length_squared,0,1) if length_squared>.000001 else 0.0
			if point.distance_squared_to(begin+segment*t)>RADIUS*RADIUS:continue
			# Recon radar intentionally ignores darkness, canopy/roof occlusion and cloak.
			game.spotting.reveal(target,row.team,game.clock)
			if not marks.has(target):marks[target]=[0.0,0.0]
			marks[target][row.team]=game.clock+game.spotting.MEMORY
			var life:=Vector2i(target,player.serial)
			if not seen[key].has(life):
				seen[key][life]=true;next_alert+=1
				alerts[target]={"seq":next_alert,"life":player.serial,"until":game.clock+game.spotting.MEMORY}
		if row.until<=game.clock:flights.erase(key);seen.erase(key);scan_time.erase(key)
func detected(target:int,team:int) -> bool:
	return team in [0,1] and marks.get(target,[0.0,0.0])[team]>game.clock
func receive(new_flights:Dictionary,new_alerts:Dictionary,new_marks:Dictionary,offset:float) -> void:
	flights=new_flights.duplicate(true);alerts=new_alerts.duplicate(true);marks=new_marks.duplicate(true)
	for row in flights.values():row.at+=offset;row.until+=offset
	for row in alerts.values():row.until+=offset
	for row in marks.values():
		for team in 2:row[team]+=offset
func notify_local() -> void:
	var id:int=game.multiplayer.get_unique_id();var row:Dictionary=alerts.get(id,{})
	if row.is_empty() or row.until<=game.clock or not game.players.has(id) or game.players[id].dead or game.players[id].serial!=row.life:return
	var token:=Vector3i(game.map_epoch,row.seq,row.life)
	if heard.get(id,Vector3i(-1,-1,-1))==token:return
	heard[id]=token;warning_count+=1
	if game.headless:return
	if not is_instance_valid(warning):
		warning=AudioStreamPlayer.new();warning.stream=load("res://deathmatch/audio/recon/spotted.wav");warning.volume_db=-7;add_child(warning)
	warning.play() # Local visor/radio warning; it remains audible in desktop and XR.
func draw() -> void:
	if game.headless:return
	for key in models.keys():
		if not flights.has(key) or flights[key].until<=game.clock:
			if is_instance_valid(models[key]):models[key].queue_free()
			models.erase(key)
	for key in flights:
		var row:Dictionary=flights[key]
		if row.until<=game.clock:continue
		if not models.has(key):
			var model:Node3D=load("res://deathmatch/models/recon/fighter.glb").instantiate();game.get_node("Map").add_child(model);Lighting.convert_node(model);prepare_model(model);models[key]=model
		var model:Node3D=models[key];model.position=position(row,game.clock);model.basis=Basis.looking_at(row.direction,Vector3.UP)
static func prepare_model(node:Node) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.visibility_range_end=1600;node.visibility_range_end_margin=100
	for child in node.get_children():prepare_model(child)
func _process(_delta:float) -> void:
	if not game or not game.active:return
	notify_local();draw()
func reset() -> void:
	flights.clear();alerts.clear();marks.clear();seen.clear();scan_time.clear();heard.clear();next_scan=0.0
	for model in models.values():
		if is_instance_valid(model):model.queue_free()
	models.clear()
	if is_instance_valid(warning):warning.stop()
