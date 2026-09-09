extends Node
const OSC=preload("res://deathmatch/vr/osc.gd")
const JOINTS={"hips":XRBodyTracker.JOINT_HIPS,"chest":XRBodyTracker.JOINT_CHEST,"left_foot":XRBodyTracker.JOINT_LEFT_FOOT,"right_foot":XRBodyTracker.JOINT_RIGHT_FOOT,"left_knee":XRBodyTracker.JOINT_LEFT_LOWER_LEG,"right_knee":XRBodyTracker.JOINT_RIGHT_LOWER_LEG,"left_elbow":XRBodyTracker.JOINT_LEFT_LOWER_ARM,"right_elbow":XRBodyTracker.JOINT_RIGHT_LOWER_ARM}
const VIVE={"hips":"waist","chest":"chest","left_foot":"left_foot","right_foot":"right_foot","left_knee":"left_knee","right_knee":"right_knee","left_elbow":"left_elbow","right_elbow":"right_elbow"}
var rig
var enabled:=true
var osc:=OSC.new()
var udp: PacketPeerUDP
var osc_ip:="127.0.0.1"
var osc_port:=9000
var corrections: Dictionary={}
var calibrated:=false
var native_corrections: Dictionary={}
var osc_alignment:=Transform3D.IDENTITY
var status:="No extra tracking detected; using IK"
var role_nodes: Dictionary={}
var permission_message:=""
func setup(value: Node) -> void:
	rig=value
	if rig.get("game") and rig.game.permissions:
		rig.game.permissions.completed.connect(_permission_result)
		rig.game.permissions.request_tracking.call_deferred()
	for key in VIVE:
		role_nodes[key]=rig.controller("Tracker_"+key,"/user/vive_tracker_htcx/role/"+VIVE[key],"default")
	var cfg:=ConfigFile.new()
	if cfg.load("user://tracking.cfg")==OK:
		osc_ip=str(cfg.get_value("slime","source_ip","127.0.0.1"))
		osc_port=clampi(int(cfg.get_value("slime","listen_port",9000)),1024,65535)
		if cfg.get_value("slime","enabled",false): start_osc()
func start_osc() -> void:
	if udp: udp.close()
	udp=PacketPeerUDP.new()
	var err:=udp.bind(osc_port,"127.0.0.1" if osc_ip=="127.0.0.1" else "*",1048576)
	if err!=OK: udp=null; status="OSC port unavailable: "+str(err)
	else: status="SlimeVR OSC listening on UDP "+str(osc_port)+"; stand straight and calibrate"
func toggle_osc() -> void:
	if udp: udp.close(); udp=null; osc.samples.clear(); status="SlimeVR OSC off"
	else: start_osc()
	var cfg:=ConfigFile.new(); cfg.load("user://tracking.cfg")
	cfg.set_value("slime","enabled",udp!=null); cfg.save("user://tracking.cfg")
func _process(_delta: float) -> void:
	if not udp: return
	# A full-body sender can exceed 32 packets/frame, especially after a loading stall.
	# Drain bursts promptly while retaining a hard packet and CPU-work limit.
	var budget:=256
	var deadline:=Time.get_ticks_usec()+1500
	while udp.get_available_packet_count()>0 and budget>0 and Time.get_ticks_usec()<deadline:
		budget-=1
		var packet:=udp.get_packet()
		if udp.get_packet_ip()==osc_ip: osc.parse(packet,Time.get_ticks_msec()*.001)
func external() -> Dictionary:
	var result: Dictionary={}
	for key in role_nodes:
		var node: XRController3D=role_nodes[key]
		if node.get_has_tracking_data(): result[key]=rig.origin.transform*node.transform
		else:
			# Also accept role poses from runtimes/bridges using grip or the older action name.
			var tracker=XRServer.get_tracker(node.tracker)
			if tracker is XRPositionalTracker:
				for pose_name in ["default","grip","tracker_pose"]:
					var tracked=tracker.get_pose(pose_name) if tracker.has_pose(pose_name) else null
					if tracked and tracked.has_tracking_data:
						result[key]=rig.origin.transform*tracked.get_adjusted_transform();break
	var slime:=osc.current(Time.get_ticks_msec()*.001)
	for key in slime:
		if key!="head" and not result.has(key):
			var pose: Transform3D=slime[key]
			pose.origin*=XRServer.world_scale
			result[key]=rig.origin.transform*osc_alignment*pose
	return result
