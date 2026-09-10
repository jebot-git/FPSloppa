extends Node
const Loader = preload("res://deathmatch/maps/loader.gd")
var game
var lights: Array[OmniLight3D]=[]
var light_tick:=0.0
var regions: Array = []
var destinations: Dictionary = {}
var teleport_until: Dictionary = {}
var hurt_until: Dictionary = {}
var bounds := AABB()

func configure(arena: Node, root: Node3D) -> void:
	game = arena
	var stack: Array = [root]
	var entities: Array = []
	var fixtures: Array=[]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and node.mesh:
			var b: AABB = node.global_transform*node.get_aabb()
			bounds = b if bounds.size.length()==0 else bounds.merge(b)
		if node.get_script()==preload("res://deathmatch/maps/entity.gd"): entities.append(node)
		elif node is Area3D:
			node.collision_mask = 2
			var kind := "water"
			if "lava" in node.name.to_lower(): kind="lava"
			elif "slime" in node.name.to_lower(): kind="slime"
			regions.append({"area":node,"kind":kind,"data":{}})
	game.fall_limit = bounds.position.y-12.0
	for node in entities:
		var e: Dictionary = node.attributes
		var kind: String = e.get("classname","")
		var flags := int(e.get("spawnflags",0))
		if flags&2048: # Quake SPAWNFLAG_NOT_DEATHMATCH
			node.visible=false
			if node is CollisionObject3D: node.collision_layer=0
			continue
		if kind in ["info_player_deathmatch","info_player_team1","info_player_team2"]:
			game.spawn_points.append(node.global_position-Vector3.UP*.70)
			game.spawn_yaws.append(deg_to_rad(float(e.get("angle",0))))
			if kind!="info_player_deathmatch":game.ctf_spawns[0 if kind=="info_player_team1" else 1].append(game.spawn_points.back())
		elif kind=="info_player_teamspawn" and int(e.get("team_no",0)) in [1,2]:
			var team:=0 if int(e.team_no)==2 else 1
			game.spawn_points.append(node.global_position-Vector3.UP*.70);game.spawn_yaws.append(deg_to_rad(float(e.get("angle",0))))
			game.ctf_spawns[team].append(game.spawn_points.back())
		elif kind=="item_tfgoal" and int(e.get("owned_by",0)) in [1,2] and str(e.get("mdl","")).contains("flag"):
			game.map_objectives["red" if int(e.owned_by)==2 else "blue"]=node.global_position-Vector3.UP*.70
		elif kind=="info_tfgoal" and int(e.get("team_no",0)) in [1,2]:
			var team:=0 if int(e.team_no)==2 else 1
			if int(e.get("items_allowed",0))>0:game.tf_capture[team]=node.global_position-Vector3.UP*.70
			elif int(e.get("ammo_shells",0))>0 or int(e.get("ammo_medikit",0))>0:game.tf_resupply[team].append(node.global_position-Vector3.UP*.70)
		elif kind in ["info_tf_capture_red","info_tf_capture_blue"]:
			game.tf_capture[0 if kind.ends_with("red") else 1]=node.global_position-Vector3.UP*.70
		elif kind in ["info_tf_resupply_red","info_tf_resupply_blue"]:
			game.tf_resupply[0 if kind.ends_with("red") else 1].append(node.global_position-Vector3.UP*.70)
		elif kind=="misc_librequake_fixture":fixtures.append(e)
		elif kind=="info_koth_control":game.map_objectives["hill"]=node.global_position-Vector3.UP*.70
		elif kind=="info_teleport_destination":
			destinations[e.get("targetname","")] = {"position":node.global_position-Vector3.UP*.70,"yaw":deg_to_rad(float(e.get("angle",0)))}
		elif kind in ["item_flag_team1","item_flag_team2"]:
			game.map_objectives["red" if kind=="item_flag_team1" else "blue"]=node.global_position-Vector3.UP*.70
		elif kind.begins_with("weapon_") or kind.begins_with("item_"): add_pickup(e,node.global_position)
		elif kind.begins_with("light") and not game.headless: add_light(e,node.global_position)
		elif kind in ["func_door","func_door_secret"]:
			var b := node_bounds(node)
			var angle := float(e.get("angle",0))
			var direction := Vector3.UP if angle==-1 else Vector3.DOWN if angle==-2 else Vector3(-sin(deg_to_rad(angle)),0,-cos(deg_to_rad(angle)))
			var distance := absf(direction.dot(b.size))-float(e.get("lip",8))*Loader.SCALE
			game.gates.append({"node":node,"base":node.position.y,"base_position":node.position,"travel":direction*maxf(distance,.5),"center":b.get_center(),"open":false,"until":0.0,"bsp":true})
		elif kind=="func_plat":
			var b := node_bounds(node)
			var travel := float(e.get("height",maxf((b.size.y-.25)/Loader.SCALE,48)))*Loader.SCALE
			node.position.y -= travel
			game.lifts.append({"node":node,"base":node.position.y,"travel":travel})
		elif kind=="func_illusionary": node.collision_layer=0
		elif kind.begins_with("trigger_") and node is Area3D:
			# Compiled BSP trigger brushes are logic volumes, never visible geometry.
			for mesh in node.find_children("*","GeometryInstance3D",true,false): mesh.hide()
			node.collision_layer=0
			node.collision_mask=2
			regions.append({"area":node,"kind":kind,"data":e})
	if not game.headless and not fixtures.is_empty():preload("res://deathmatch/maps/librequake_props.gd").add(root,fixtures)
	if game.spawn_points.is_empty():
		for node in entities:
			if node.attributes.get("classname","")=="info_player_start":
				game.spawn_points.append(node.global_position-Vector3.UP*.70)
				game.spawn_yaws.append(0.0)

