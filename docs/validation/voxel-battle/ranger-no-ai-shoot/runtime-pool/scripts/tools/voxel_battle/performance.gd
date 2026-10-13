extends RefCounted
## Sample active rendered match frames, including streaming and live-feed overhead.
var series: Dictionary={}
var views: Dictionary={}
var csv: FileAccess
var started_usec:=0
var samples:=0
var captures: Array=[]
var measured_viewports: Array[RID]=[]
func setup(output: String,viewport: RID) -> void:
	RenderingServer.viewport_set_measure_render_time(viewport,true)
	for eye in measured_viewports:RenderingServer.viewport_set_measure_render_time(eye,true)
	csv=FileAccess.open(output+"/frames.csv",FileAccess.WRITE)
	csv.store_csv_line(PackedStringArray(["simulation_seconds","view","stream_settled","frame_ms","viewport_gpu_ms","render_cpu_ms","draw_calls","primitives","static_memory_mb","video_memory_mb","terrain_tiles","environment_draws","environment_update_ms"]))
	started_usec=Time.get_ticks_usec()
static func summary(values: Array) -> Dictionary:
	if values.is_empty():return {}
	var sorted:=values.duplicate();sorted.sort()
	return {"samples":sorted.size(),"p50":sorted[sorted.size()/2],"p95":sorted[int(sorted.size()*.95)],"p99":sorted[int(sorted.size()*.99)],"max":sorted[-1]}
func record(delta: float,viewport: RID,map,seconds: float,label: String) -> void:
	var settled: bool=map.terrain.settled()
	var values:={"frame_ms":delta*1000,"viewport_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(viewport),"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(viewport),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"static_memory_mb":OS.get_static_memory_usage()/1048576.0,"video_memory_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"terrain_tiles":map.terrain.resident.size(),"environment_draws":map.environment.draw_calls,"environment_update_ms":map.environment.update_ms}
	if not measured_viewports.is_empty():
		values.viewport_gpu_ms=0.0;values.render_cpu_ms=0.0
		for eye in measured_viewports:
			values.viewport_gpu_ms+=RenderingServer.viewport_get_measured_render_time_gpu(eye)
			values.render_cpu_ms+=RenderingServer.viewport_get_measured_render_time_cpu(eye)
	if not views.has(label):views[label]={"frames":0,"settled_frames":0,"frame_ms":[],"viewport_gpu_ms":[],"draw_calls":[]}
	views[label].frames+=1
	if settled:views[label].settled_frames+=1
	for key in values:
		if not series.has(key):series[key]=[]
		series[key].append(values[key])
	for key in ["frame_ms","viewport_gpu_ms","draw_calls"]:views[label][key].append(values[key])
	var row:=PackedStringArray([str(seconds),label,str(settled)])
	for key in values:row.append(str(values[key]))
	csv.store_csv_line(row);samples+=1
	if samples%120==0:csv.flush()
func result() -> Dictionary:
	if csv:csv.flush()
	var result:={"samples":samples,"wall_seconds":(Time.get_ticks_usec()-started_usec)/1000000.0,"units":"milliseconds, MB, counts","frames_over_16_67ms_percent":0.0,"by_view":{},"live_readback_encode_ms":summary(captures)}
	for key in series:result[key]=summary(series[key])
	if series.has("frame_ms"):
		var over:=0
		for value in series.frame_ms:
			if value>1000.0/60:over+=1
		result.frames_over_16_67ms_percent=float(over)*100/series.frame_ms.size()
	for label in views:
		var row: Dictionary=views[label].duplicate()
		for key in ["frame_ms","viewport_gpu_ms","draw_calls"]:row[key]=summary(row[key])
		result.by_view[label]=row
	return result
