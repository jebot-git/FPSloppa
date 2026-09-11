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
var contents=preload("res://deathmatch/maps/contents.gd").new()
var has_contents:=false
var breath: Dictionary={}
var push_contacts: Dictionary={}
var legacy_train_push:=false

func configure(arena: Node, root: Node3D, bsp_path: String="") -> void:
	game = arena
	process_physics_priority=-50
	if not bsp_path.is_empty():has_contents=contents.open(bsp_path)
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
	legacy_train_push=entities.any(func(node):return node.attributes.get("classname","")=="info_train_motion")
	game.fall_limit = bounds.position.y-12.0
	for node in entities:
		var e: Dictionary = node.attributes
		var kind: String = e.get("classname","")
		# Repair existing scene caches created before triangle collisions received
		# the same inverse entity rotation as their brush meshes.
		if node is PhysicsBody3D and str(e.get("model","")).begins_with("*"):
			for shape in node.get_children():
				if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
					shape.transform=Transform3D(node.transform.basis.inverse(),Vector3.ZERO)
		var flags := int(e.get("spawnflags",0))
		if kind.begins_with("info_as_"):
			var row:=e.duplicate();row["kind"]=kind;row["position"]=node.global_position-Vector3.UP*.70
			game.map_assault.append(row)
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
			# Quake raises info_teleport_destination by 27 units before use.
			destinations[e.get("targetname","")] = {"position":node.global_position+Vector3.UP*(27.0*Loader.SCALE-.70),"yaw":deg_to_rad(float(e.get("angle",0)))}
		elif kind in ["item_flag_team1","item_flag_team2"]:
			game.map_objectives["red" if kind=="item_flag_team1" else "blue"]=node.global_position-Vector3.UP*.70
		elif kind.begins_with("weapon_") or kind.begins_with("item_"): add_pickup(e,node.global_position)
		elif kind.begins_with("light") and not game.headless: add_light(e,node.global_position)
		elif kind in ["func_door","func_door_secret"]:
			var b := node_bounds(node)
			var angle := float(e.get("angle",0))
			var direction := Vector3.UP if angle==-1 else Vector3.DOWN if angle==-2 else Vector3(-sin(deg_to_rad(angle)),0,-cos(deg_to_rad(angle)))
			var distance := absf(direction.dot(b.size))-float(e.get("lip",8))*Loader.SCALE
			game.gates.append({"node":node,"base":node.position.y,"base_position":node.position,"travel":direction*maxf(distance,.5),"center":b.get_center(),"open":false,"until":0.0,"bsp":true,"as_unlock":int(e.get("as_unlock",0))})
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
	remove_sentry_pickups()
	if not game.headless and not fixtures.is_empty():preload("res://deathmatch/maps/librequake_props.gd").add(root,fixtures)
	if not game.headless:preload("res://deathmatch/maps/filtering.gd").new().apply(root,int(game.presentation.get("texture_filter",2)))
	if not game.headless and entities.any(func(node):return node.attributes.get("classname","")=="info_train_motion"):
		var motion:=preload("res://deathmatch/maps/train_motion.gd").new();motion.name="TrainMotion";add_child(motion);motion.configure(game,root,entities)
	if game.spawn_points.is_empty():
		for node in entities:
			if node.attributes.get("classname","")=="info_player_start":
				game.spawn_points.append(node.global_position-Vector3.UP*.70)
				game.spawn_yaws.append(0.0)

