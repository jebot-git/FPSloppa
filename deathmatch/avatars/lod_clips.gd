extends RefCounted
## Retarget procedural poses once per avatar/locomotion clip; replay with native
## AnimationPlayer at range. At most one 21-pose bake per rendered frame globally.
const BONES=["Hips","Chest","Head","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"]
const Gait=preload("res://deathmatch/avatars/locomotion.gd")
static var cache: Dictionary={}
static var bake_frame:=-1
static var bakes:=0
static func description(rig) -> Dictionary:
	var flat:=Vector3(rig.movement.x,0,rig.movement.z)
	var direction:=posmod(roundi(atan2(flat.x,-flat.z)/(PI/4)),8) if flat.length()>.2 else 0
	var state: String="idle" if flat.length()<.2 else "run" if flat.length()>6 else "walk"
	if rig.stance!="stand":state=rig.stance+("_idle" if flat.length()<.2 else "")
	if not rig.grounded:state="jump" if rig.movement.y>1 else "fall" if rig.movement.y< -1 else "hover"
	if state in ["idle","crouch_idle","prone_idle","jump","fall","hover"]:direction=0
	return {"key":state+str(direction)+("_pistol" if rig.weapon_id==2 else ""),"state":state,"direction":direction}
static func obtain(rig,description: Dictionary) -> Animation:
	if rig.skeleton.get_bone_count()>256:return null # Bound main-thread retargeting.
	var key: String=rig.avatar_hash+":"+str(rig.get_path_to(rig.skeleton))+":"+description.key
	if cache.has(key):return cache[key]
	if bake_frame==Engine.get_process_frames():return null
	bake_frame=Engine.get_process_frames()
	var clip:=bake(rig,description)
	if cache.size()>=64:cache.erase(cache.keys()[0])
	cache[key]=clip;bakes+=1;return clip
static func bake(rig,description: Dictionary) -> Animation:
	var sk: Skeleton3D=rig.skeleton
	var saved:={}
	for property in ["gait","xr_pose","aim_pitch","recoil","offhand_recoil","collider_height","grounded","preview_mode"]:saved[property]=rig.get(property)
	var positions: Array=[];var rotations: Array=[]
	for index in sk.get_bone_count():positions.append(sk.get_bone_pose_position(index));rotations.append(sk.get_bone_pose_rotation(index))
	var solver=rig.solver
	var cached: Dictionary=solver.cached_poses.duplicate(true)
	var floors: Dictionary=solver.floor_heights;solver.floor_heights={}
	var old_tick: float=solver.solve_tick;var floor_tick: float=solver.floor_tick
	rig.gait=Gait.new();rig.xr_pose={};rig.aim_pitch=0;rig.recoil=0;rig.offhand_recoil=0;rig.preview_mode=0
	var state: String=description.state
	var stance: String="prone" if state.begins_with("prone") else "crouch" if state.begins_with("crouch") else "stand"
	rig.collider_height=.65 if stance=="prone" else 1.05 if stance=="crouch" else 1.65
	rig.grounded=state not in ["jump","fall","hover"]
	var speed:=9.4 if state=="run" else 4.0 if state=="walk" else 2.0 if state=="crouch" else 1.0 if state=="prone" else 0.0
	var angle: float=description.direction*PI/4
	var movement:=Vector3(sin(angle),0,-cos(angle))*speed
	if not rig.grounded:movement.y=3 if state=="jump" else -3 if state=="fall" else 0
	for i in 20:rig.gait.update(.05,movement,stance,rig.grounded,{},false)
	var length:=1.0/(2.05 if state=="run" else .8 if stance=="prone" else 1.15)
	var clip:=Animation.new();clip.length=length;clip.loop_mode=Animation.LOOP_LINEAR
	var bone_names: Array=[]
	for bone in BONES:
		if sk.find_bone(bone)<0:continue
		bone_names.append(bone)
		for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
			var track:=clip.add_track(type);clip.track_set_path(track,NodePath(str(rig.get_path_to(sk))+":"+bone))
	for frame in 21:
		rig.gait.phase=frame/20.0;rig.gait.update(0,movement,stance,rig.grounded,{},false)
		solver.solve_tick=0;solver._process_modification_with_delta(0)
		for index in bone_names.size():
			var bone: int=sk.find_bone(bone_names[index])
			clip.position_track_insert_key(index*2,frame*length/20,sk.get_bone_pose_position(bone) if frame<20 else clip.track_get_key_value(index*2,0))
			clip.rotation_track_insert_key(index*2+1,frame*length/20,sk.get_bone_pose_rotation(bone) if frame<20 else clip.track_get_key_value(index*2+1,0))
	for property in saved:rig.set(property,saved[property])
	for index in sk.get_bone_count():sk.set_bone_pose_position(index,positions[index]);sk.set_bone_pose_rotation(index,rotations[index])
	solver.cached_poses=cached;solver.floor_heights=floors;solver.solve_tick=old_tick;solver.floor_tick=floor_tick
	return clip
