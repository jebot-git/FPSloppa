extends RefCounted
## Server-side weapon swing detection. Positions are relative to the headset so
## locomotion, room-scale capsule correction and stick turning cannot create hits.
const DAMAGE := 10
const COOLDOWN := .8
const DESKTOP_REACH := 1.25
const WEAPON_LENGTH := .5
const RADIUS := .10
const SWING_SPEED := 1.0
const RESET_SPEED := .35
const SWING_WINDOW := .22
const KICK_RADIUS := .14
const KICK_SPEED := 1.2
const KICK_MIN_HEIGHT := .18
const KICK_REACH := 1.35

static func reset_motion(state: Dictionary) -> void:
	state.erase("pose")
	state.erase("time")
	state.armed=true
	state.swing_until=0.0

static func sample(state: Dictionary, pose: Dictionary, now: float, weapon: int) -> Dictionary:
	var current: Transform3D=pose.weapon
	current.origin-=pose.head.origin
	var previous: Transform3D=state.get("pose",current)
	var dt: float=now-float(state.get("time",now))
	var changed: bool=state.get("weapon",weapon)!=weapon or state.get("left_handed",pose.left_handed)!=pose.left_handed
	state.pose=current;state.time=now;state.weapon=weapon;state.left_handed=pose.left_handed
	var distance:=maxf(previous.origin.distance_to(current.origin),(previous*(Vector3.FORWARD*WEAPON_LENGTH)).distance_to(current*(Vector3.FORWARD*WEAPON_LENGTH)))
	if dt<.005 or dt>.15 or changed or distance>.65:
		state.armed=true;state.swing_until=0.0
		return {}
	var speed:=distance/dt
	if speed<RESET_SPEED: state.armed=true
	var started:=false
	if speed>=SWING_SPEED and distance>=.025 and state.get("armed",true) and now>=state.get("ready_at",0.0):
		state.armed=false;state.ready_at=now+COOLDOWN;state.swing_until=now+SWING_WINDOW;state.hit=false
		started=true
	if state.get("hit",false) or now>=state.get("swing_until",0.0) or speed<RESET_SPEED: return {}
	# Sweep the whole short weapon volume, including rotational arcs between packets.
	var segments: Array=[]
	for step in range(4):
		var a:=previous.interpolate_with(current,float(step)/4)
		var b:=previous.interpolate_with(current,float(step+1)/4)
		for reach in [0.0,WEAPON_LENGTH*.5,WEAPON_LENGTH]:
			segments.append([a*Vector3(0,0,-reach),b*Vector3(0,0,-reach)])
		segments.append([b.origin,b*Vector3(0,0,-WEAPON_LENGTH)])
	return {"started":started,"segments":segments}

static func sample_foot(state: Dictionary,pose: Dictionary,now: float,side: String) -> Dictionary:
	var foot=pose.get("body",{}).get(side+"_foot")
	if not foot is Transform3D:
		reset_motion(state);return {}
	var current: Vector3=foot.origin-pose.head.origin
	if Vector2(current.x,current.z).length()>KICK_REACH or foot.origin.y<-.1 or foot.origin.y>1.6:
		reset_motion(state);return {}
	var previous: Vector3=state.get("pose",current)
	var dt: float=now-float(state.get("time",now))
	state.pose=current;state.time=now
	var distance:=previous.distance_to(current)
	if dt<.005 or dt>.15 or distance>.65:
		state.armed=true;state.swing_until=0.0;return {}
	# Horizontal extension and a raised foot distinguish kicks from standing/head bob.
	var speed:=Vector2(current.x-previous.x,current.z-previous.z).length()/dt
	if speed<RESET_SPEED:state.armed=true
	var started:=false
	if speed>=KICK_SPEED and distance>=.04 and foot.origin.y>=KICK_MIN_HEIGHT and state.get("armed",true) and now>=state.get("ready_at",0.0):
		state.armed=false;state.ready_at=now+COOLDOWN;state.swing_until=now+SWING_WINDOW;state.hit=false;started=true
	if state.get("hit",false) or now>=state.get("swing_until",0.0) or speed<RESET_SPEED or foot.origin.y<KICK_MIN_HEIGHT:return {}
	return {"started":started,"segments":[[previous,current]]}
