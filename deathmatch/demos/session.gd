extends Node
const MAX_PLAYERS:=preload("res://deathmatch/server/config.gd").MAX_CLIENTS
const MAGIC:="FPSDEMO1"
const MAX_FILE:=1_073_741_824
const MAX_FRAME:=2_097_152
# Retired cues remain readable in old recordings, but are never played.
const LEGACY_ANNOUNCER_CUES=["start","team_deathmatch","capture_the_flag","last_man_standing","round_winner","game_over"]
const EVENTS=["_ability_fx","_movement_sound","_saw_contact","_announcer_cue","_shot_fx","_melee_fx","_impacts","_hurt_fx","_projectile_end","_teleport_fx"]
var game
var auto_record:=false
var auto_path:=""
var recording:=false
var playing:=false
var paused:=false
var speed:=1.0
var position_seconds:=0.0
var duration:=0.0
var selected_player:=0
var viewpoint:="first"
var output: FileAccess
var input: FileAccess
var offsets: Array[int]=[]
var times: Array[float]=[]
var cursor:=0
var started:=0.0
var events: Array=[]
var path:=""
var message:=""
var camera: Camera3D
var gun: Node3D
var gun_id:=-1
var exit_at_end:=false
var stop_at:=INF
var free_rotation:=Vector2.ZERO
func setup(arena: Node) -> void:game=arena
func folder() -> String:return game.Maps.Paths.folder("demos")
func start_record(filename: String="") -> bool:
	if recording or playing or not game.active:return false
	path=folder()+Time.get_datetime_string_from_system().replace(":","-")+".fpsdemo" if filename.is_empty() else filename
	if FileAccess.file_exists(path):message="Demo already exists; choose a new filename.";return false
	output=FileAccess.open(path,FileAccess.WRITE)
	if not output:message="Cannot create demo file.";return false
	output.store_buffer(MAGIC.to_ascii_buffer());started=game.clock;events.clear();recording=true;message="Recording "+path.get_file();return true
func stop_record() -> void:
	auto_record=false
	if output:output.flush();output.close();output=null
	recording=false;events.clear()
func event(method: String,args: Array) -> void:
	if recording and method in EVENTS and events.size()<256:events.append([method,args])
func capture(snapshot: Array) -> void:
	if auto_record and not recording and game.active:start_record(auto_path)
	if not recording:return
	snapshot=snapshot.duplicate(true)
	snapshot[10]["lobby"]=game.lobby.snapshot() if multiplayer.is_server() else game.lobby.view.duplicate(true)
	var roster: Array=[]
	for id in game.players:
		var s: Dictionary=game.players[id]
		roster.append([id,s.name,s.color,game.fighters[id].position,s.yaw,s.spectator,s.team])
	var frame: Dictionary={"time":game.clock-started,"map":game.current_map,"hash":game.map_sha,"roster":roster,"avatars":game.avatars.choices.duplicate(true),"snapshot":snapshot,"events":events.duplicate(true)}
	var bytes:=var_to_bytes(frame)
	if bytes.size()>MAX_FRAME or output.get_position()+bytes.size()+4>MAX_FILE:stop_record();message="Recording stopped at size limit.";return
	output.store_32(bytes.size());output.store_buffer(bytes);events.clear()
func read_frame() -> Dictionary:
	if not input or input.get_position()+4>input.get_length():return {}
	var size:=input.get_32()
	if size<1 or size>MAX_FRAME or input.get_position()+size>input.get_length():return {}
	var frame=bytes_to_var(input.get_buffer(size)) # Objects disabled; never execute serialized resources.
	return frame if valid_frame(frame) else {}
static func typed_values(values: Variant,types: Array) -> bool:
	if not values is Array or values.size()!=types.size():return false
	for i in types.size():
		if typeof(values[i])!=types[i]:return false
		if values[i] is float and not is_finite(values[i]):return false
		if values[i] is Vector3 and not values[i].is_finite():return false
	return true
