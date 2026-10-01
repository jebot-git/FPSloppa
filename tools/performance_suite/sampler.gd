extends Node
signal finished
const Metrics=preload("res://deathmatch/avatars/animation_metrics.gd")
const Events=preload("res://tools/performance_suite/events.gd")
var game
var config: Dictionary
var frames: Array=[]
var metadata: Dictionary
var output: FileAccess
var pending: PackedStringArray=[]
var trackers: Dictionary={}
var started:=0
var previous:=0
var next_pose:=0
var next_inventory:=0
var next_flush:=0
var done:=false
var capturing:=false
var capture_count:=0
var capture_us:=0
var max_capture_us:=0
var previous_capture_us:=0
var pose_interval:=33333
func _ready() -> void:
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	started=Time.get_ticks_usec();previous=started;next_flush=started+1000000
	var xr=XRServer.find_interface("OpenXR")
	var refresh: float=xr.get_display_refresh_rate() if game.is_vr() else config.refresh_hz
	metadata={"schema":1,"config":config,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"viewport":str(get_viewport().size),"xr":game.is_vr(),"refresh_hz":refresh,"budget_hz":config.refresh_hz,"render_size":str(xr.get_render_target_size()) if game.is_vr() else str(get_viewport().size),"presentation":game.presentation.duplicate(true),"utc_start":Time.get_unix_time_from_system(),"ticks_start_us":started,"haptics":game.haptics.values.duplicate(true) if game.haptics else {},"compositor":"not captured by Godot; requires separate runtime trace","gpu_alignment":"latest available viewport query; delayed, not guaranteed to match event frame","scope_units":"inclusive microseconds and call count; nested scopes must not be summed"}
	metadata["map"]=game.current_map
	metadata["msaa"]=get_viewport().msaa_3d
	metadata["scale3d"]=get_viewport().scaling_3d_scale
	if game.is_vr():metadata["tracking"]={"enabled":game.xr_rig.tracking.enabled,"status":game.xr_rig.tracking.status}
	metadata["avatar_hashes"]=[]
	for actor in game.fighters.values():metadata.avatar_hashes.append(actor.avatar_hash)
	output=FileAccess.open(config.output.path_join("poses.jsonl"),FileAccess.WRITE)
	if not output:push_error("Cannot open telemetry output");get_tree().quit(2)
func inventory() -> void:
	trackers=XRServer.get_trackers(XRServer.TRACKER_ANY)
	var info: Dictionary={}
	for key in trackers:info[str(key)]={"class":trackers[key].get_class(),"description":trackers[key].get_tracker_desc()}
	metadata["tracker_inventory"]=info
func pose_snapshot() -> Dictionary:
	var data:={"ticks_us":Time.get_ticks_usec(),"trackers":{}}
	for key in trackers:
		var tracker=trackers[key];var row: Dictionary={}
		if tracker is XRPositionalTracker:
			for name_here in ["default","grip","aim","tracker_pose"]:
				if tracker.has_pose(name_here):
					var p=tracker.get_pose(name_here)
					row[name_here]={"tracked":p.has_tracking_data,"confidence":p.tracking_confidence,"pose":var_to_str(p.get_adjusted_transform())}
		if tracker is XRBodyTracker:
			row["active"]=tracker.has_tracking_data;row["joints"]=[]
			for joint in XRBodyTracker.JOINT_MAX:row.joints.append([tracker.get_joint_flags(joint),var_to_str(tracker.get_joint_transform(joint))])
		if tracker is XRHandTracker:
			row["active"]=tracker.has_tracking_data;row["source"]=tracker.hand_tracking_source;row["joints"]=[]
			for joint in XRHandTracker.HAND_JOINT_MAX:row.joints.append([tracker.get_hand_joint_flags(joint),var_to_str(tracker.get_hand_joint_transform(joint))])
		data.trackers[str(key)]=row
	if not game.is_vr():
		# Identical synthetic pose payload for desktop capture comparisons.
		data["synthetic"]=[]
		for actor in game.fighters.values():
			if actor.avatar and actor.avatar.get("target_xr_pose")!=null:data.synthetic.append(var_to_str(actor.avatar.target_xr_pose))
	if game.haptics:
		data["haptic_effect"]=game.haptics.last_effect
		if game.haptics.native_output and game.haptics.native_output.bridge:data["ble"]=JSON.parse_string(game.haptics.native_output.bridge.diagnostics_json())
	return data
