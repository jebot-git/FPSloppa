extends RefCounted
## Retarget in small main-thread slices, restoring the live rig after each slice.
## Jobs use weak references and share completed clips by avatar and locomotion key.
const BONES=["Hips","Chest","Head","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"]
const Gait=preload("res://deathmatch/avatars/locomotion.gd")
const SAMPLES_PER_FRAME:=2
const MAX_PENDING:=8
static var cache: Dictionary={}
static var pending: Dictionary={}
static var bake_frame:=-1
static var bakes:=0
static var last_slice_usec:=0
static var maximum_slice_usec:=0
static func description(rig) -> Dictionary:
	var flat:=Vector3(rig.movement.x,0,rig.movement.z)
	var direction:=posmod(roundi(atan2(flat.x,-flat.z)/(PI/4)),8) if flat.length()>.2 else 0
	var state: String="idle" if flat.length()<.2 else "run" if flat.length()>6 else "walk"
	if rig.stance!="stand":state=rig.stance+("_idle" if flat.length()<.2 else "")
	if not rig.grounded:state="jump" if rig.movement.y>1 else "fall" if rig.movement.y< -1 else "hover"
	if state in ["idle","crouch_idle","prone_idle","jump","fall","hover"]:direction=0
	return {"key":state+str(direction)+("_pistol" if rig.weapon_id==2 else ""),"state":state,"direction":direction}
static func obtain(rig,description: Dictionary) -> Animation:
	if rig.skeleton.get_bone_count()>256:return null
	var key: String=rig.avatar_hash+":"+str(rig.get_path_to(rig.skeleton))+":"+description.key
	if cache.has(key):return cache[key]
	if not pending.has(key) and pending.size()<MAX_PENDING:
		pending[key]=BakeJob.new(rig,description)
		var tree: SceneTree=rig.get_tree()
		if not tree.process_frame.is_connected(process_pending):tree.process_frame.connect(process_pending)
	return null
static func process_pending() -> void:
	if bake_frame==Engine.get_process_frames():return
	bake_frame=Engine.get_process_frames()
	var started:=Time.get_ticks_usec()
	for key in pending.keys():
		var job: BakeJob=pending[key]
		var rig=job.owner_ref.get_ref()
		if not is_instance_valid(rig) or not rig.is_inside_tree() or not is_instance_valid(rig.skeleton) or rig.dead:
			pending.erase(key);continue
		job.step(rig,SAMPLES_PER_FRAME)
		if job.frame>=21:
			if cache.size()>=64:cache.erase(cache.keys()[0])
			cache[key]=job.clip;bakes+=1;pending.erase(key)
		break
	last_slice_usec=Time.get_ticks_usec()-started
	maximum_slice_usec=maxi(maximum_slice_usec,last_slice_usec)
	if pending.is_empty():
		var tree:=Engine.get_main_loop() as SceneTree
		if tree and tree.process_frame.is_connected(process_pending):tree.process_frame.disconnect(process_pending)
# Offline/reference helper; live avatars only use the budgeted queue above.
static func bake(rig,description: Dictionary) -> Animation:
	var job:=BakeJob.new(rig,description);job.step(rig,21);return job.clip
class BakeJob extends RefCounted:
	var owner_ref: WeakRef
	var description: Dictionary
	var clip: Animation
	var gait=Gait.new()
	var frame:=0
	var ids: Array[int]=[]
	var movement:=Vector3.ZERO
	var stance:="stand"
	var grounded:=true
	func _init(rig,request: Dictionary):
		owner_ref=weakref(rig);description=request.duplicate()
	func prepare(rig) -> void:
		var state: String=description.state
		stance="prone" if state.begins_with("prone") else "crouch" if state.begins_with("crouch") else "stand"
		grounded=state not in ["jump","fall","hover"]
		var speed:=9.4 if state=="run" else 4.0 if state=="walk" else 2.0 if state=="crouch" else 1.0 if state=="prone" else 0.0
		var angle: float=description.direction*PI/4
		movement=Vector3(sin(angle),0,-cos(angle))*speed
		if not grounded:movement.y=3 if state=="jump" else -3 if state=="fall" else 0
		for i in 20:gait.update(.05,movement,stance,grounded,{},false)
		clip=Animation.new();clip.length=1.0/(2.05 if state=="run" else .8 if stance=="prone" else 1.15);clip.loop_mode=Animation.LOOP_LINEAR
		for bone_name in BONES:
			var index: int=rig.skeleton.find_bone(bone_name)
			if index<0:continue
			ids.append(index)
			for type in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D]:
				var track:=clip.add_track(type);clip.track_set_path(track,NodePath(str(rig.get_path_to(rig.skeleton))+":"+bone_name))
	func step(rig,count: int) -> void:
		if clip==null:prepare(rig)
		var sk: Skeleton3D=rig.skeleton
		var saved: Dictionary={}
		for property in ["gait","xr_pose","aim_pitch","recoil","offhand_recoil","collider_height","grounded","preview_mode","pain","weapon_id","first_person","animation_sleeping"]:saved[property]=rig.get(property)
		var positions: Array=[];var rotations: Array=[]
		for index in sk.get_bone_count():positions.append(sk.get_bone_pose_position(index));rotations.append(sk.get_bone_pose_rotation(index))
		var solver=rig.solver;var solver_saved: Dictionary={}
		for property in ["cached_poses","floor_heights","solve_tick","floor_tick","last_floor_position","baking"]:solver_saved[property]=solver.get(property)
		solver.cached_poses={};solver.floor_heights={};solver.baking=true
		rig.gait=gait;rig.xr_pose={};rig.aim_pitch=0;rig.recoil=0;rig.offhand_recoil=0;rig.preview_mode=0;rig.pain=0
		rig.first_person=false;rig.animation_sleeping=false;rig.weapon_id=2 if description.key.ends_with("_pistol") else 3
		rig.collider_height=.65 if stance=="prone" else 1.05 if stance=="crouch" else 1.65;rig.grounded=grounded
		for sample_index in mini(count,21-frame):
			gait.phase=frame/20.0;gait.update(0,movement,stance,grounded,{},false)
			solver.solve_tick=0;solver._process_modification_with_delta(0)
			for index in ids.size():
				clip.position_track_insert_key(index*2,frame*clip.length/20,sk.get_bone_pose_position(ids[index]) if frame<20 else clip.track_get_key_value(index*2,0))
				clip.rotation_track_insert_key(index*2+1,frame*clip.length/20,sk.get_bone_pose_rotation(ids[index]) if frame<20 else clip.track_get_key_value(index*2+1,0))
			frame+=1
		for property in saved:rig.set(property,saved[property])
		for index in sk.get_bone_count():sk.set_bone_pose_position(index,positions[index]);sk.set_bone_pose_rotation(index,rotations[index])
		for property in solver_saved:solver.set(property,solver_saved[property])
