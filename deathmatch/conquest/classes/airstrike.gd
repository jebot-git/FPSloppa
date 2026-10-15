extends Node
## Authority owns targeting and damage. Clients animate bounded, collision-free payloads.
const Recon=preload("res://deathmatch/conquest/classes/recon_drone.gd")
const Landscape=preload("res://tools/voxel_battle/landscape.gd")
const Lighting=preload("res://tools/voxel_battle/baked_lighting.gd")
const TARGET_SECONDS:=5.0
const COOLDOWN:=300.0
const COUNT:=12
const DAMAGE:=300
const RADIUS:=35.0 # Broad area bombardment with linear falloff to the edge.
const SPACING:=18.0
const INTERVAL:=.3
const SPEED:=SPACING/INTERVAL
const FALL_SECONDS:=2.0
var game
var pending:Dictionary={}
var flights:Dictionary={}
var delivered:Dictionary={}
var models:Dictionary={}
var payloads:Dictionary={}
var next_id:=0
func setup(arena) -> void:game=arena
func equipped(id:int) -> bool:
	return game.classes.role(id)=="shocktroop" and game.classes.ensure(id).get("equipped_utility","jetpack")=="airstrike"
func stationary(id:int) -> bool:
	if not game.fighters.has(id) or not game.players.has(id):return false
	var s:Dictionary=game.players[id];var velocity:Vector3=game.fighters[id].velocity
	# RoomScale.move_capsule translates the collider without changing velocity. Do
	# not compare world positions: valid playspace shifts are allowed for aiming.
	return s.move.length_squared()<=.0009 and Vector2(velocity.x,velocity.z).length_squared()<=.0225 and absf(velocity.y)<=.5 and not s.get("jump",false) and s.get("swim",Vector3.ZERO).length_squared()<=.0009
func targeting(id:int) -> bool:
	if not game.classes.alive(id) or not game.players.has(id):return false
	var s:Dictionary=game.players[id]
	return s.weapon==8 and s.fire and not s.get("input_blocked",false) and game.clock-s.last_input<=.35 and stationary(id) and not game.lobby.active() and game.intermission<=0
func cancel(id:int) -> void:
	pending.erase(id);game.designations.erase(id)
func designate(id:int,hit:Dictionary,direction:Vector3) -> void:
	if not equipped(id):return
	var state:Dictionary=game.classes.ensure(id)
	if state.get("airstrike_ready",0.0)>game.clock:cancel(id);return
	if not pending.has(id):
		var path:=Recon.route(hit.position,direction)
		if path.is_empty():return
		pending[id]={"at":game.clock,"position":hit.position,"direction":path.direction,"life":game.players[id].serial}
	var row:Dictionary=pending[id]
	# Small hand/head aiming adjustments are fine; moving the laser to a new site
	# starts a fresh uninterrupted lock and never changes the original bearing.
	if row.life!=game.players[id].serial or row.position.distance_to(hit.position)>8:
		cancel(id);return
	if game.clock-row.at+.00001>=TARGET_SECONDS:
		launch(id,row.position,row.direction);pending.erase(id)
func launch(id:int,center:Vector3,direction:Vector3) -> bool:
	if not game.multiplayer.is_server() or not equipped(id) or not targeting(id) or game.classes.ensure(id).xp.shocktroop<game.classes.progression.UTILITY_XP or game.classes.ensure(id).get("airstrike_ready",0.0)>game.clock:return false
	var path:=Recon.route(center,direction)
	if path.is_empty():return false
	var step:float=minf(SPACING,path.length/(COUNT-1))
	var along:float=(center-path.start).dot(path.direction)
	var first:float=clampf(along-step*(COUNT-1)*.5,0,maxf(0,path.length-step*(COUNT-1)))
	var target:Vector3=path.start+path.direction*first
	var start:Vector3=target-path.direction*180;var length:float=180+step*(COUNT-1)+240
	var ceiling:=-INF
	for i in ceili(length/16)+1:
		var p:Vector3=start+path.direction*minf(length,i*16.0)
		ceiling=maxf(ceiling,Landscape.surface(p.x,p.z).x)
	start.y=ceiling+80
	next_id+=1
	flights[next_id]={"owner":id,"team":game.players[id].team,"start":start,"direction":path.direction,"length":length,"target":target,"step":step,"at":game.clock,"impact_at":game.clock+180/SPEED+FALL_SECONDS,"until":game.clock+length/SPEED+FALL_SECONDS}
	delivered[next_id]=0;game.classes.ensure(id)["airstrike_ready"]=game.clock+COOLDOWN
	return true
