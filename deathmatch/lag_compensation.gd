extends RefCounted
# Server-owned history; clients may request only a bounded, measured-latency window.
const MAX_REWIND:=.30
const VIEW_ALLOWANCE:=.12
static func delay(clock: float,ping_ms: int,view_time: float,received: float) -> float:
	var bound:=minf(MAX_REWIND,maxi(0,ping_ms)/1000.0+VIEW_ALLOWANCE)
	if not is_finite(view_time) or view_time<0 or view_time>received:return minf(bound,maxi(0,ping_ms)/1000.0+.075)
	return clampf(clock-view_time,0,bound)
static func positions(history: Array,now: float,rewind: float,current: Dictionary) -> Dictionary:
	if rewind<=0 or history.is_empty():return {}
	var at:=now-clampf(rewind,0,MAX_REWIND)
	var before: Dictionary=history[0]
	var after: Dictionary={"time":now,"positions":current}
	for sample in history:
		if sample.time<=at:before=sample
		else:after=sample;break
	var weight:=clampf((at-before.time)/maxf(after.time-before.time,.000001),0,1)
	var result: Dictionary={}
	for id in current:
		var a: Dictionary=before.positions.get(id,{})
		var b: Dictionary=after.positions.get(id,{})
		# Never rewind into another life or interpolate across a teleport.
		if a.get("serial",-1)!=current[id].serial or b.get("serial",-1)!=current[id].serial:continue
		if a.position.distance_to(b.position)>3.0:continue
		result[id]=a.position.lerp(b.position,weight)
	return result
