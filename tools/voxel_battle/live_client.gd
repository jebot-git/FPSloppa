extends SceneTree
## Explicit live-test telemetry. No raw microphone, controller or tracking data.
var game
var output:FileAccess
var elapsed:=0.0
func _initialize()->void:call_deferred("start")
func arena_scene()->PackedScene:return load("res://tools/voxel_battle/class_arena.tscn")
func start()->void:
	var args:=OS.get_cmdline_user_args()
	var path:="user://cq-live-client.jsonl"
	var index:=args.find("--analytics-output")
	if index>=0 and index+1<args.size():path=args[index+1]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	output=FileAccess.open(path,FileAccess.WRITE)
	if output==null:push_error("Cannot open live analytics: "+path);quit(2);return
	game=arena_scene().instantiate();root.add_child(game);current_scene=game
	process_frame.connect(sample)
	print("CQ_LIVE_ANALYTICS ",path)
func sample()->void:
	elapsed+=root.get_process_delta_time()
	if elapsed<1.0:return
	elapsed=0
	var id:int=game.multiplayer.get_unique_id()
	var player:Dictionary=game.players.get(id,{})
	var row:={"utc":Time.get_datetime_string_from_system(true),"ms":Time.get_ticks_msec(),"active":game.active,"map_loading":game.map_loading,"menu":game.menu_open,"xr":game.is_vr(),"fps":Engine.get_frames_per_second(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"static_memory":Performance.get_monitor(Performance.MEMORY_STATIC),"players":game.players.size(),"hp":player.get("hp",0),"armor":player.get("armor",0),"dead":player.get("dead",false),"squad":player.get("squad",-1),"class":game.classes.role(id),"voice_sent":game.voice.sequence,"voice_received":game.voice.received_packets}
	if game.xr_rig:row["focused"]=game.xr_rig.focused
	if not game.weather.state.is_empty():
		var weather_values:Vector4=game.weather.state.values
		row["weather"]={"mode":game.weather.state.mode,"rain":weather_values.y,"fog":weather_values.x,"rain_reduced":game.weather.reduced}
	var viewport:Viewport=game.get_viewport()
	var xr=XRServer.find_interface("OpenXR")
	row["render"]={"requested_scale":game.presentation.render_scale,"scale_3d":viewport.scaling_3d_scale,"vrs_mode":viewport.vrs_mode,"viewport_size":str(viewport.get_visible_rect().size),"msaa":viewport.msaa_3d,"screen_space_aa":viewport.screen_space_aa,"nvg":game.night_vision.enabled_for(id)}
	if xr and xr.is_initialized():
		row.render.merge({"target_size":str(xr.get_render_target_size()),"target_multiplier":xr.render_target_size_multiplier,"foveation_mode":preload("res://deathmatch/vr/foveation.gd").mode(xr,game.presentation.get("foveation_dynamic",true)),"foveation_level":xr.foveation_level,"foveation_dynamic":xr.foveation_dynamic,"vrs_radius":xr.vrs_min_radius,"vrs_strength":xr.vrs_strength})
		row.render["session_state"]=xr.get_session_state()
		var gaze=XRServer.get_tracker("/user/eyes_ext")
		var pose=gaze.get_pose("eye_gaze_pose") if gaze and gaze.has_pose("eye_gaze_pose") else null
		row.render["gaze_tracked"]=pose!=null and pose.has_tracking_data
	output.store_line(JSON.stringify(row));output.flush()
func _finalize()->void:
	if output:output.flush();output.close()