func _process(_delta: float) -> void:
	if done:return
	var now:=Time.get_ticks_usec();var interval:=(now-previous)/1000.0;previous=now
	if game.quitting:finish(false);return
	if now-started<config.warmup*1000000:Metrics.reset();return
	if not capturing:
		capturing=true;Events.rows.clear();Events.enabled=true;Metrics.reset()
		metadata["measurement_start_us"]=now
		# First interval crosses warmup; omit it.
		return
	var state: Dictionary=game.local_state()
	var rid:=get_viewport().get_viewport_rid()
	var row:={"ticks_us":now,"frame":Engine.get_process_frames(),"frame_ms":interval,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(rid),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(rid),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"active":game.active,"menu":game.menu_open,"weapon":state.get("weapon",-1),"rules":game.armory.effective(),"previous_capture_ms":previous_capture_us/1000.0}
	if game.is_vr():row["focused"]=game.xr_rig.focused
	if Metrics.enabled:row["scopes"]=Metrics.samples.duplicate(true);Metrics.reset()
	frames.append(row)
	if frames.size()>=250000:push_warning("Frame memory limit reached; capture is incomplete");finish(false);return
	previous_capture_us=0
	if config.capture!="none" and now>=next_pose:
		var begin:=Time.get_ticks_usec();next_pose=now+pose_interval
		if config.capture=="immediate" or now>=next_inventory:inventory();next_inventory=now+1000000
		var pose:=pose_snapshot()
		if config.capture=="immediate":
			pose["inventory"]=metadata.get("tracker_inventory",{})
			pose["presentation"]=game.presentation.duplicate(true)
		var line:=JSON.stringify(pose)
		if config.capture=="immediate":
			output.store_line(line);output.flush()
			var status:=FileAccess.open(config.output.path_join("status.json"),FileAccess.WRITE)
			status.store_string(line);status.close()
		else:pending.append(line)
		previous_capture_us=Time.get_ticks_usec()-begin;capture_count+=1
	if now>=next_flush:
		var begin:=Time.get_ticks_usec();flush_poses();next_flush=now+1000000
		previous_capture_us+=Time.get_ticks_usec()-begin
	capture_us+=previous_capture_us;max_capture_us=maxi(max_capture_us,previous_capture_us)
	if now-int(metadata.measurement_start_us)>=config.seconds*1000000:finish(true)
func flush_poses() -> void:
	if not pending.is_empty():output.store_string("\n".join(pending)+"\n");pending.clear();output.flush()
func finish(complete: bool) -> void:
	if done:return
	var measurement_end:=Time.get_ticks_usec()
	done=true;Events.enabled=false;Metrics.enabled=false
	flush_poses();output.close()
	var file:=FileAccess.open(config.output.path_join("frames.jsonl"),FileAccess.WRITE)
	for row in frames:file.store_line(JSON.stringify(row))
	file.close();file=FileAccess.open(config.output.path_join("events.jsonl"),FileAccess.WRITE)
	for row in Events.rows:file.store_line(JSON.stringify(row))
	file.close()
	metadata.merge({"complete":complete,"frames":frames.size(),"measurement_end_us":measurement_end,"capture_samples":capture_count,"capture_total_ms":capture_us/1000.0,"capture_max_ms":max_capture_us/1000.0},true)
	file=FileAccess.open(config.output.path_join("metadata.json"),FileAccess.WRITE);file.store_string(JSON.stringify(metadata,"  "));file.close()
	print("PERFORMANCE_SUITE_DONE ",config.output)
	finished.emit()
	game.request_quit()
