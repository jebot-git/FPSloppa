extends RefCounted
## Remote bodies only. Local headset/controller poses never enter this buffer.
var tracks: Dictionary = {}
var server_time := -1.0
var arrived := 0.0
var jitter := 0.0
var render_time := -1.0
var delay := .075
func reset() -> void:
	tracks.clear(); server_time = -1; arrived = 0; jitter = 0; render_time = -1; delay = .075
func push(id: int, stamp: float, position: Vector3, velocity: Vector3, yaw: float, serial: int, now: float) -> void:
	if stamp < 0 or not is_finite(stamp): return
	if stamp > server_time:
		if server_time >= 0: jitter = lerpf(jitter,minf(.1,absf((now-arrived)-(stamp-server_time))),.1)
		server_time = stamp; arrived = now; delay = clampf(.075+jitter*2,.075,.15)
	var samples: Array = tracks.get(id,[])
	if not samples.is_empty():
		if stamp <= samples[-1].time: return
		if samples[-1].serial != serial or samples[-1].position.distance_to(position)>3.0: samples.clear()
	samples.append({"time":stamp,"position":position,"velocity":velocity,"yaw":yaw,"serial":serial})
	while samples.size() > 12: samples.pop_front()
	tracks[id] = samples
func advance(now: float) -> float:
	if server_time < 0: return -1
	var target := minf(server_time,server_time+maxf(0,now-arrived)-delay)
	render_time = maxf(render_time,target)
	return render_time
func sample(id: int) -> Dictionary:
	var samples: Array = tracks.get(id,[])
	if samples.is_empty(): return {}
	while samples.size()>2 and samples[1].time<render_time: samples.pop_front()
	if render_time <= samples[0].time: return samples[0]
	for i in range(1,samples.size()):
		if samples[i].time >= render_time:
			var a: Dictionary = samples[i-1]; var b: Dictionary = samples[i]
			var fraction: float = clampf((render_time-a.time)/maxf(.001,b.time-a.time),0,1)
			return {"position":a.position.lerp(b.position,fraction),"yaw":lerp_angle(a.yaw,b.yaw,fraction)}
	var last: Dictionary = samples[-1]
	# Hold at the latest known position rather than extrapolate through a wall.
	return last
