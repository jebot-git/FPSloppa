extends Node3D
## Binaural Steam Audio processing; the listener follows the actual desktop/XR camera.
## Config/listener outlive map and player nodes so map rotation cannot leave a dangling listener.
var game
var config: Node3D
var listener: Node3D
var available:=false
func setup(arena: Node) -> void:
	game=arena
	if game.headless or not ClassDB.class_exists("SteamAudioPlayer"):return
	# Plugin 0.3.1 derives its DSP block size from these settings. Godot mixes 512 frames.
	# Match its allocation to that block, independent of the OS device's output latency.
	ProjectSettings.set_setting("audio/driver/mix_rate",int(AudioServer.get_mix_rate()))
	ProjectSettings.set_setting("audio/driver/output_latency",roundi(512000.0/AudioServer.get_mix_rate()))
	config=ClassDB.instantiate("SteamAudioConfig")
	config.set("scene_type",0) # Portable CPU path on Linux, Windows and standalone Android.
	config.set("global_log_level",2)
	config.set("max_ambisonics_order",1)
	config.set("max_reflection_sources",1);config.set("max_reflection_rays",32);config.set("reflection_threads",1)
	config.set("max_reflection_duration",.1)
	listener=ClassDB.instantiate("SteamAudioListener")
	listener.set("reflection_rays",32);listener.set("reflection_bounces",1);listener.set("reflection_duration",.1)
	add_child(listener);add_child(config)
	available=true;process_priority=-20;process_physics_priority=-20
func enabled() -> bool:return available and game.presentation.get("spatial_audio","steam_audio")=="steam_audio"
func create_player() -> AudioStreamPlayer3D:
	if not enabled():return AudioStreamPlayer3D.new()
	var player: AudioStreamPlayer3D=ClassDB.instantiate("SteamAudioPlayer")
	player.set("ambisonics",true);player.set("ambisonics_order",1)
	player.set("distance_attenuation",true)
	# Gameplay's ray-tested muffling includes moving doors and lifts. No second occlusion pass.
	player.set("occlusion",false);player.set("reflection",false)
	return player
func _process(_delta: float) -> void:sync_listener()
func _physics_process(_delta: float) -> void:sync_listener()
func sync_listener() -> void:
	if not available:return
	var camera: Camera3D=game.camera if is_instance_valid(game.camera) else game.get_node("Overview")
	listener.global_transform=camera.global_transform