static func valid_frame(frame: Variant) -> bool:
	if not frame is Dictionary or not frame.get("time") is float or not is_finite(frame.time) or frame.time<0:return false
	if not frame.get("map") is String or frame.map.length()>80 or not frame.get("hash") is String:return false
	if not frame.get("roster") is Array or frame.roster.size()>MAX_PLAYERS or not frame.get("avatars") is Dictionary:return false
	for row in frame.roster:
		if not row is Array or row.size()!=7 or not row[0] is int or not row[1] is String or row[1].length()>80 or not row[2] is int or row[2]<0 or row[2]>7 or not row[3] is Vector3 or not row[3].is_finite() or not row[4] is float or not is_finite(row[4]) or not row[5] is bool or not row[6] in [-1,0,1]:return false
	var s=frame.get("snapshot")
	if not s is Array or s.size()!=12 or not s[0] is Array or s[0].size()>MAX_PLAYERS or not s[1] is PackedByteArray or s[1].size()>8192 or not s[7] is Array or s[7].size()>1024 or not s[8] is Array or not s[10] is Dictionary or not s[11] is Dictionary:return false
	if not typed_values([s[2],s[3],s[4],s[5],s[6],s[9]],[TYPE_FLOAT,TYPE_FLOAT,TYPE_STRING,TYPE_INT,TYPE_FLOAT,TYPE_INT]):return false
	for gate in s[8]:
		if not gate is bool:return false
	for shot in s[7]:
		if not typed_values(shot,[TYPE_INT,TYPE_VECTOR3,TYPE_INT,TYPE_INT,TYPE_VECTOR3,TYPE_FLOAT,TYPE_FLOAT]):return false
		if not game_weapon(shot[3]):return false
	for row in s[0]:
		if not row is Array or row.size()!=22 or not row[0] is int or not row[1] is Vector3 or not row[1].is_finite() or not row[2] is Vector3 or not row[2].is_finite() or not row[8] is int or not game_weapon(row[8]) or not row[18] is Dictionary:return false
	if not frame.get("events") is Array or frame.events.size()>256:return false
	for e in frame.events:
		if not e is Array or e.size()!=2 or not e[0] in EVENTS or not e[1] is Array:return false
		var schemas={"_saw_contact":[TYPE_VECTOR3,TYPE_VECTOR3,TYPE_INT,TYPE_INT],"_announcer_cue":[TYPE_STRING,TYPE_INT],"_shot_fx":[TYPE_INT,TYPE_INT,TYPE_BOOL],"_melee_fx":[TYPE_INT,TYPE_BOOL],"_impacts":[TYPE_VECTOR3,TYPE_PACKED_VECTOR3_ARRAY,TYPE_INT],"_hurt_fx":[TYPE_INT,TYPE_VECTOR3,TYPE_VECTOR3,TYPE_INT,TYPE_BOOL,TYPE_BOOL,TYPE_INT],"_projectile_end":[TYPE_INT,TYPE_VECTOR3,TYPE_INT],"_teleport_fx":[TYPE_VECTOR3]}
		schemas["_ability_fx"]=[TYPE_STRING,TYPE_VECTOR3,TYPE_VECTOR3,TYPE_INT]
		schemas["_movement_sound"]=[TYPE_INT,TYPE_INT,TYPE_INT,TYPE_STRING,TYPE_VECTOR3]
		if e[0]=="_hurt_fx" and e[1].size()==8:schemas["_hurt_fx"].append(TYPE_BOOL)
		if not typed_values(e[1],schemas[e[0]]):return false
		if e[0]=="_announcer_cue" and not e[1][0] in preload("res://deathmatch/audio/announcer.gd").CLIPS+LEGACY_ANNOUNCER_CUES:return false
		if e[0]=="_shot_fx" and not game_weapon(e[1][1]):return false
		if e[0] in ["_impacts","_projectile_end"] and not game_weapon(e[1][2]):return false
	return true
