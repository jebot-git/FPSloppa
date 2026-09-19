extends RefCounted
const State=preload("res://tools/district_sim/state.gd")
var game
var camera: Camera3D
var geometry: Node3D
var all_pickups: Array=[]
var zone:=-1
var sequence:=-1
var targets: Dictionary={}
var latest: Dictionary={}
var received_at:=0
var peak_actors:=0
func setup(tree: SceneTree) -> bool:
	game=load("res://deathmatch/arena.tscn").instantiate();tree.root.add_child(game);game.set_process(false);game.set_physics_process(false)
	game.armory.select("quake");game.match_mode.configure({"sv_gametype":"dm"})
	game.map_catalog.append({"id":"prototype_km1","title":"District prototype","path":"res://maps/Benchmark1km/prototype_km1.bsp","scene":"res://maps/Benchmark1km/zones.scn","sha256":FileAccess.get_sha256("res://maps/Benchmark1km/prototype_km1.bsp"),"modes":["dm"]})
	if not game._load_map("prototype_km1"):return false
	all_pickups=game.pickups.duplicate()
	for node in game.get_node("Map").get_child(0).find_children("*","MeshInstance3D",true,false):node.hide()
	var presentation: Node3D=game.get_node("Map").get_child(0).get_node_or_null("CityPresentation")
	if presentation:presentation.hide()
	preload("res://tools/km_benchmark/presentation.gd").apply(tree.root)
	game.get_node("Map/MapRuntime").process_mode=Node.PROCESS_MODE_DISABLED
	geometry=load("res://maps/Benchmark1km/districts.scn").instantiate();game.add_child(geometry)
	var pool=game.get_node("Map/MapRuntime/WeaponLighting");pool.configure(geometry,"res://maps/Benchmark1km/prototype_km1.bsp");pool.process_mode=Node.PROCESS_MODE_ALWAYS
	game._weapon_visuals().physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF
	for node in geometry.get_children():node.hide()
	for layer in game.find_children("*","CanvasLayer",true,false):layer.hide()
	if game.viewmodel:game.viewmodel.hide()
	camera=Camera3D.new();camera.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;camera.far=450;camera.fov=85;game.add_child(camera);camera.make_current()
	tree.root.use_occlusion_culling=false;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=120
	return true
func apply(snapshot: Dictionary,replace: bool=false) -> bool:
	if snapshot.schema!=State.SCHEMA:return false
	if not replace and (snapshot.zone!=zone or snapshot.sequence<=sequence):return false
	if replace:
		zone=snapshot.zone;sequence=-1;targets.clear()
		for node in geometry.get_children():node.visible=node.name=="District_%02d"%zone
		game.pickups=all_pickups.filter(func(item):return State.district(item.position)==zone)
		for item in all_pickups:item.node.visible=State.district(item.position)==zone
		for id in game.fighters.keys():game._peer_left(id)
		for id in game.projectiles.keys():game._projectile_end(id,game.projectiles[id].position,game.projectiles[id].weapon)
	sequence=snapshot.sequence;latest=snapshot;received_at=Time.get_ticks_msec();game.clock=snapshot.clock
	var ids: Array=[]
	for row in snapshot.actors:
		var id: int=row.id;ids.append(id)
		if not game.players.has(id):game._add_player(id,row.state.name);game.fighters[id].position=row.position
		game.players[id]=row.state.duplicate(true);game.avatars.choices[id]=row.avatar
		var actor=game.fighters[id];actor.physics_interpolation_mode=Node.PHYSICS_INTERPOLATION_MODE_OFF;actor.visual_velocity=row.velocity;actor.visual_weapon=row.state.weapon;actor.visual_pitch=row.state.pitch;actor.show_alive(not row.state.dead,false);actor.collision_layer=0;actor.collision_mask=0
		targets[id]={"position":row.position,"yaw":row.state.yaw}
	for id in game.fighters.keys():
		if not id in ids:game._peer_left(id);targets.erase(id)
	peak_actors=maxi(peak_actors,ids.size())
	for i in mini(game.pickups.size(),snapshot.pickups.size()):game.pickups[i].available=snapshot.pickups[i].available;game.pickups[i].node.visible=snapshot.pickups[i].available
	var projectiles: Array=[]
	for p in snapshot.projectiles:
		projectiles.append(p.id)
		if not game.projectiles.has(p.id):game._projectile_spawn(p.id,p.owner,p.weapon,p.position,p.direction,p.yaw,p.pitch,p.get("extra",{}))
		if game.projectiles.has(p.id):
			var node=game.projectiles[p.id].node;game.projectiles[p.id]=p.duplicate(true);game.projectiles[p.id].node=node
	for id in game.projectiles.keys():
		if not id in projectiles:game._projectile_end(id,game.projectiles[id].position,game.projectiles[id].weapon)
	return true
func frame(delta: float) -> void:
	if zone<0:return
	for id in targets:
		if not game.fighters.has(id):continue
		var actor=game.fighters[id];actor.position=actor.position.lerp(targets[id].position,minf(1,delta*25));actor.rotation.y=lerp_angle(actor.rotation.y,targets[id].yaw,minf(1,delta*25))
	game._process(delta)
	var focus: Vector3=Vector3(-375+(zone%4)*250,1,-375+(zone/4)*250)
	if game.fighters.has(-1):focus=game.fighters[-1].position+Vector3.UP
	camera.position=focus+Vector3(-12,8,15);camera.look_at(focus)
func close() -> void:
	if game:game.disconnect_game();game.queue_free()
