extends Node
const ID:="__waiting_lobby__"
const HASH:="fpsloppa-built-in-waiting-room-v1"
var game
var enabled:=false
var seconds:=45
var until:=0.0
var ballots: Dictionary={}
var view: Dictionary={}
var fallback: Dictionary={}
var offered: Array=[]
var last_vote: Dictionary={}
var next_publish:=0.0
func setup(arena: Node) -> void:game=arena
func active() -> bool:return game.current_map==ID
func choices() -> Array:
	var result: Array=[]
	for mode in game.votes.allowed_modes:
		var maps: Array=game.mode_maplists.get(mode,game.map_rotation)
		if maps.is_empty():maps=[game.selected_map]
		for map in maps:
			if game.map_catalog.any(func(row):return row.id==map):result.append({"mode":mode,"map":map})
	return result
func begin() -> void:
	if not enabled or active():return
	offered=choices();ballots.clear();last_vote.clear()
	var next: String=game.map_rotation[(game.rotation_index+1)%game.map_rotation.size()] if not game.map_rotation.is_empty() else game.current_map
	fallback={"mode":game.match_mode.kind,"map":next}
	if not fallback in offered and not offered.is_empty():fallback=offered[0]
	if offered.is_empty():game._restart_round();return
	game._rotate_map(ID);until=game.clock+seconds;game.round_left=seconds
	game._announcement.rpc("Waiting room · open LOBBY VOTE to choose the next match")
func build() -> bool:
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
	return true
func submit(mode: String,map: String) -> void:
	if multiplayer.is_server():cast(multiplayer.get_unique_id(),mode,map)
	else:vote_request.rpc_id(1,mode,map)
@rpc("any_peer","call_remote","reliable",0)
func vote_request(mode: String,map: String) -> void:
	if multiplayer.is_server():cast(multiplayer.get_remote_sender_id(),mode,map)
func cast(id: int,mode: String,map: String) -> bool:
	if not active() or not game.players.has(id) or id<=0 or game.players[id].spectator or game.clock<last_vote.get(id,0.0):return false
	var choice: Dictionary={"mode":mode,"map":map}
	if not choice in offered:return false
	ballots[id]=choice;last_vote[id]=game.clock+.4;next_publish=0;return true
func result() -> Dictionary:
	var best:=fallback.duplicate();var count:=0
	for option in offered:
		var votes:=ballots.values().count(option)
		if votes>count or votes==count and option==fallback:best=option;count=votes
	return best
func snapshot() -> Dictionary:
	if not active():return {}
	var counts: Array=[]
	for option in offered:counts.append({"mode":option.mode,"map":option.map,"votes":ballots.values().count(option)})
	return {"seconds":maxi(0,ceili(until-game.clock)),"options":counts,"voted":ballots.keys()}
@rpc("authority","call_remote","reliable",0)
func receive_state(data: Dictionary) -> void:
	if active():view=data
func publish() -> void:
	if multiplayer.is_server() and not game.practice:receive_state.rpc(snapshot())
func tick(delta: float) -> void:
	if game.clock>=next_publish:publish();next_publish=game.clock+1
	for id in ballots.keys():
		if not game.players.has(id):ballots.erase(id)
	game.round_left=maxf(0,until-game.clock)
	for id in game.players:
		var s: Dictionary=game.players[id];var actor=game.fighters[id]
		s.fire=false;s.offhand_fire=false;s.melee=false;s.charge=0;s.hp=100;s.armor=0
		if game.clock-s.last_input>.35:s.move=Vector2.ZERO;s.room=Vector3.ZERO;s.jump=false
		actor.speed_multiplier=1;actor.simulate(s.move,s.yaw,s.slow,delta,s.jump)
		if not s.xr.is_empty():
			var shift: Vector3=game.RoomScale.move_capsule(actor,s.room,s.yaw,delta);s.room-=shift;game.RoomScale.rebase_pose(s.xr,shift)
			if id==multiplayer.get_unique_id() and game.is_vr():game.xr_rig.compensate_room_move(shift)
		if actor.position.y<game.fall_limit:game._spawn(id)
	if game.clock<until or game.map_loading:return
	var selected:=result();ballots.clear();view.clear()
	game.match_mode.kind=selected.mode
	if game.mode_maplists.has(selected.mode):game.map_rotation=game.mode_maplists[selected.mode].duplicate()
	game.rotation_index=maxi(0,game.map_rotation.find(selected.map));game.pending_teams.clear()
	for s in game.players.values():s.team=-1
	game._rotate_map(selected.map)