static func game_weapon(id: int) -> bool:return id>=0 and id<preload("res://deathmatch/weapons.gd").DATA.size()
func open_demo(filename: String) -> bool:
	if game.is_vr():message="Demo playback uses desktop mode. Launch with --xr-mode off.";return false
	stop_record()
	if playing:stop_playback();game.disconnect_game("Loading demo")
	var source:=FileAccess.open(filename,FileAccess.READ)
	if not source or source.get_length()<12 or source.get_length()>MAX_FILE:message="Invalid demo size or unreadable file.";return false
	if source.get_buffer(8).get_string_from_ascii()!=MAGIC:message="Unsupported demo format.";return false
	input=source;offsets.clear();times.clear()
	while input.get_position()<input.get_length():
		var offset:=input.get_position();var frame:=read_frame()
		if frame.is_empty() or (not times.is_empty() and frame.time<times.back()) or offsets.size()>=200000:
			input.close();input=null;message="Invalid or incomplete demo frame.";return false
		offsets.append(offset);times.append(frame.time)
	if offsets.is_empty():message="Demo contains no frames.";input.close();input=null;return false
	game.disconnect_game("Demo playback")
	game.dedicated=true;game.menu_open=false;game.active=true
	playing=true;paused=false;position_seconds=0;duration=times.back();cursor=0;path=filename
	camera=Camera3D.new();camera.name="DemoCamera";camera.near=.04;camera.fov=85;game.add_child(camera);camera.make_current();game.camera=camera
	if game.hud:game.hud.show_menu(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	seek(0);message="Playing "+filename.get_file();return playing
func stop_playback() -> void:
	playing=false
	if input:input.close();input=null
	if is_instance_valid(camera):camera.queue_free()
	if is_instance_valid(gun):gun.queue_free()
	camera=null;gun=null;gun_id=-1;game.dedicated=false
func seek(time: float) -> void:
	if not playing:return
	position_seconds=clampf(time,0,duration);cursor=maxi(0,times.bsearch(position_seconds,false)-1)
	game.effects.clear()
	game.announcer.clear_audio()
	input.seek(offsets[cursor]);apply_frame(read_frame(),false);cursor+=1
func next_player() -> void:
	var ids: Array=game.players.keys().filter(func(id):return not game.players[id].spectator);ids.sort()
	if not ids.is_empty():selected_player=ids[(ids.find(selected_player)+1)%ids.size()]
func apply_frame(frame: Dictionary,play_events: bool=true) -> void:
	if frame.is_empty():stop_playback();message="Demo read failed.";return
	if game.map_sha!=frame.hash or game.current_map!=frame.map:
		var id: String=frame.map
		if id!=game.lobby.ID:
			var maps: Array=game.map_catalog.filter(func(row):return row.sha256==frame.hash)
			if maps.is_empty():stop_playback();game.disconnect_game("Demo needs map "+id+" (matching BSP hash).");return
			id=maps[0].id
		game._clear_map_players();game._load_map(id);game.active=true;game.camera=camera
		# Loading a BSP makes its Overview camera current; restore the replay camera.
		if is_instance_valid(camera):camera.make_current()
	game.map_loading=false;game._roster(frame.roster);game.active=true
	for id in frame.avatars:
		var choice=frame.avatars[id]
		if choice is Dictionary and game.avatars.library.entries.has(choice.get("hash","")) and game.avatars.choices.get(id,{})!=choice:
			game.avatars.choices[id]=choice;game.avatars.queue_avatar(id)
	var snap: Array=frame.snapshot
	game.round_left=snap[2];game.intermission=snap[3];game.round_message=snap[4];game.frag_limit=snap[5];game.time_limit=snap[6]
	game.match_mode.receive(snap[10]);game.lobby.view=snap[10].get("lobby",{});game.votes.view=snap[11]
	for row in snap[0]:
		if not game.players.has(row[0]):continue
		var state: Dictionary=game.players[row[0]];var actor=game.fighters[row[0]]
		state.merge({"yaw":row[3],"pitch":row[4],"hp":row[5],"armor":row[6],"dead":row[7],"weapon":row[8],"ammo":row[9],"owned":row[10],"kills":row[11],"deaths":row[12],"ping":row[13],"serial":row[14],"cooldown":row[17],"xr":row[18],"spectator":row[20]},true)
		if not play_events or actor.spawn_serial!=row[14]:actor.position=row[1];actor.rotation.y=row[3]
		actor.spawn_serial=row[14];actor.target=row[1];actor.target_yaw=row[3];actor.visual_velocity=row[2];actor.visual_pitch=row[4];actor.visual_weapon=row[8];actor.xr_pose=row[18];actor.spectator=row[20];actor.show_alive(not row[7],false)
	for i in mini(snap[1].size(),game.pickups.size()):
		game.pickups[i].available=snap[1][i]==1
		if is_instance_valid(game.pickups[i].node):game.pickups[i].node.visible=snap[1][i]==1 and not game.match_mode.kind in ["ig","cc"]
	var live: Array=[]
	for shot in snap[7]:
		live.append(shot[0])
		if not game.projectiles.has(shot[0]):game._projectile_spawn(shot[0],shot[2],shot[3],shot[1],shot[4],shot[5],shot[6])
		game.projectiles[shot[0]].position=shot[1]
	for id in game.projectiles.keys():
		if not id in live:
			if is_instance_valid(game.projectiles[id].node):game.projectiles[id].node.queue_free()
			game.projectiles.erase(id)
	for i in mini(snap[8].size(),game.gates.size()):
		if game.gates[i].open!=snap[8][i]:game._gate_state(i,snap[8][i])
	if not game.players.has(selected_player):next_player()
	if play_events:
		for e in frame.events:game.callv(e[0],e[1])
func tick(delta: float) -> void:
	if not playing:return
	if not paused:
		position_seconds=minf(position_seconds+delta*speed,duration)
		while cursor<times.size() and times[cursor]<=position_seconds:
			input.seek(offsets[cursor]);apply_frame(read_frame());cursor+=1
			if not playing:return
		if position_seconds>=minf(duration,stop_at):
			paused=true
			if exit_at_end:finish_movie()
	for actor in game.fighters.values():
		actor.position=actor.position.lerp(actor.target,minf(delta*20*speed,1));actor.rotation.y=lerp_angle(actor.rotation.y,actor.target_yaw,minf(delta*20*speed,1))
	if not game.lobby.active():game.match_mode.draw_objectives()
	for shot in game.projectiles.values():
		if is_instance_valid(shot.node):shot.node.position=shot.position
	update_camera(delta)
func update_camera(delta: float) -> void:
	if not is_instance_valid(camera):return
	for id in game.fighters:game.fighters[id].show_alive(not game.players[id].dead,id==selected_player and viewpoint=="first")
	var actor=game.fighters.get(selected_player)
	if not actor:return
	var s: Dictionary=game.players[selected_player]
	var aim:=Transform3D(Basis(Vector3.UP,s.yaw)*Basis(Vector3.RIGHT,s.pitch),actor.position+Vector3.UP*1.48)
	if not s.xr.is_empty():aim=actor.global_transform*s.xr.head
	if viewpoint=="free":
		if not game.menu_open:
			var input_dir:=Vector3(float(game.bindings.pressed("right"))-float(game.bindings.pressed("left")),float(game.bindings.pressed("jump"))-float(game.bindings.pressed("down")),float(game.bindings.pressed("back"))-float(game.bindings.pressed("forward")))
			camera.position+=camera.basis*input_dir.limit_length(1)*delta*6
			camera.rotation=Vector3(free_rotation.y,free_rotation.x,0)
	else:
		camera.global_transform=aim
		if viewpoint=="chase":
			var target:=aim.origin+aim.basis.z*3+Vector3.UP*.65
			var hit: Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(aim.origin,target,1))
			camera.global_position=hit.position+hit.normal*.15 if not hit.is_empty() else target
			camera.look_at(aim.origin-aim.basis.z*2)
	if s.weapon!=gun_id:
		if is_instance_valid(gun):gun.free()
		gun=game.Art.weapon(s.weapon);game.add_child(gun);gun_id=s.weapon
	gun.visible=viewpoint=="first" and not s.dead and not game.lobby.active()
	var held: Transform3D=actor.global_transform*s.xr.weapon if not s.xr.is_empty() else Transform3D(aim.basis,aim.origin+aim.basis*Vector3(.18,-.24,-.35))
	gun.global_transform=game.Art.held_transform(held,s.weapon)
func _unhandled_input(event: InputEvent) -> void:
	if not playing:return
	if event is InputEventMouseMotion and viewpoint=="free" and not game.menu_open:
		free_rotation.x-=event.relative.x*.0022;free_rotation.y=clampf(free_rotation.y-event.relative.y*.0022,-1.5,1.5)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:game.menu_open=not game.menu_open;game.hud.show_menu(game.menu_open);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if game.menu_open else Input.MOUSE_MODE_CAPTURED
			KEY_P:paused=not paused
			KEY_SPACE:
				if viewpoint!="free":paused=not paused
			KEY_TAB:next_player()
			KEY_C:viewpoint="chase" if viewpoint=="first" else "free" if viewpoint=="chase" else "first"
			KEY_LEFT:seek(position_seconds-5)
			KEY_RIGHT:seek(position_seconds+5)

func _exit_tree() -> void:
	stop_record()

func finish_movie() -> void:
	exit_at_end=false
	var tree:=get_tree()
	stop_playback();game.disconnect_game("Demo movie complete")
	game.set_physics_process(false);game.set_process(false)
	await tree.process_frame;await tree.process_frame
	tree.quit()
