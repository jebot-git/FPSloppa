extends RefCounted
## One render timeline for each hull and its attached seats. Never moves colliders.
const HISTORY:=20
var tracks: Dictionary={}
var latest:=-1.0
var arrived:=0.0
var render_time:=-1.0
var previous_now:=-1.0
var jitter:=0.0
var delay:=.075
func clear():
	tracks.clear();latest=-1;arrived=0;render_time=-1;previous_now=-1;jitter=0;delay=.075
func erase(key: int):tracks.erase(key)
func push(key: int,stamp: float,pose: Transform3D):
	var samples: Array=tracks.get(key,[])
	if not samples.is_empty():
		if stamp<samples[-1].time:return
		if stamp==samples[-1].time:samples[-1].pose=pose;return
		# Warps/map resets must not sweep a displayed hull across the map.
		if samples[-1].pose.origin.distance_to(pose.origin)>maxf(10,100*(stamp-samples[-1].time)):samples.clear()
	samples.append({"time":stamp,"pose":pose})
	while samples.size()>HISTORY:samples.pop_front()
	tracks[key]=samples
func received(stamp: float,now: float):
	if stamp<=latest:return
	if latest>=0:jitter=lerpf(jitter,minf(.1,absf((now-arrived)-(stamp-latest))),.1)
	latest=stamp;arrived=now;delay=clampf(.075+jitter*2,.075,.15)
func advance(now: float) -> float:
	if latest<0:return -1
	var target:=minf(latest,latest+maxf(0,now-arrived)-delay)
	if previous_now<0:render_time=target
	else:
		var elapsed:=maxf(0,now-previous_now)
		# Slew clock corrections instead of stepping forward when a packet arrives.
		var rate:=clampf(1+(target-render_time-elapsed)*2,.9,1.1)
		render_time=minf(latest,render_time+elapsed*rate)
	previous_now=now
	return render_time
func sample(key: int,stamp: float,fallback: Transform3D) -> Transform3D:
	var samples: Array=tracks.get(key,[])
	if samples.is_empty():return fallback
	if stamp<=samples[0].time:return samples[0].pose
	for i in range(1,samples.size()):
		if samples[i].time>=stamp:
			var a: Dictionary=samples[i-1];var b: Dictionary=samples[i]
			return a.pose.interpolate_with(b.pose,clampf((stamp-a.time)/maxf(.00001,b.time-a.time),0,1))
	# A missing packet cannot extrapolate a hull or passenger through a wall.
	return samples[-1].pose
