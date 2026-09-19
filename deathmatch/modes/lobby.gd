extends Node
const ID:="__waiting_lobby__"
const HASH:="fpsloppa-built-in-waiting-room-v1"
var game
var enabled:=false
var seconds:=45
var until:=0.0
var view: Dictionary={}
var last_results: Dictionary={}
var fallback: Dictionary={}
var offered: Array=[]
var ballot_id:=0
var selections: Dictionary={}
const OPTION_COUNT:=9
func setup(arena: Node) -> void:game=arena
func active() -> bool:return game.current_map==ID
func choices() -> Array:
	var result: Array=[]
	for mode in game.votes.allowed_modes:
		var maps: Array=game.maps_for_mode(mode)
		for map in maps:
			if game.map_catalog.any(func(row):return row.id==map and (mode!="as" or game.Maps.supports_assault(row.path))):result.append({"mode":mode,"map":map})
	return result
func ballot_open() -> bool:
	return not offered.is_empty() and (active() or game.intermission>0)
func reset_ballot() -> void:
	offered.clear();selections.clear();fallback.clear();view.clear()
func prepare() -> void:
	reset_ballot();ballot_id+=1
	var candidates: Array=[]
	var seen: Dictionary={}
	for option in choices():
		var required: String=game.armory.required(option.mode)
		var rules: Array=[required] if not required.is_empty() else game.armory.IDS
		for rule in rules:
			var key: String=option.mode+"|"+option.map+"|"+rule
			if seen.has(key):continue
			seen[key]=true
			var title: String=option.map
			var hash: String=""
			for row in game.map_catalog:
				if row.id==option.map:title=row.title;hash=row.sha256;break
			candidates.append({"mode":option.mode,"map":option.map,"rules":rule,"title":title,"sha256":hash})
	if not game.votes.enabled:
		var next: String=game.map_rotation[(game.rotation_index+1)%game.map_rotation.size()] if not game.map_rotation.is_empty() else game.current_map
		var defaults: Array=candidates.filter(func(row):return row.mode==game.match_mode.kind and row.map==next and row.rules==(game.armory.required(row.mode) if not game.armory.required(row.mode).is_empty() else game.armory.preferred))
		offered=(defaults if not defaults.is_empty() else candidates).slice(0,1)
		if not offered.is_empty():fallback=spec(offered[0])
		return
	candidates.shuffle()
	offered=candidates.slice(0,OPTION_COUNT)
	# The shuffled order is also the fixed tie breaker, shared by every client.
	if not offered.is_empty():fallback=spec(offered[0])
func spec(option: Dictionary) -> Dictionary:
	return {"mode":option.mode,"map":option.map,"rules":option.rules}
func begin() -> void:
	if not enabled or active():return
	if offered.is_empty():prepare()
	if offered.is_empty():game._restart_round();return
	game._rotate_map(ID);until=game.clock+seconds;game.round_left=seconds
	game._announcement.rpc("Waiting room · vote for the next match on the wall")
func build() -> bool:
	if not game.headless:load("res://deathmatch/maps/atmosphere.gd").apply(game,ID)
	game.match_mode.fortress.reset()
	game.map_assault.clear()
	for child in game.get_node("Map").get_children():child.free()
	game.match_mode.clear_visuals();game.pickups.clear();game.gates.clear();game.lifts.clear();game.spawn_points.clear();game.spawn_yaws.clear();game.map_objectives.clear();game.ctf_spawns=[[],[]];game.tf_capture.clear();game.tf_resupply=[[],[]]
	var root:=Node3D.new();root.name="WaitingRoom";game.get_node("Map").add_child(root)
	for spec in [[Vector3(0,-.5,0),Vector3(24,1,24)],[Vector3(-12,4,0),Vector3(1,9,24)],[Vector3(12,4,0),Vector3(1,9,24)],[Vector3(0,4,-12),Vector3(24,9,1)],[Vector3(0,4,12),Vector3(24,9,1)],[Vector3(0,9,0),Vector3(24,1,24)]]:
		var body:=StaticBody3D.new();body.position=spec[0];body.collision_layer=1;root.add_child(body)
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=spec[1];shape.shape=box;body.add_child(shape)
		if not game.headless:
			var mesh:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=spec[1];mesh.mesh=cube
			var material:=StandardMaterial3D.new();material.albedo_color=Color(.34,.40,.44);material.roughness=1;material.emission_enabled=true;material.emission=Color(.08,.09,.10);mesh.material_override=material;body.add_child(mesh)
	for z in range(4):
		for x in range(8):game.spawn_points.append(Vector3(x*3-10.5,.05,z*3-4.5));game.spawn_yaws.append(0.0)
	game.fall_limit=-5;game.current_map=ID;game.map_title="Waiting lobby";game.map_sha=HASH.sha256_text()
	if not game.headless:
		var light:=OmniLight3D.new();light.position=Vector3(0,6,0);light.omni_range=22;light.light_energy=2;root.add_child(light)
		var wall=load("res://deathmatch/modes/lobby_wall.gd").new();wall.name="VoteWall";root.add_child(wall)
		wall.position=Vector3(-4.0,3.4,-11.35);wall.setup(game)
		var mirror=load("res://deathmatch/modes/lobby_mirror.gd").new();mirror.name="TrackingMirror";root.add_child(mirror)
		var results=load("res://deathmatch/modes/lobby_results.gd").new();results.name="LastRoundResults";root.add_child(results);results.position=Vector3(0,3.1,11.35);results.rotation.y=PI;results.setup(game)
		mirror.position=Vector3(6.5,1.25,-11.3);mirror.setup(game)
	return true
