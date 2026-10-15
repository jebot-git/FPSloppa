extends SceneTree
## Explicit live-test telemetry. No raw microphone, controller or tracking data.
var game
var output:FileAccess
var elapsed:=0.0
func _initialize()->void:call_deferred("start")
func start()->void:
	var args:=OS.get_cmdline_user_args()
	var path:="user://cq-live-client.jsonl"
	var index:=args.find("--analytics-output")
	if index>=0 and index+1<args.size():path=args[index+1]
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	output=FileAccess.open(path,FileAccess.WRITE)
	if output==null:push_error("Cannot open live analytics: "+path);quit(2);return
	game=load("res://tools/voxel_battle/class_arena.tscn").instantiate();root.add_child(game);current_scene=game
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
	output.store_line(JSON.stringify(row));output.flush()
func _finalize()->void:
	if output:output.flush();output.close()
