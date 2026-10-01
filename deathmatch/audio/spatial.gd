extends Node3D
const WeaponLevels = preload("res://deathmatch/audio/weapon_levels.gd")
const ModeSounds = preload("res://deathmatch/audio/modes/catalog.gd")
const ActionSounds = preload("res://deathmatch/audio/weapon-actions/catalog.gd")
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
var bank_cursor: Dictionary={}
var ambience
var actions
var enclosure:=0.0
var effects_limiter: AudioEffectHardLimiter
func setup(arena: Node) -> void:
	game=arena
	if game.headless: return
	prewarm()
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
	# Normalized reports can overlap. Limit only the effects sum, with room for
	# the downstream room reverb; user music/voice levels remain independent.
	var effects_index:=AudioServer.get_bus_index("ArenaEffects")
	for effect in AudioServer.get_bus_effect_count(effects_index):
		if AudioServer.get_bus_effect(effects_index,effect) is AudioEffectHardLimiter:effects_limiter=AudioServer.get_bus_effect(effects_index,effect)
	if not effects_limiter:
		effects_limiter=AudioEffectHardLimiter.new();effects_limiter.ceiling_db=-3;effects_limiter.pre_gain_db=0;effects_limiter.release=.06
		AudioServer.add_bus_effect(effects_index,effects_limiter)
	ambience=preload("res://deathmatch/audio/ambience.gd").new();add_child(ambience);ambience.setup(game,self)
	actions=preload("res://deathmatch/audio/weapon-actions/player.gd").new();add_child(actions);actions.setup(game,self)
func prewarm() -> void:
	# Bounded built-in combat sounds, prepared before the arena accepts input.
	# Enumerate random variants directly: warming must not advance gameplay RNG.
	for kind in ["hit_confirm","impact_energy","impact_heavy","impact_dust"]:
		if not cache.has(kind):cache[kind]=preload("res://deathmatch/audio/impact_sounds.gd").make(kind)
	var paths: Array[String]=[]
	for kind in ["death","gib","spawn","teleport","ui","pickup"]:paths.append("res://deathmatch/audio/"+kind+".wav")
	paths.append("res://deathmatch/audio/flamethrower.res")
	for kind in ["explosion","pickup_ammo","pickup_weapon","pickup_armor","pickup_health","pickup_mega"]:paths.append("res://deathmatch/audio/doom-style/"+kind+".wav")
	for slot in range(1,9):paths.append("res://deathmatch/audio/doom-style/weapon_%d.wav"%slot)
	for variant in 3:
		paths.append("res://deathmatch/audio/recorded/pain_%d.wav"%variant)
		paths.append("res://deathmatch/audio/ba2/stomp_%d.res"%variant)
		for kind in ["jump","land"]:paths.append("res://deathmatch/audio/doom-style/%s_%d.wav"%[kind,variant])
	for stem in ["footstep_concrete","impactMetal_light","impactPunch_heavy"]:
		for variant in 5:paths.append("res://deathmatch/audio/recorded/%s_%03d.ogg"%[stem,variant])
	for kind in ["snip","mag_out","mag_in","rack_back","rack_close","empty_lock"]:paths.append("res://deathmatch/audio/cs16/"+kind+".res")
	for rules in ["quake","ut99"]:
		for slot in 12:
			for suffix in ["","_alt"]:paths.append("res://deathmatch/audio/experimental/%s_weapon_%d%s.wav"%[rules,slot,suffix])
		for kind in ["bounce","explosion","combo"]:paths.append("res://deathmatch/audio/experimental/%s_%s.wav"%[rules,kind])
	for slot in 12:paths.append("res://deathmatch/audio/tribes/weapon_%d.res"%slot)
	for kind in ["bounce","explosion"]:paths.append("res://deathmatch/audio/tribes/"+kind+".res")
	for path in paths:
		if not cache.has(path) and ResourceLoader.exists(path):cache[path]=load(path)
	for variants in ModeSounds.SOUNDS.values():
		for path in variants:
			if not cache.has(path):cache[path]=load(path)
	for entry in ActionSounds.SOUNDS.values():
		if not cache.has(entry.path):cache[entry.path]=load(entry.path)
