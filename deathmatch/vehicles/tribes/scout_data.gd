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
const KINDS:=["scout","lpc","hpc","wildcat","shrike","havoc","beowulf","thundersword","jericho"]
static func definition(kind: String="scout") -> Dictionary:
	# T2 roles use the same ST controls and damage scale. These are tuned
	# adaptations, not claims of reproducing Torque vehicle physics.
	if kind=="beowulf":return {"name":"BEOWULF","title":"BEOWULF GRAV TANK","price":1100,"hp":600.0,"speed":32.0,"reverse":12.0,"altitude":1.15,"vertical":6.0,"pitch":.12,"bank":.12,"accel":10.0,"turn":.85,"strafe":6.0,"half":Vector3(2.5,1.05,3.6),"seats":[Vector3(0,1,-1.6),Vector3(0,1.45,.9)],"ground_scale":.1,"ram":2.5,"hover":true}
	if kind=="thundersword":return {"name":"THUNDERSWORD","title":"THUNDERSWORD BOMBER","price":1250,"hp":500.0,"speed":45.0,"reverse":6.0,"altitude":90.0,"vertical":12.0,"pitch":.3,"bank":.3,"accel":9.0,"turn":.75,"strafe":9.0,"half":Vector3(3.0,1.1,4.4),"seats":[Vector3(0,1,-2.7),Vector3(0,.6,-.4),Vector3(0,1.1,2.7)],"ground_scale":.2,"ram":2.0}
	if kind=="jericho":return {"name":"JERICHO","title":"JERICHO MOBILE BASE","price":1500,"hp":850.0,"speed":18.0,"reverse":7.0,"altitude":1.25,"vertical":4.0,"pitch":.08,"bank":.08,"accel":5.0,"turn":.55,"strafe":0.0,"half":Vector3(2.5,1.2,4.3),"seats":[Vector3(0,1.2,-2.7),Vector3(0,1.7,.6)],"ground_scale":.08,"ram":3.0,"hover":true}
	if kind=="wildcat":return {"name":"WILDCAT","title":"WILDCAT GRAVCYCLE","price":450,"hp":100.0,"speed":70.0,"reverse":12.0,"altitude":1.3,"vertical":8.0,"pitch":.18,"bank":.25,"accel":22.0,"turn":1.6,"strafe":12.0,"half":Vector3(.85,.55,1.8),"seats":[Vector3(0,.6,.25)],"ground_scale":.2,"ram":1.2,"hover":true}
	if kind=="shrike":return {"name":"SHRIKE","title":"SHRIKE FIGHTER","price":750,"hp":150.0,"speed":75.0,"reverse":8.0,"altitude":85.0,"vertical":18.0,"pitch":.5,"bank":.5,"accel":19.0,"turn":1.25,"strafe":14.0,"half":Vector3(2.0,.75,3.3),"seats":[Vector3(0,.45,.5)],"ground_scale":.5,"ram":1.5}
	if kind=="havoc":return {"name":"HAVOC","title":"HAVOC TRANSPORT","price":1000,"hp":400.0,"speed":35.0,"reverse":5.0,"altitude":65.0,"vertical":9.0,"pitch":.175,"bank":.25,"accel":7.0,"turn":.6,"strafe":7.0,"half":Vector3(3.0,.85,4.4),"seats":[Vector3(0,1,-2.65),Vector3(-1.6,1,-.4),Vector3(1.6,1,-.4),Vector3(-1.6,1,1.6),Vector3(1.6,1,1.6),Vector3(0,1,2.9)],"ground_scale":.2,"ram":2.0}
	if kind=="lpc":return {"name":"LPC","title":"LIGHT TRANSPORT","price":675,"hp":1.5*100/.66,"speed":25.0,"reverse":1.0,"altitude":15.0,"vertical":6.0,"pitch":.175,"bank":.25,"accel":7.0,"turn":.7,"strafe":6.0,"half":Vector3(2.4,.65,3.5),"seats":[Vector3(0,.7,-1.9),Vector3(-1.35,.7,.7),Vector3(1.35,.7,.7)],"ground_scale":.5,"ram":2.0}
	if kind=="hpc":return {"name":"HPC","title":"HEAVY TRANSPORT","price":875,"hp":2.0*100/.66,"speed":25.0,"reverse":1.0,"altitude":15.0,"vertical":6.0,"pitch":.175,"bank":.25,"accel":5.5,"turn":.55,"strafe":5.0,"half":Vector3(3,.7,4.4),"seats":[Vector3(0,.75,-2.6),Vector3(-1.65,.75,.2),Vector3(1.65,.75,.2),Vector3(-1.65,.75,2.1),Vector3(1.65,.75,2.1)],"ground_scale":.125,"ram":2.0}
	return {"name":"SCOUT","title":"SCOUT FLYER","price":PRICE,"hp":HP,"speed":SPEED,"reverse":REVERSE,"altitude":ALTITUDE,"vertical":VERTICAL,"pitch":.5,"bank":.5,"accel":14.0,"turn":1.1,"strafe":12.0,"half":HALF,"seats":[SEAT],"ground_scale":1.0,"ram":1.5}
