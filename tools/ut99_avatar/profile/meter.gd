extends RefCounted
## Benchmark-only nested CPU scopes. Exclusive time subtracts recorded children.
const Probe=preload("res://tools/voxel_battle/performance.gd")
const LABELS=["benchmark_tick","gameplay_tick","server_tick","movement_collision","combat_input","hit_trace","shot_solution","impact_dispatch","shot_fx_dispatch","history","snapshot","projectiles","melee","pickup_collection","game_scene_update","fighter_visual_update","avatar_update","tracked_head_neck_arms_ik","effects_update","effects_spawn","effects_pool_acquire","effects_impacts"]
static var enabled:=false
static var stack:Array=[]
static var totals:Dictionary={}
static var frame:Dictionary={}
static var series:Dictionary={}
static var walls:Array=[]
static var last_wall:=0
static var csv:FileAccess
static func reset(output:String) -> void:
	stack.clear();totals.clear();frame.clear();series.clear();walls.clear()
	for label in LABELS:
		totals[label]={"calls":0,"inclusive_ms":0.0,"exclusive_ms":0.0}
		series[label]={"inclusive_ms":[],"exclusive_ms":[]}
	csv=FileAccess.open(output+"/categories.csv",FileAccess.WRITE)
	var header:=PackedStringArray(["wall_frame_ms","simulation_seconds"])
	for label in LABELS:header.append(label+"_inclusive_ms");header.append(label+"_exclusive_ms")
	csv.store_csv_line(header);last_wall=Time.get_ticks_usec();enabled=true
static func begin(label:String) -> int:
	if not enabled:return 0
	var start:=Time.get_ticks_usec();stack.append({"label":label,"start":start,"children":0});return start
static func add(label:String,usec:int,exclusive:int) -> void:
	totals[label].calls+=1;totals[label].inclusive_ms+=usec/1000.0;totals[label].exclusive_ms+=exclusive/1000.0
	if not frame.has(label):frame[label]=Vector2.ZERO
	frame[label]+=Vector2(usec,exclusive)/1000.0
static func end(label:String,start:int) -> void:
	if start==0:return
	var duration:=Time.get_ticks_usec()-start;var scope:Dictionary=stack.pop_back();assert(scope.label==label)
	add(label,duration,maxi(0,duration-int(scope.children)))
	if not stack.is_empty():stack[-1].children+=duration
static func leaf(label:String,usec:int) -> void:
	if not enabled:return
	add(label,usec,usec)
	if not stack.is_empty():stack[-1].children+=usec
static func commit(seconds:float) -> void:
	if not enabled:return
	assert(stack.is_empty())
	var now:=Time.get_ticks_usec();var wall:float=(now-last_wall)/1000.0;last_wall=now;walls.append(wall)
	var row:=PackedStringArray([str(wall),str(seconds)])
	for label in LABELS:
		var value:Vector2=frame.get(label,Vector2.ZERO)
		series[label].inclusive_ms.append(value.x);series[label].exclusive_ms.append(value.y)
		row.append(str(value.x));row.append(str(value.y))
	csv.store_csv_line(row);frame.clear()
	if walls.size()%120==0:csv.flush()
static func result() -> Dictionary:
	if csv:csv.flush()
	var categories:Dictionary={}
	for label in LABELS:
		categories[label]=totals[label].duplicate()
		categories[label].inclusive_ms_per_render=Probe.summary(series[label].inclusive_ms)
		categories[label].exclusive_ms_per_render=Probe.summary(series[label].exclusive_ms)
	return {"frames":walls.size(),"wall_frame_ms":Probe.summary(walls),"wall_render_fps":1000.0/(walls.reduce(func(a,b):return a+b,0.0)/maxi(1,walls.size())),"categories":categories,"partial_frame_cpu_ms":frame,"scope":"CPU timings use nested benchmark-only wrappers; exclusive values subtract recorded child scopes. Unwrapped engine/scene work remains unmeasured. GPU counters overlap CPU. Wall intervals sampled at frame_post_draw; warmup excluded. Profiler adds clock/counter and CSV overhead."}