func choose(kind: String) -> AudioStream:
	if kind.begins_with("action_"):
		var entry:Dictionary=ActionSounds.SOUNDS.get(kind.trim_prefix("action_"),{})
		if entry.is_empty():return null
		if not cache.has(entry.path):cache[entry.path]=load(entry.path)
		return cache[entry.path]
	if ModeSounds.SOUNDS.has(kind):
		var variants: Array=ModeSounds.SOUNDS[kind]
		var index: int=bank_cursor.get(kind,0)%variants.size()
		bank_cursor[kind]=index+1
		var path: String=variants[index]
		if not cache.has(path):cache[path]=load(path) # Explicit offline/test callers may skip setup.
		return cache[path]
	if kind in ["hit_confirm","impact_energy","impact_heavy","impact_dust"]:
		if not cache.has(kind):cache[kind]=preload("res://deathmatch/audio/impact_sounds.gd").make(kind)
		return cache[kind]
	var file:="res://deathmatch/audio/"+kind+".wav"
	if kind.begins_with("tribes_") and not "/" in kind and not "." in kind:file="res://deathmatch/audio/tribes/"+kind.trim_prefix("tribes_").trim_suffix("_alt")+".res"
	elif kind.begins_with("cs_reload_") and kind.trim_prefix("cs_reload_") in ["mag_out","mag_in","rack_back","rack_close","empty_lock"]:
		file="res://deathmatch/audio/cs16/"+kind.trim_prefix("cs_reload_")+".res"
	elif kind=="de_snip":file="res://deathmatch/audio/cs16/snip.res"
	elif kind.begins_with("cs16_weapon_"):
		var slot:=kind.trim_prefix("cs16_weapon_").trim_suffix("_alt").to_int()
		file="res://deathmatch/audio/doom-style/weapon_%d.wav"%([2,2,2,3,3,5,5,5,5,3,2,5][clampi(slot,0,11)])
	elif kind=="flamethrower":file="res://deathmatch/audio/flamethrower.res"
	elif kind=="ba2_stomp":file="res://deathmatch/audio/ba2/stomp_%d.res"%randi_range(0,2)
	elif kind.begins_with("quake_") or kind.begins_with("ut99_"):
		if kind.contains("/") or kind.contains(".") or kind.length()>32:return null
		file="res://deathmatch/audio/experimental/"+kind+".wav"
	elif kind in ["jump","land"]:file="res://deathmatch/audio/doom-style/"+kind+"_%d.wav"%randi_range(0,2)
	elif kind in ["weapon_1","weapon_2","weapon_3","weapon_4","weapon_5","weapon_6","weapon_7","weapon_8","explosion","pickup_ammo","pickup_weapon","pickup_armor","pickup_health","pickup_mega"]:file="res://deathmatch/audio/doom-style/"+kind+".wav"
	elif kind=="pain":file="res://deathmatch/audio/recorded/pain_%d.wav"%randi_range(0,2)
	elif kind in ["step","flesh","weapon_0","impact"]:
		var stem:="footstep_concrete" if kind=="step" else "impactMetal_light" if kind=="impact" else "impactPunch_heavy"
		file="res://deathmatch/audio/recorded/%s_%03d.ogg"%[stem,randi_range(0,4)]
	# Exported WAVs live behind Godot's import remaps, not as loose source files.
	if not cache.has(file):cache[file]=load(file) if ResourceLoader.exists(file) else null
	return cache[file]
func configure(player: AudioStreamPlayer3D, voice: bool=false) -> void:
	# SteamAudioPlayer inherits Godot's Doppler pitch calculation; its stream
	# wrapper forwards that playback rate into the HRTF mixer.
	player.doppler_tracking=AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
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
	var source:=choose(kind)
	if source==null:return
	var weapon_report:=kind.begins_with("weapon_") or kind.contains("_weapon_") or kind=="flamethrower"
	if ambience and (weapon_report or kind.ends_with("explosion") or kind=="ut99_combo") and is_instance_valid(game.camera) and where.distance_squared_to(game.camera.global_position)<900:
		ambience.combat_pulse()
	active=active.filter(is_instance_valid)
	if active.size()>=32:
		active.pop_front().queue_free()
	var player: AudioStreamPlayer3D=create_player()
	configure(player)
	player.stream=source
	volume+=WeaponLevels.gain_db(kind,source.resource_path)
	# Permit calibrated positive gains on quiet sources at the reference distance.
	player.max_db=maxf(0,volume)
	player.volume_db=volume
	player.set_meta("dry_db",volume)
	player.set_meta("expires",game.clock+source.get_length()/.97+.15)
	player.pitch_scale=randf_range(.985,1.015) if weapon_report else randf_range(.97,1.03)
	if kind=="ba2_stomp":
		player.max_distance=100;player.unit_size=8
		if player.has_method("play_stream"):player.set("min_attenuation_distance",player.unit_size)
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
func _process(_delta: float) -> void:
	# Also track the camera when the native plugin is unavailable or disabled.
	if game and is_instance_valid(game.camera) and game.camera.doppler_tracking!=Camera3D.DOPPLER_TRACKING_IDLE_STEP:
		game.camera.doppler_tracking=Camera3D.DOPPLER_TRACKING_IDLE_STEP
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
		enclosure=lerpf(enclosure,float(count)/5.0,.35)
		reverb.wet=lerpf(reverb.wet,.04+count*.032,.35)
func clear() -> void:
	if is_instance_valid(ambience):ambience.clear()
	if is_instance_valid(actions):actions.clear()
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