static func controls(state: Dictionary) -> Dictionary:
	return {"move":state.get("move",Vector2.ZERO).limit_length(1),"yaw":state.get("yaw",0.0),"pitch":clampf(state.get("pitch",0.0),-.5,.5),"jet":state.get("jet_held",state.get("jetpack",false)),"fire":state.get("fire",false),"lift_axis":state.get("vr_device",false),"lift":clampf(state.get("fly",0.0),-1,1)}
static func advance(row: Dictionary,control: Dictionary,height: float,delta: float) -> void:
	# Rate-limited yaw/pitch, VTOL when jetting at idle, cruise along the nose.
	# Banking belongs to the hull visual, never the VR headset transform.
	var d:=definition(row.get("kind","scout"))
	if row.get("deployed",false):row.velocity=Vector3.ZERO;row.pitch=0.;row.bank=0.;return
	var hover: bool=d.get("hover",false)
	var lift_axis: bool=control.get("lift_axis",false) or hover
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
		wanted.y=clampf((d.altitude-height)*5.0,-18.0,d.vertical) if hover else control.lift*d.vertical
		# Begin braking before the ceiling, avoiding a rise/fall oscillation on release.
		if not hover:wanted.y=minf(wanted.y,sqrt(2*d.accel*maxf(0,d.altitude-height)))
	elif control.jet:wanted.y=maxf(wanted.y,d.vertical)
	elif absf(throttle)<.05:wanted.y=-3.0
	if not hover:wanted.y=minf(wanted.y,clampf((d.altitude-height)*2,-d.vertical,d.vertical))
	if lift_axis:
		var vertical:=move_toward(float(row.velocity.y),wanted.y,d.accel*delta)
		row.velocity=Vector3(row.velocity.x,0,row.velocity.z).move_toward(Vector3(wanted.x,0,wanted.z),d.accel*delta)
		row.velocity.y=vertical
	else:row.velocity=row.velocity.move_toward(wanted,d.accel*delta)

const ARMED:=["scout","shrike","beowulf","thundersword","tailgun","jericho"]
static func weapon(kind: String,slot: int) -> String:
	if kind in ["beowulf","thundersword"] and slot in [0,1]:return kind
	if kind=="thundersword" and slot==2:return "tailgun"
	if kind=="jericho" and slot==1:return "jericho"
	return kind if kind in ["scout","shrike"] and slot==0 else ""
static func projectile(kind: String="scout") -> Dictionary:
	if kind=="beowulf":return {"name":"BEOWULF MORTAR","speed":75.0,"terminal":75.0,"accel":0.0,"gravity":18.0,"life":6.0,"cycle":1.4,"damage":140.0,"radius":12.0,"muzzle":Vector3(0,2.1,-4.0)}
	if kind=="thundersword":return {"name":"THUNDERSWORD BOMB","speed":12.0,"terminal":12.0,"accel":0.0,"gravity":24.0,"life":10.0,"cycle":.65,"damage":160.0,"radius":14.0,"muzzle":Vector3(0,-1.35,0)}
	if kind in ["tailgun","jericho"]:return {"name":"TAIL BLASTER" if kind=="tailgun" else "JERICHO TURRET","speed":160.0,"terminal":160.0,"accel":0.0,"life":3.0,"cycle":.25,"damage":20.0,"radius":0.0,"muzzle":Vector3(0,2.5,0)}
	if kind=="shrike":return {"name":"SHRIKE BLASTER","speed":180.0,"terminal":180.0,"accel":0.0,"life":3.0,"cycle":.18,"damage":18.0,"radius":0.0,"muzzle":Vector3(1.25,-.05,-3.4)}
	return {"name":"SCOUT ROCKET","speed":ROCKET_SPEED,"terminal":ROCKET_TERMINAL,"accel":ROCKET_ACCEL,"life":ROCKET_LIFE,"cycle":ROCKET_CYCLE,"damage":ROCKET_DAMAGE,"radius":ROCKET_RADIUS,"muzzle":MUZZLE}
