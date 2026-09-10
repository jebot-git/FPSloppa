extends RefCounted
# HMD-local height excludes virtual jumps, stairs and origin recentering.
var baseline:=0.0
var previous:=0.0
var ready:=false
var armed:=false
var cooldown:=0.0
var pending:=0.0
func reset() -> void:ready=false;armed=false;pending=0;cooldown=0
func sample(height: float,dt: float,allowed: bool,grounded: bool) -> void:
	pending=maxf(0,pending-dt);cooldown=maxf(0,cooldown-dt)
	if not allowed or not is_finite(height) or dt<=0 or dt>.1:reset();return
	if not ready:baseline=height;previous=height;ready=true;return
	var velocity: float=(height-previous)/dt
	previous=height
	if absf(velocity)>5:reset();return # tracking discontinuity
	if height<baseline+.045 and absf(velocity)<.35:
		baseline=lerpf(baseline,height,minf(dt*2,1));armed=true
	if armed and grounded and cooldown<=0 and height-baseline>.10 and velocity>.85:
		pending=.15;armed=false;cooldown=.8
func consume() -> bool:
	if pending<=0:return false
	pending=0;return true
