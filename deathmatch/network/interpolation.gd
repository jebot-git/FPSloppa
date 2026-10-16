extends RefCounted
## Remote bodies only. Local headset/controller poses never enter this buffer.
var native=_native()
static func _native():
	if OS.get_cmdline_user_args().has("--gdscript-interpolation") or not preload("res://deathmatch/native/runtime.gd").available("FPSRemoteInterpolation"):return null
	return ClassDB.instantiate("FPSRemoteInterpolation")
var tracks:Dictionary:
	get:return native.tracks() if native else _tracks
var server_time:float:
	get:return native.stats()["server_time"] if native else _server_time
var arrived:float:
	get:return native.stats()["arrived"] if native else _arrived
var jitter:float:
	get:return native.stats()["jitter"] if native else _jitter
var render_time:float:
	get:return native.stats()["render_time"] if native else _render_time
var delay:float:
	get:return native.stats()["delay"] if native else _delay
var last_advance:float:
	get:return native.stats()["last_advance"] if native else _last_advance
var underruns:int:
	get:return native.stats()["underruns"] if native else _underruns
var _tracks: Dictionary = {}
var _server_time := -1.0
var _arrived := 0.0
var _jitter := 0.0
var _render_time := -1.0
var _delay := .075
var _last_advance:=-1.0
var _underruns:=0
func reset() -> void:
	if native:native.reset();return
	_tracks.clear(); _server_time = -1; _arrived = 0; _jitter = 0; _render_time = -1; _delay = .075;_last_advance=-1.0;_underruns=0
func push(id: int, stamp: float, position: Vector3, velocity: Vector3, yaw: float, serial: int, now: float) -> void:
	if native:native.push(id,stamp,position,velocity,yaw,serial,now);return
	if stamp < 0 or not is_finite(stamp): return
	if stamp > _server_time:
		if _server_time >= 0: _jitter = lerpf(_jitter,minf(.1,absf((now-_arrived)-(stamp-_server_time))),.1)
		_server_time = stamp; _arrived = now; _delay = clampf(.075+_jitter*2,.075,.15)
	var samples: Array = _tracks.get(id,[])
	if not samples.is_empty():
		if stamp <= samples[-1].time: return
		if samples[-1].serial != serial or samples[-1].position.distance_to(position)>3.0: samples.clear()
	samples.append({"time":stamp,"position":position,"velocity":velocity,"yaw":yaw,"serial":serial})
	while samples.size() > 12: samples.pop_front()
	_tracks[id] = samples
func advance(now: float) -> float:
	if native:return native.advance(now)
	if _server_time < 0: return -1
	var target := _server_time+maxf(0,now-_arrived)-_delay
	if _render_time<0 or _last_advance<0:
		_render_time=minf(_server_time,target)
	else:
		var elapsed:=clampf(now-_last_advance,0,.1)
		# Gently refill/drain the buffer instead of freezing when _delay grows.
		var rate:=clampf(1.0+(target-_render_time)*2.0,.9,1.1)
		var next:=_render_time+elapsed*rate
		if next>_server_time:_underruns+=1
		_render_time=minf(_server_time,next)
	_last_advance=now
	return _render_time
func sample(id: int) -> Dictionary:
	if native:return native.sample(id)
	var samples: Array = _tracks.get(id,[])
	if samples.is_empty(): return {}
	while samples.size()>2 and samples[1].time<_render_time: samples.pop_front()
	if _render_time <= samples[0].time: return samples[0]
	for i in range(1,samples.size()):
		if samples[i].time >= _render_time:
			var a: Dictionary = samples[i-1]; var b: Dictionary = samples[i]
			var fraction: float = clampf((_render_time-a.time)/maxf(.001,b.time-a.time),0,1)
			return {"position":a.position.lerp(b.position,fraction),"yaw":lerp_angle(a.yaw,b.yaw,fraction)}
	var last: Dictionary = samples[-1]
	# Hold at the latest known position rather than extrapolate through a wall.
	return last

func erase(id:int)->void:
	if native:native.erase(id)
	else:_tracks.erase(id)
func apply(fighters:Dictionary,mine:int,delta:float)->bool:
	if not native:return false
	native.apply(fighters,mine,delta)
	return true

func push_rows(rows:Array,sample_times:Dictionary,stamp:float,now:float,mine:int,fighters:Dictionary)->bool:
	if not native:return false
	native.push_rows(rows,sample_times,stamp,now,mine,fighters)
	return true