func select_option(index: int) -> void:
	var data: Dictionary=snapshot() if multiplayer.is_server() else view
	if multiplayer.is_server():cast_option(multiplayer.get_unique_id(),int(data.get("id",-1)),index)
	else:selection_request.rpc_id(1,int(data.get("id",-1)),index)
@rpc("any_peer","call_remote","reliable",0)
func selection_request(generation: int,index: int) -> void:
	if multiplayer.is_server():cast_option(multiplayer.get_remote_sender_id(),generation,index)
func cast_option(id: int,generation: int,index: int) -> bool:
	if not ballot_open() or not game.active or not game.votes.enabled or generation!=ballot_id or index<0 or index>=offered.size() or not game.votes.eligible(id):return false
	if active() and game.clock>=until:return false
	if selections.get(id,-1)==index:return true
	selections[id]=index
	return true
func submit(mode: String,map: String,rules:String="") -> void:
	var data: Dictionary=snapshot() if multiplayer.is_server() else view
	var options: Array=data.get("options",[])
	for index in options.size():
		var option: Dictionary=options[index]
		if option.mode==mode and option.map==map and (rules.is_empty() or option.rules==rules):select_option(index);return
func cast(id: int,mode: String,map: String) -> bool:return cast_value(id,mode+"|"+map)
func cast_value(id: int,value: String) -> bool:
	var parts:=value.split("|")
	if parts.size() not in [2,3]:return false
	for index in offered.size():
		var option: Dictionary=offered[index]
		if option.mode==parts[0] and option.map==parts[1] and (parts.size()==2 or option.rules==parts[2]):return cast_option(id,ballot_id,index)
	return false
func remove_peer(id: int) -> void:
	selections.erase(id)
func tally() -> Array:
	var counts: Array=[];counts.resize(offered.size());counts.fill(0)
	for id in selections:
		# Preserve votes through the lobby's per-peer map admission transition.
		if game.players.has(id):
			if game.players[id].spectator:continue
		elif not game.pending_names.has(id):continue
		var index: int=selections[id]
		if index>=0 and index<counts.size():counts[index]+=1
	return counts
func result() -> Dictionary:
	if offered.is_empty():return fallback.duplicate()
	var counts:=tally();var winner:=0
	for index in counts.size():
		if counts[index]>counts[winner]:winner=index
	return spec(offered[winner])
func snapshot() -> Dictionary:
	if not ballot_open():return {}
	return {"id":ballot_id,"epoch":game.map_epoch,"stage":"lobby" if active() else "intermission","results":last_results,"seconds":maxi(0,ceili(until-game.clock if active() else game.intermission)),"options":offered.duplicate(true),"counts":tally(),"selections":selections.duplicate(),"next":result(),"enabled":game.votes.enabled}
func launch() -> void:
	var selected:=result()
	if selected.is_empty():reset_ballot();game._restart_round();return
	reset_ballot()
	game.votes.apply_rules(selected.mode,selected.rules)
	if game.mode_maplists.has(game.match_mode.maplist_kind(selected.mode)):game.map_rotation=game.maps_for_mode(selected.mode).duplicate()
	game.rotation_index=maxi(0,game.map_rotation.find(selected.map));game.pending_teams.clear()
	for s in game.players.values():s.team=-1
	game._rotate_map(selected.map)
func tick(delta: float) -> void:
	game.round_left=maxf(0,until-game.clock)
	for id in game.players:
		var s: Dictionary=game.players[id];var actor=game.fighters[id]
		s.fire=false;s.offhand_fire=false;s.melee=false;s.charge=0
		if s.spectator:
			game._move_spectator(id,s.move,s.fly,s.yaw,s.slow,delta);continue
		s.hp=100;s.armor=0
		if game.clock-s.last_input>.35:s.move=Vector2.ZERO;s.room=Vector3.ZERO;s.jump=false
		game._update_crouch(id,s.xr)
		actor.speed_multiplier=1;actor.simulate(s.move,s.yaw,s.slow,delta,s.jump)
		if not s.xr.is_empty():
			var shift: Vector3=game.RoomScale.move_capsule(actor,s.room,s.yaw,delta);s.room-=shift;game.RoomScale.rebase_pose(s.xr,shift)
			if id==multiplayer.get_unique_id() and game.is_vr():game.xr_rig.compensate_room_move(shift)
		if actor.position.y<game.fall_limit or actor.position.y>8 or absf(actor.position.x)>11.6 or absf(actor.position.z)>11.6:game._spawn(id)
	if game.clock<until or game.map_loading:return
	launch()