static func point(row:Dictionary,index:int) -> Vector3:return row.target+row.direction*row.step*index
static func impact_time(row:Dictionary,index:int) -> float:return row.impact_at+row.step/SPEED*index
static func position(row:Dictionary,clock:float) -> Vector3:return row.start+row.direction*clampf((clock-row.at)*SPEED,0,row.length)
func tick() -> void:
	if not game.multiplayer.is_server():return
	for id in game.designations.keys():
		if not targeting(id):cancel(id)
	for id in pending.keys():
		if not targeting(id) or not game.designations.has(id) or game.designations[id].until<=game.clock:cancel(id)
	for key in flights.keys():
		var row:Dictionary=flights[key];var count:int=delivered.get(key,0)
		while count<COUNT and game.clock+.00001>=impact_time(row,count):
			impact(row,count);count+=1
		delivered[key]=count
		if row.until<=game.clock:flights.erase(key);delivered.erase(key)
func impact(row:Dictionary,index:int) -> void:
	var p:=point(row,index);var ground:float=Landscape.surface(p.x,p.z).x
	var hit:Dictionary=game._trace(Vector3(p.x,row.start.y,p.z),Vector3(p.x,ground-10,p.z),row.owner)
	var where:Vector3=hit.position if hit.hit else Vector3(p.x,ground,p.z)
	if hit.hit and hit.id!=0:game._damage(hit.id,row.owner,DAMAGE,"AIRSTRIKE",false,where,Vector3.DOWN)
	if hit.hit:game._damage_map_hit(hit,row.owner,DAMAGE,"ordnance")
	game.variant_combat.blast(where+Vector3.UP*.08,row.owner,DAMAGE,RADIUS,"AIRSTRIKE",hit.id if hit.hit else 0,false)
	for vehicle in game.get_tree().get_nodes_in_group("cq_repairable_vehicles"):
		if vehicle.hp<=0 or vehicle.get("service")==game.battery_tanks or vehicle==hit.get("cq_vehicle"):continue
		var distance:float=where.distance_to(vehicle.global_position)
		if distance<RADIUS and game.variant_combat.vehicle_lock.clear_line(game,where,{"position":vehicle.global_position,"node":vehicle}):vehicle.damage(row.team,maxi(0,int(DAMAGE*(1-distance/RADIUS)*.5)),"ordnance")
	game._cq_airstrike_fx.rpc(where)
func receive(new_flights:Dictionary,new_pending:Dictionary,offset:float) -> void:
	flights=new_flights.duplicate(true);pending=new_pending.duplicate(true)
	for row in flights.values():row.at+=offset;row.impact_at+=offset;row.until+=offset
	for row in pending.values():row.at+=offset
func draw() -> void:
	if game.headless:return
	for key in models.keys():
		if not flights.has(key) or flights[key].until<=game.clock:
			models[key].queue_free();models.erase(key)
	for token in payloads.keys():
		var key:int=token.x;var index:int=token.y
		if not flights.has(key) or game.clock>=impact_time(flights[key],index):payloads[token].queue_free();payloads.erase(token)
	for key in flights:
		var row:Dictionary=flights[key]
		if row.until<=game.clock:continue
		if not models.has(key):
			var model:Node3D=load("res://deathmatch/models/airstrike/bomber.glb").instantiate();game.get_node("Map").add_child(model);prepare_model(model);Lighting.convert_node(model);Recon.prepare_model(model);models[key]=model
		models[key].position=position(row,game.clock);models[key].basis=Basis.looking_at(row.direction,Vector3.UP)
		for i in COUNT:
			var at:=impact_time(row,i);var t:float=(game.clock-(at-FALL_SECONDS))/FALL_SECONDS
			if t<0 or t>=1:continue
			var token:=Vector2i(key,i);var p:=point(row,i);p.y=Landscape.surface(p.x,p.z).x
			if not payloads.has(token):
				var node:=MeshInstance3D.new();var mesh:=SphereMesh.new();mesh.radius=.12;mesh.height=.4;mesh.radial_segments=6;mesh.rings=2;node.mesh=mesh
				var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("e4bb70");node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				game.get_node("Map").add_child(node);payloads[token]=node
			var release:Vector3=row.start+row.direction*(180+row.step*i)
			payloads[token].position=release.lerp(p,t*t)
static func prepare_model(node:Node) -> void:
	# Godot's GLTF importer retains COLOR_0 but leaves use-as-albedo disabled.
	# Enable it before converting to the jungle baked shader (and on cached meshes).
	if node is MeshInstance3D and node.mesh:
		for surface in node.mesh.get_surface_count():
			var material:Material=node.mesh.surface_get_material(surface)
			if material is StandardMaterial3D:material.vertex_color_use_as_albedo=true
			elif material is ShaderMaterial:material.set_shader_parameter("vertex_tint",true)
	for child in node.get_children():prepare_model(child)
func _process(_delta:float) -> void:
	if game and game.active:draw()
func reset() -> void:
	pending.clear();flights.clear();delivered.clear()
	for node in models.values()+payloads.values():
		if is_instance_valid(node):node.queue_free()
	models.clear();payloads.clear()