func calibrate() -> void:
	var targets:={"hips":Vector3(0,.92,0),"chest":Vector3(0,1.35,0),"left_foot":Vector3(-.13,.08,0),"right_foot":Vector3(.13,.08,0),"left_knee":Vector3(-.13,.5,-.03),"right_knee":Vector3(.13,.5,-.03),"left_elbow":Vector3(-.4,1.05,0),"right_elbow":Vector3(.4,1.05,0)}
	corrections.clear()
	var head: Transform3D=rig.origin.transform*rig.head.transform if rig.get("head") else Transform3D.IDENTITY
	var facing:=Transform3D(Basis(Vector3.UP,head.basis.get_euler().y),Vector3(head.origin.x,0,head.origin.z))
	# OSC coordinates come from Slime's reset frame, which can face the other way.
	# Align the whole frame, so both translations and rotations turn together.
	var slime:=osc.current(Time.get_ticks_msec()*.001)
	osc_alignment=Transform3D.IDENTITY
	var heading: Basis=Basis.IDENTITY
	var has_heading:=false
	if osc.samples.get("head",{}).has("basis"):
		heading=osc.samples.head.basis;has_heading=true
	elif slime.has("hips"):
		heading=slime.hips.basis;has_heading=true
	if has_heading:
		osc_alignment.basis=Basis(Vector3.UP,rig.origin.basis.inverse().get_euler().y+facing.basis.get_euler().y-heading.get_euler().y)
	if slime.has("head"):
		var from: Vector3=slime.head.origin*XRServer.world_scale
		var to: Vector3=rig.origin.transform.affine_inverse()*head.origin
		osc_alignment.origin=to-osc_alignment.basis*from
		osc_alignment.origin.y=0
	var raw:=external()
	for key in raw: corrections[key]=raw[key].affine_inverse()*facing*Transform3D(Basis.IDENTITY,targets[key])
	native_corrections.clear()
	var native_count:=0
	for tracker in XRServer.get_trackers(XRServer.TRACKER_BODY).values():
		if not tracker is XRBodyTracker or not tracker.has_tracking_data:continue
		var adjustments: Dictionary={}
		for key in JOINTS:
			var flags:int=tracker.get_joint_flags(JOINTS[key])
			if not flags&XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID:continue
			var basis_here:Basis=preload("res://deathmatch/vr/body_basis.gd").native_to_facing(key,tracker.get_joint_transform(JOINTS[key]).basis)
			adjustments[key]=basis_here.inverse()*rig.origin.basis.inverse()*facing.basis
			native_count+=1
		native_corrections[tracker.name]=adjustments
	calibrated=not corrections.is_empty() or native_count>0
	status="Calibrated %d external / %d native targets"%[corrections.size(),native_count] if calibrated else "No body tracking data available to calibrate"
	if rig.get("game") and rig.game.permissions: rig.game.permissions.request_tracking(true)

func _permission_result(permission: String,allowed: bool) -> void:
	if permission in preload("res://deathmatch/vr/permissions.gd").QUEST_TRACKING and allowed:
		permission_message="Tracking access granted. If no joints arrive, restart the app to start the XR trackers."

static func has_body_pose(body: Dictionary) -> bool:
	for joint in JOINTS:
		if body.has(joint): return true
	return false
func sample() -> Dictionary:
	if not enabled or not rig.focused: return {}
	var result: Dictionary={}
	for tracker in XRServer.get_trackers(XRServer.TRACKER_BODY).values():
		if not tracker is XRBodyTracker or not tracker.has_tracking_data: continue
		for key in JOINTS:
			var flags: int=tracker.get_joint_flags(JOINTS[key])
			if flags&XRBodyTracker.JOINT_FLAG_POSITION_VALID and flags&XRBodyTracker.JOINT_FLAG_ORIENTATION_VALID:
				var pose: Transform3D=tracker.get_joint_transform(JOINTS[key])
				pose.origin*=XRServer.world_scale
				pose.basis=preload("res://deathmatch/vr/body_basis.gd").native_to_facing(key,pose.basis)*native_corrections.get(tracker.name,{}).get(key,Basis.IDENTITY)
				result[key]=rig.origin.transform*pose
	var raw:=external()
	for key in raw:
		if corrections.has(key): result[key]=raw[key]*corrections[key]
	# Optional optical hands only animate the avatar. Controllers still own weapons/input.
	for side in ["left","right"]:
		var hand=XRServer.get_tracker("/user/hand_tracker/"+side)
		if not hand is XRHandTracker or not hand.has_tracking_data: continue
		var flags: int=hand.get_hand_joint_flags(XRHandTracker.HAND_JOINT_WRIST)
		if not flags&XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID or not flags&XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID: continue
		var pose: Transform3D=hand.get_hand_joint_transform(XRHandTracker.HAND_JOINT_WRIST)
		pose.origin*=XRServer.world_scale
		result[side+"_hand"]=rig.origin.transform*pose
		var curls:=PackedFloat32Array()
		for joints in [[2,3,4,5],[7,8,9,10],[12,13,14,15],[17,18,19,20],[22,23,24,25]]:
			var a: Vector3=hand.get_hand_joint_transform(joints[1]).origin-hand.get_hand_joint_transform(joints[0]).origin
			var b: Vector3=hand.get_hand_joint_transform(joints[3]).origin-hand.get_hand_joint_transform(joints[2]).origin
			curls.append(clampf(a.angle_to(b)/2.4,0,1) if a.length()>.001 and b.length()>.001 else 0)
		result[side+"_curls"]=curls
	if not result.is_empty(): status="Tracking: "+", ".join(result.keys())
	elif not raw.is_empty(): status="Trackers detected: stand straight and CALIBRATE BODY"
	else: status=permission_message if not permission_message.is_empty() else "No extra tracking data; using animated IK"
	if rig.get("game") and rig.game.permissions:
		var access_status: String=rig.game.permissions.tracking_status()
		if not access_status.is_empty(): status=access_status
	return result
func _exit_tree() -> void:
	if udp: udp.close()