func node_bounds(node: Node3D) -> AABB:
	var result := AABB()
	for child in node.find_children("*","MeshInstance3D",true,false):
		var b: AABB = child.global_transform*child.get_aabb()
		result = b if result.size.length()==0 else result.merge(b)
	return result

func add_pickup(e: Dictionary, origin: Vector3) -> void:
	var kind: String = e.get("classname","")
	var weapons := {"weapon_shotgun":3,"weapon_supershotgun":4,"weapon_nailgun":5,"weapon_supernailgun":7,"weapon_grenadelauncher":3,"weapon_rocketlauncher":6,"weapon_lightning":8}
	var ammo := {"item_shells":1,"item_spikes":0,"item_rockets":2,"item_cells":3}
	var item_kind := ""
	var item := 0
	if weapons.has(kind): item_kind="weapon"; item=weapons[kind]
	elif ammo.has(kind): item_kind="ammo"; item=ammo[kind]
	elif kind=="item_health":
		item_kind="health"
		item=100 if int(e.get("spawnflags",0))&2 else 10 if int(e.get("spawnflags",0))&1 else 25
	elif kind.begins_with("item_armor"):
		item_kind="armor"; item=1 if kind=="item_armor1" else 2
	elif kind.begins_with("item_artifact_"):
		# Map Quake-only powerups onto existing authoritative Doom pickups.
		item_kind="health"; item=100
	if item_kind.is_empty(): return
	# Quake pickups occupy a 32-unit box extending positive X/Y from origin.
	var p := {"kind":item_kind,"item":item,"position":origin+Vector3(-.5,.05,-.5),"available":true,"respawn":0.0,"node":null}
	if not game.headless: p.node = game._pickup_art(p)
	game.pickups.append(p)

func add_light(e: Dictionary, pos: Vector3) -> void:
	var lamp := OmniLight3D.new()
	lamp.position=pos
	var strength := float(e.get("light",200))
	lamp.omni_range=clampf(strength*Loader.SCALE,4,16)
	lamp.light_energy=clampf(strength/220.0,.3,1.5)
	var color: String=e.get("_color","")
	if not color.is_empty():
		var values:=color.split_floats(" ",false)
		if values.size()==3:
			var divisor:=255.0 if maxf(values[0],maxf(values[1],values[2]))>1.0 else 1.0
			lamp.light_color=Color(values[0]/divisor,values[1]/divisor,values[2]/divisor)
	elif e.get("classname","")!="light": lamp.light_color=Color(1,.65,.3)
	lamp.shadow_enabled=false
	lamp.visible=false
	lights.append(lamp)
	game.get_node("Map").add_child(lamp)

func _physics_process(_delta: float) -> void:
	if not game or not game.active: return
	for actor in game.fighters.values(): actor.in_water=false
	for region in regions:
		for actor in region.area.get_overlapping_bodies():
			if not "peer_id" in actor or not game.players.has(actor.peer_id): continue
			var id: int=actor.peer_id
			if game.players[id].dead or game.match_mode.special.blocked(id): continue
			if region.kind=="water": actor.in_water=true
			if not multiplayer.is_server(): continue
			if region.kind=="trigger_teleport" and game.clock>=teleport_until.get(id,0):
				var target: String=region.data.get("target","")
				if not destinations.has(target): continue
				var dest: Dictionary=destinations[target]
				actor.position=dest.position
				actor.velocity=Vector3.ZERO
				game.players[id].yaw=dest.yaw
				if id==multiplayer.get_unique_id(): game.local_yaw=dest.yaw
				game.players[id].serial+=1
				game._teleport_fx.rpc(dest.position)
				teleport_until[id]=game.clock+1.0
				game.history.clear()
			elif region.kind in ["trigger_hurt","lava","slime"] and game.clock>=hurt_until.get(id,0):
				hurt_until[id]=game.clock+.6
				game._damage(id,id,int(region.data.get("dmg",20)),"environment",true)
			elif region.kind=="trigger_push":
				var angle:=float(region.data.get("angle",-1))
				var direction:=Vector3.UP if angle==-1 else Vector3(-sin(deg_to_rad(angle)),.5,-cos(deg_to_rad(angle)))
				actor.velocity=direction*float(region.data.get("speed",600))*Loader.SCALE
	if not multiplayer.is_server(): return
	for i in range(game.gates.size()):
		var gate: Dictionary=game.gates[i]
		if not gate.get("bsp",false) or gate.open: continue
		for id in game.players:
			if not game.players[id].dead and game.fighters[id].position.distance_to(gate.center)<3:
				gate.until=game.clock+4
				game._gate_state.rpc(i,true)
				break

func _process(delta: float) -> void:
	light_tick-=delta
	if light_tick>0 or not game or not game.camera: return
	light_tick=.2
	var viewpoint: Vector3=game.camera.global_position
	lights.sort_custom(func(a,b): return a.global_position.distance_squared_to(viewpoint)<b.global_position.distance_squared_to(viewpoint))
	var budget:=4 if OS.has_feature("android") else 8
	for i in range(lights.size()):
		var lamp:=lights[i]
		var distance:=lamp.global_position.distance_to(viewpoint)
		lamp.visible=i<budget and distance<lamp.omni_range+12
