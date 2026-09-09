extends Node3D
## Shared bounded spatial mixer. Occlusion is a cosmetic static-world ray test.
var game
var active: Array=[]
var cache: Dictionary={}
var tick:=0.0
var room_tick:=0.0
var reverb: AudioEffectReverb
var own_bus:=false
func setup(arena: Node) -> void:
	game=arena
	if game.headless: return
	if AudioServer.get_bus_index("ArenaSpatial")<0:
		own_bus=true
		AudioServer.add_bus()
		var idx:=AudioServer.bus_count-1
		AudioServer.set_bus_name(idx,"ArenaSpatial")
		reverb=AudioEffectReverb.new()
		reverb.predelay_msec=18
		reverb.wet=.08; reverb.dry=1; reverb.room_size=.55; reverb.damping=.7
		AudioServer.add_bus_effect(idx,reverb)
func choose(kind: String) -> AudioStream:
	var file:="res://deathmatch/audio/"+kind+".wav"
	if kind in ["weapon_2","weapon_5"]: file="res://deathmatch/audio/recorded/"+kind+"_"+str(randi_range(0,3))+".wav"
	elif kind in ["weapon_3","weapon_4"]: file="res://deathmatch/audio/recorded/"+kind+"_0.wav"
	elif kind in ["step","land","flesh","weapon_0","impact"]:
		var stem:="footstep_concrete" if kind in ["step","land"] else "impactMetal_light" if kind=="impact" else "impactPunch_heavy"
		file="res://deathmatch/audio/recorded/%s_%03d.ogg"%[stem,randi_range(0,4)]
	if not cache.has(file): cache[file]=load(file)
	return cache[file]
func configure(player: AudioStreamPlayer3D, voice: bool=false) -> void:
	player.bus="ArenaSpatial"
	player.panning_strength=1.4
	player.unit_size=3 if voice else 5
	player.max_distance=45 if voice else 80
	player.attenuation_model=AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.attenuation_filter_db=-18
	player.attenuation_filter_cutoff_hz=18000
	player.max_db=0
func play(kind: String,where: Vector3,volume: float=-8) -> void:
	if game.headless: return
	active=active.filter(is_instance_valid)
	if active.size()>=32:
		active.pop_front().queue_free()
	var player:=AudioStreamPlayer3D.new()
	configure(player)
	player.stream=choose(kind)
	player.volume_db=volume
	player.set_meta("dry_db",volume)
	player.pitch_scale=randf_range(.97,1.03)
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
		for player in active: update_source(player,float(player.get_meta("dry_db",-8)))
	if room_tick>.5 and reverb:
		room_tick=0
		var count:=0
		var pos: Vector3=game.camera.global_position
		for dir in [Vector3.UP,Vector3.LEFT,Vector3.RIGHT,Vector3.FORWARD,Vector3.BACK]:
			if occluded(pos,pos+dir*12): count+=1
		reverb.wet=lerpf(reverb.wet,.04+count*.032,.35)
func clear() -> void:
	for player in active:
		if is_instance_valid(player): player.queue_free()
	active.clear()
func _exit_tree() -> void:
	if own_bus:
		var idx:=AudioServer.get_bus_index("ArenaSpatial")
		if idx>=0: AudioServer.remove_bus(idx)
