extends Node
const ID:="__waiting_lobby__"
const HASH:="fpsloppa-built-in-waiting-room-v1"
var game
var enabled:=false
var seconds:=45
var until:=0.0
var view: Dictionary={}
var fallback: Dictionary={}
var offered: Array=[]
var confirmed:=false
var vote_result:=""
var next_publish:=0.0
func setup(arena: Node) -> void:game=arena
func active() -> bool:return game.current_map==ID
func choices() -> Array:
	var result: Array=[]
	for mode in game.votes.allowed_modes:
		var maps: Array=game.mode_maplists.get(mode,game.map_rotation)
		if maps.is_empty():maps=[game.selected_map]
		for map in maps:
			if game.map_catalog.any(func(row):return row.id==map and (mode!="as" or game.Maps.supports_assault(row.path))):result.append({"mode":mode,"map":map})
	return result
func begin() -> void:
	if not enabled or active():return
	offered=choices();confirmed=false;vote_result=""
	var next: String=game.map_rotation[(game.rotation_index+1)%game.map_rotation.size()] if not game.map_rotation.is_empty() else game.current_map
	fallback={"mode":game.match_mode.kind,"map":next}
	if not fallback in offered and not offered.is_empty():fallback=offered[0]
	if offered.is_empty():game._restart_round();return
	game._rotate_map(ID);game.votes.cooldown=0;until=game.clock+seconds;game.round_left=seconds
	game._announcement.rpc("Waiting room · choose the next match on the voting wall")
func build() -> bool:
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
		var wall:=preload("res://deathmatch/modes/lobby_wall.gd").new();wall.name="VoteWall";root.add_child(wall)
		wall.position=Vector3(-4.0,3.4,-11.35);wall.setup(game)
		var mirror:=preload("res://deathmatch/modes/lobby_mirror.gd").new();mirror.name="TrackingMirror";root.add_child(mirror)
		mirror.position=Vector3(6.5,1.25,-11.3);mirror.setup(game)
	return true
func submit(mode: String,map: String) -> void:
	if multiplayer.is_server():cast(multiplayer.get_unique_id(),mode,map)
	else:vote_request.rpc_id(1,mode,map)
@rpc("any_peer","call_remote","reliable",0)
func vote_request(mode: String,map: String) -> void:
	if multiplayer.is_server():cast(multiplayer.get_remote_sender_id(),mode,map)
func cast(id: int,mode: String,map: String) -> bool:
	if not active():return false
	var value:=mode+"|"+map
	if not game.votes.ballot.is_empty() and game.votes.ballot.kind=="match" and game.votes.ballot.value==value:return game.votes.cast(id,true)
	return game.votes.start(id,"match",value)
func accept_match(value: String) -> void:
	var pair:=value.split("|")
	if pair.size()!=2:return
	var choice: Dictionary={"mode":pair[0],"map":pair[1]}
	if not choice in offered:return
	fallback=choice;confirmed=true;vote_result="VOTE PASSED · "+pair[0].to_upper()+" / "+pair[1];next_publish=0
func result() -> Dictionary:return fallback.duplicate()
func snapshot() -> Dictionary:
	if not active():return {}
	return {"seconds":maxi(0,ceili(until-game.clock)),"options":offered.duplicate(true),"next":fallback.duplicate(),"confirmed":confirmed,"result":vote_result,"vote":game.votes.snapshot(),"proposal_wait":maxf(0,game.votes.cooldown-game.clock)}
@rpc("authority","call_remote","reliable",0)
func receive_state(data: Dictionary) -> void:
	if active():view=data
func publish() -> void:
	if multiplayer.is_server() and not game.practice:receive_state.rpc(snapshot())
func tick(delta: float) -> void:
	if game.clock>=next_publish:publish();next_publish=game.clock+1
	game.round_left=maxf(0,until-game.clock)
	for id in game.players:
		var s: Dictionary=game.players[id];var actor=game.fighters[id]
		s.fire=false;s.offhand_fire=false;s.melee=false;s.charge=0
		if s.spectator:
			game._move_spectator(id,s.move,s.fly,s.yaw,s.slow,delta);continue
		s.hp=100;s.armor=0
		if game.clock-s.last_input>.35:s.move=Vector2.ZERO;s.room=Vector3.ZERO;s.jump=false
		actor.speed_multiplier=1;actor.simulate(s.move,s.yaw,s.slow,delta,s.jump)
		if not s.xr.is_empty():
			var shift: Vector3=game.RoomScale.move_capsule(actor,s.room,s.yaw,delta);s.room-=shift;game.RoomScale.rebase_pose(s.xr,shift)
			if id==multiplayer.get_unique_id() and game.is_vr():game.xr_rig.compensate_room_move(shift)
		if actor.position.y<game.fall_limit or actor.position.y>8 or absf(actor.position.x)>11.6 or absf(actor.position.z)>11.6:game._spawn(id)
	if game.clock<until or game.map_loading:return
	var selected:=result();view.clear()
	game.match_mode.kind=selected.mode
	if game.mode_maplists.has(selected.mode):game.map_rotation=game.mode_maplists[selected.mode].duplicate()
	game.rotation_index=maxi(0,game.map_rotation.find(selected.map));game.pending_teams.clear()
	for s in game.players.values():s.team=-1
	game._rotate_map(selected.map)
