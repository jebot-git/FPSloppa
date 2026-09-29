extends RefCounted
## Independent vehicle data adaptation; legacy constants describe the Scout.
const PRICE:=600
const TEAM_LIMIT:=3
const MAX_VEHICLES:=18
const HP:=.6*100/.66
const SPEED:=50.0
const REVERSE:=2.0
const ALTITUDE:=25.0
const VERTICAL:=10.0
const HALF:=Vector3(2.0,.55,2.8)
const SEAT:=Vector3(0,.15,.25)
const MUZZLE:=Vector3(1.05,.02,-2.9)
const ROCKET_DAMAGE:=.5*100/.66
const ROCKET_SPEED:=65.0
const ROCKET_TERMINAL:=80.0
const ROCKET_ACCEL:=5.0
const ROCKET_RADIUS:=9.5
const ROCKET_CYCLE:=2.0
const ROCKET_LIFE:=10.0
const KINDS:=["scout","lpc","hpc"]
static func definition(kind: String="scout") -> Dictionary:
	if kind=="lpc":return {"name":"LPC","title":"LIGHT TRANSPORT","price":675,"hp":1.5*100/.66,"speed":25.0,"reverse":1.0,"altitude":15.0,"vertical":6.0,"pitch":.175,"bank":.25,"accel":7.0,"turn":.7,"strafe":6.0,"half":Vector3(2.4,.65,3.5),"seats":[Vector3(0,.7,-1.9),Vector3(-1.35,.7,.7),Vector3(1.35,.7,.7)],"ground_scale":.5,"ram":2.0}
	if kind=="hpc":return {"name":"HPC","title":"HEAVY TRANSPORT","price":875,"hp":2.0*100/.66,"speed":25.0,"reverse":1.0,"altitude":15.0,"vertical":6.0,"pitch":.175,"bank":.25,"accel":5.5,"turn":.55,"strafe":5.0,"half":Vector3(3,.7,4.4),"seats":[Vector3(0,.75,-2.6),Vector3(-1.65,.75,.2),Vector3(1.65,.75,.2),Vector3(-1.65,.75,2.1),Vector3(1.65,.75,2.1)],"ground_scale":.125,"ram":2.0}
	return {"name":"SCOUT","title":"SCOUT FLYER","price":PRICE,"hp":HP,"speed":SPEED,"reverse":REVERSE,"altitude":ALTITUDE,"vertical":VERTICAL,"pitch":.5,"bank":.5,"accel":14.0,"turn":1.1,"strafe":12.0,"half":HALF,"seats":[SEAT],"ground_scale":1.0,"ram":1.5}
static func controls(state: Dictionary) -> Dictionary:
	return {"move":state.get("move",Vector2.ZERO).limit_length(1),"yaw":state.get("yaw",0.0),"pitch":clampf(state.get("pitch",0.0),-.5,.5),"jet":state.get("jet_held",state.get("jetpack",false)),"fire":state.get("fire",false),"lift_axis":state.get("vr_device",false),"lift":clampf(state.get("fly",0.0),-1,1)}
static func advance(row: Dictionary,control: Dictionary,height: float,delta: float) -> void:
	# Rate-limited yaw/pitch, VTOL when jetting at idle, cruise along the nose.
	# Banking belongs to the hull visual, never the VR headset transform.
	var d:=definition(row.get("kind","scout"))
	var lift_axis: bool=control.get("lift_axis",false)
	var turn:=clampf(wrapf(float(control.yaw)-float(row.yaw),-PI,PI),-d.turn*delta,d.turn*delta)
	row.yaw=wrapf(row.yaw+turn,-PI,PI)
	var visual_pitch:=clampf(control.pitch,-d.pitch,d.pitch)
	if lift_axis:
		var forward_speed: float=row.velocity.dot(Basis(Vector3.UP,row.yaw)*Vector3.FORWARD)
		visual_pitch=-.12*clampf(forward_speed/d.speed,0,1)
		if control.lift>.18 and control.move.length()<.1 and Vector2(row.velocity.x,row.velocity.z).length()<1:visual_pitch=.10*control.lift
	row.pitch=move_toward(row.pitch,visual_pitch,delta*.7)
	row.bank=move_toward(row.bank,clampf(-turn/maxf(delta,.001)*.35-control.move.x*.2,-d.bank,d.bank),delta)
	var forward:=Basis(Vector3.UP,row.yaw)*Basis(Vector3.RIGHT,0.0 if lift_axis else row.pitch)*Vector3.FORWARD
	var throttle: float=-control.move.y
	var wanted: Vector3=forward*(throttle*d.speed if throttle>=0 else throttle*d.reverse)
	wanted+=Basis(Vector3.UP,row.yaw)*Vector3.RIGHT*control.move.x*d.strafe
	if lift_axis:
		wanted.y=control.lift*d.vertical
		# Begin braking before the ceiling, avoiding a rise/fall oscillation on release.
		wanted.y=minf(wanted.y,sqrt(2*d.accel*maxf(0,d.altitude-height)))
	elif control.jet:wanted.y=maxf(wanted.y,d.vertical)
	elif absf(throttle)<.05:wanted.y=-3.0
	wanted.y=minf(wanted.y,clampf((d.altitude-height)*2,-d.vertical,d.vertical))
	if lift_axis:
		var vertical:=move_toward(float(row.velocity.y),wanted.y,d.accel*delta)
		row.velocity=Vector3(row.velocity.x,0,row.velocity.z).move_toward(Vector3(wanted.x,0,wanted.z),d.accel*delta)
		row.velocity.y=vertical
	else:row.velocity=row.velocity.move_toward(wanted,d.accel*delta)