func remove_sentry_pickups() -> void:
	# Older HiSlop BSPs include a rotating chaingun on each authored turret mount.
	# Filter at load on every peer so pickup indices stay identical in snapshots.
	for index in range(game.pickups.size()-1,-1,-1):
		var pickup: Dictionary=game.pickups[index]
		if pickup.kind!="weapon" or pickup.item!=5:continue
		for row in game.map_assault:
			if row.kind!="info_as_sentry":continue
			var offset: Vector3=pickup.position-row.position
			if Vector2(offset.x,offset.z).length()>.8 or absf(offset.y)>1.5:continue
			if is_instance_valid(pickup.node):pickup.node.free()
			game.pickups.remove_at(index);break

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
	for id in game.fighters:
		var actor=game.fighters[id]
		actor.in_water=false;actor.underwater=false;actor.water_surface=false
		if not game.players.has(id):continue
		var state: Dictionary=game.players[id]
		if state.dead or state.spectator:breath.erase(id);actor.air_left=12.0;continue
		if has_contents:
			var waist: float=minf(.75,actor.collision_height*.5)
			var kind:int=contents.at(actor.global_position+Vector3.UP*waist)
			actor.in_water=contents.liquid(kind)
			actor.water_surface=actor.in_water and not contents.liquid(contents.at(actor.global_position+Vector3.UP*(waist+.20)))
			var pose:Dictionary=actor.xr_pose if id==multiplayer.get_unique_id() and game.is_vr() else state.get("xr",{})
			var eye:Vector3=pose.get("head",Transform3D(Basis.IDENTITY,Vector3.UP*1.48)).origin
			actor.underwater=contents.liquid(contents.at(actor.global_transform*eye))
			if multiplayer.is_server() and kind in [-4,-5] and game.clock>=hurt_until.get(id,0):
				hurt_until[id]=game.clock+.6;game._damage(id,id,20,"environment",true)
		var air:Dictionary=breath.get(id,{"left":12.0,"next":0.0,"damage":2,"serial":state.serial})
		if not actor.underwater or air.serial!=state.serial:air={"left":12.0,"next":game.clock,"damage":2,"serial":state.serial}
		else:air.left=maxf(0,air.left-_delta)
		actor.air_left=air.left;breath[id]=air
		if actor.underwater and air.left<=0 and multiplayer.is_server() and game.clock>=air.next:
			air.next=game.clock+1.0
			game._damage(id,id,air.damage,"DROWNING",true)
			air.damage=mini(10,air.damage+2)
	for id in breath.keys():
		if not game.fighters.has(id):breath.erase(id)
	var touching_push: Dictionary={}
	for region in regions:
		for actor in region.area.get_overlapping_bodies():
			if not "peer_id" in actor or not game.players.has(actor.peer_id): continue
			var id: int=actor.peer_id
			if game.players[id].dead or game.players[id].spectator or game.match_mode.special.blocked(id): continue
			if region.kind in ["water","slime","lava"]:
				# Authoritative BSP queries supersede imprecise imported liquid boxes.
				if not has_contents:actor.in_water=true
				if has_contents:continue
			if region.kind=="trigger_push":
				if not multiplayer.is_server() and id!=multiplayer.get_unique_id():continue
				var push: Vector3=push_velocity(region.data,1.0 if legacy_train_push else 10.0)
				if push.is_zero_approx():continue
				actor.velocity=push;actor.blast_velocity=Vector2.ZERO
				if push.y>0:actor.floor_grace=0;actor.stepped_last_frame=false
				var key: String=str(id)+":"+str(region.area.get_instance_id())
				touching_push[key]=true
				if multiplayer.is_server() and not push_contacts.has(key):game._ability_fx.rpc("jump_pad",actor.position,actor.position+push.normalized(),0)
				continue
			if not multiplayer.is_server(): continue
			if region.kind=="trigger_teleport" and game.clock>=teleport_until.get(id,0):
				var target: String=region.data.get("target","")
				if not destinations.has(target): continue
				var dest: Dictionary=destinations[target]
				var departure: Vector3=actor.position
				actor.position=dest.position
				telefrag(id)
				actor.reset_view()
				actor.velocity=Vector3.ZERO
				game.players[id].yaw=dest.yaw
				if id==multiplayer.get_unique_id(): game.local_yaw=dest.yaw
				game.players[id].serial+=1
				# Both ends are audible to nearby players, with one cue for adjacent pads.
				if departure.distance_to(dest.position)>2.0:game._teleport_fx.rpc(departure)
				game._teleport_fx.rpc(dest.position)
				teleport_until[id]=game.clock+1.0
				game.history.clear()
			elif region.kind in ["trigger_hurt","lava","slime"] and game.clock>=hurt_until.get(id,0):
				hurt_until[id]=game.clock+.6
				game._damage(id,id,int(region.data.get("dmg",20)),"environment",true)
	push_contacts=touching_push
	if not multiplayer.is_server(): return
	for i in range(game.gates.size()):
		var gate: Dictionary=game.gates[i]
		if not gate.get("bsp",false) or gate.open: continue
		if game.match_mode.kind=="as" and game.match_mode.assault.stage<int(gate.get("as_unlock",0)):continue
		for id in game.players:
			if not game.players[id].dead and game.fighters[id].position.distance_to(gate.center)<3:
				gate.until=game.clock+4
				game._gate_state.rpc(i,true)
				break

static func push_velocity(data: Dictionary,legacy_scale: float=10.0) -> Vector3:
	var direction:=Vector3.FORWARD
	if data.has("angles"):
		var angles: PackedFloat64Array=str(data.angles).split_floats(" ",false)
		if angles.size()!=3:return Vector3.ZERO
		var pitch:=deg_to_rad(angles[0]);var yaw:=deg_to_rad(angles[1])
		if angles==PackedFloat64Array([0,1,0]):direction=Vector3.UP
		elif angles==PackedFloat64Array([0,-1,0]):direction=Vector3.DOWN
		else:direction=Vector3(-cos(pitch)*sin(yaw),-sin(pitch),-cos(pitch)*cos(yaw))
	else:
		var angle:=float(data.get("angle",0))
		direction=Vector3.UP if angle==-1 else Vector3.DOWN if angle==-2 else Vector3(-sin(deg_to_rad(angle)),0,-cos(deg_to_rad(angle)))
	var speed:=float(data.get("speed",1000))
	if speed==0:speed=1000
	var scale:=float(data.get("fpsloppa_push_scale",legacy_scale))
	var velocity:=direction*speed*scale*Loader.SCALE
	return velocity.limit_length(320) if velocity.is_finite() else Vector3.ZERO

func telefrag(arriving: int) -> void:
	if not multiplayer.is_server() or not game.fighters.has(arriving):return
	var actor=game.fighters[arriving]
	for id in game.players:
		if id==arriving or game.players[id].dead or game.players[id].spectator:continue
		var other=game.fighters[id]
		var offset: Vector3=actor.position-other.position
		var vertical:=maxf(0,maxf(other.position.y+.3-(actor.position.y+actor.collision_height-.3),actor.position.y+.3-(other.position.y+other.collision_height-.3)))
		if Vector2(offset.x,offset.z).length_squared()+vertical*vertical<.61*.61:
			game._damage(id,arriving,100000,"TELEFRAG",true)

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
