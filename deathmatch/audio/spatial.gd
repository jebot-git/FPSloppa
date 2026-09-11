extends Node3D
const WeaponLevels = preload("res://deathmatch/audio/weapon_levels.gd")
## Shared bounded spatial mixer. Occlusion is a cosmetic static-world ray test.
var game
var steam
var active: Array=[]
var cache: Dictionary={}
var tick:=0.0
var room_tick:=0.0
var reverb: AudioEffectReverb
var own_bus:=false
var effects_bus_owned:=false
func setup(arena: Node) -> void:
	game=arena
	if game.headless: return
	steam=preload("res://deathmatch/audio/steam_backend.gd").new();add_child(steam);steam.setup(game)
	if AudioServer.get_bus_index("ArenaSpatial")<0:
		own_bus=true
		AudioServer.add_bus()
		var idx:=AudioServer.bus_count-1
		AudioServer.set_bus_name(idx,"ArenaSpatial")
		reverb=AudioEffectReverb.new()
		reverb.predelay_msec=18
		reverb.wet=.08; reverb.dry=1; reverb.room_size=.55; reverb.damping=.7
		AudioServer.add_bus_effect(idx,reverb)
	if AudioServer.get_bus_index("ArenaEffects")<0:
		effects_bus_owned=true;AudioServer.add_bus()
		var idx:=AudioServer.bus_count-1
		AudioServer.set_bus_name(idx,"ArenaEffects");AudioServer.set_bus_send(idx,"ArenaSpatial")
func choose(kind: String) -> AudioStream:
	var file:="res://deathmatch/audio/"+kind+".wav"
	if kind in ["jump","land"]:file="res://deathmatch/audio/doom-style/"+kind+"_%d.wav"%randi_range(0,2)
	elif kind in ["weapon_1","weapon_2","weapon_3","weapon_4","weapon_5","weapon_6","weapon_7","weapon_8","explosion","pickup_ammo","pickup_weapon","pickup_armor","pickup_health","pickup_mega"]:file="res://deathmatch/audio/doom-style/"+kind+".wav"
	elif kind=="pain":file="res://deathmatch/audio/recorded/pain_%d.wav"%randi_range(0,2)
	elif kind in ["step","flesh","weapon_0","impact"]:
		var stem:="footstep_concrete" if kind=="step" else "impactMetal_light" if kind=="impact" else "impactPunch_heavy"
		file="res://deathmatch/audio/recorded/%s_%03d.ogg"%[stem,randi_range(0,4)]
	if not cache.has(file): cache[file]=load(file)
	return cache[file]
func configure(player: AudioStreamPlayer3D, voice: bool=false) -> void:
	player.bus="ArenaSpatial" if voice else "ArenaEffects"
	player.panning_strength=0.0 if player.has_method("play_stream") else 1.4
	player.unit_size=3 if voice else 5
	player.max_distance=45 if voice else 80
	player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED if player.has_method("play_stream") else AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	if player.has_method("play_stream"):player.set("min_attenuation_distance",player.unit_size)
	player.attenuation_filter_db=-18
	player.attenuation_filter_cutoff_hz=18000
	player.max_db=0
func play(kind: String,where: Vector3,volume: float=-8) -> void:
	if game.headless or game.quitting: return
	active=active.filter(is_instance_valid)
	if active.size()>=32:
		active.pop_front().queue_free()
	var player: AudioStreamPlayer3D=create_player()
	configure(player)
	var source:=choose(kind)
	player.stream=source
	if kind.begins_with("weapon_"):
		volume += float(WeaponLevels.TRIM_DB.get(player.stream.resource_path.get_file(),0.0))
	player.volume_db=volume
	player.set_meta("dry_db",volume)
	player.set_meta("expires",game.clock+source.get_length()/.97+.15)
	player.pitch_scale=randf_range(.985,1.015) if kind.begins_with("weapon_") else randf_range(.97,1.03)
	if kind in ["jump","land"]:
		player.max_distance=28;player.unit_size=3.5
		if player.has_method("play_stream"):player.set("min_attenuation_distance",player.unit_size)
	add_child(player)
	player.global_position=where
	active.append(player)
	update_source(player,volume)
	player.finished.connect(player.queue_free)
	player.play()
func occluded(from: Vector3,to: Vector3) -> bool:
	if from.distance_squared_to(to)<.04: return false
	return not get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1)).is_empty()
func update_source(player: AudioStreamPlayer3D,dry_db: float) -> void:
	if not is_instance_valid(game.camera): return
	var blocked:=occluded(game.camera.global_position,player.global_position)
	player.volume_db=dry_db-10 if blocked else dry_db
	player.attenuation_filter_cutoff_hz=1800 if blocked else 18000
func _physics_process(delta: float) -> void:
	if not game or game.headless or not is_instance_valid(game.camera): return
	tick+=delta; room_tick+=delta
	if tick>.1:
		tick=0
		active=active.filter(is_instance_valid)
		for player in active:
			if game.clock>float(player.get_meta("expires",INF)):player.queue_free()
			else:update_source(player,float(player.get_meta("dry_db",-8)))
	if room_tick>.5 and reverb:
		room_tick=0
		var count:=0
		var pos: Vector3=game.camera.global_position
		for dir in [Vector3.UP,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			if occluded(pos,pos+dir*12): count+=1
		reverb.wet=lerpf(reverb.wet,.04+count*.032,.35)
func clear() -> void:
	for player in active:
		if is_instance_valid(player): player.stop();player.queue_free()
	active.clear()
func _exit_tree() -> void:
	if effects_bus_owned:
		var idx:=AudioServer.get_bus_index("ArenaEffects")
		if idx>=0:AudioServer.remove_bus(idx)
	if own_bus:
		var idx:=AudioServer.get_bus_index("ArenaSpatial")
		if idx>=0: AudioServer.remove_bus(idx)

func create_player() -> AudioStreamPlayer3D:
	return steam.create_player() if is_instance_valid(steam) else AudioStreamPlayer3D.new()
func apply_backend() -> void:
	clear()
	if game.voice:
		for id in game.voice.streams.keys():game.voice.remove_stream(id)
