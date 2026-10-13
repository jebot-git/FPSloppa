extends RefCounted
static var enabled:=false
static var totals: Dictionary={}
static var frame: Dictionary={}
static var frames: Dictionary={}
static func begin() -> int:return Time.get_ticks_usec() if enabled else 0
static func end(label: String,start: int) -> void:
	if not enabled or start==0:return
	var usec:=Time.get_ticks_usec()-start
	if not totals.has(label):totals[label]={"usec":0,"calls":0,"max_usec":0}
	totals[label].usec+=usec;totals[label].calls+=1;totals[label].max_usec=maxi(totals[label].max_usec,usec)
	frame[label]=frame.get(label,0)+usec
static func commit() -> void:
	for label in totals:
		if not frames.has(label):frames[label]=[]
		frames[label].append(frame.get(label,0)/1000.0)
	frame.clear()
static func result() -> Dictionary:
	var rows: Dictionary={}
	for label in totals:
		var row: Dictionary=totals[label].duplicate();row.total_ms=row.usec/1000.0;row.mean_call_ms=row.total_ms/row.calls
		row.per_render_frame_ms=preload("res://tools/voxel_battle/performance.gd").summary(frames.get(label,[]));rows[label]=row
	return rows
