extends SkeletonModifier3D
## Presentation-only tiers. The gameplay collider and server are never affected.
const Clips=preload("res://deathmatch/avatars/lod_clips.gd")
var rig
var tier:=0
var using_generic:=false
var player: AnimationPlayer
var clips:=AnimationLibrary.new()
var last_pose: Dictionary={}
var blend_pose: Dictionary={}
var blend_left:=0.0
var sample_tick:=0.0
var mesh_retry:=0.0
var bone_ids: Array[int]=[]
var arms: Array[int]=[]
var head:=-1
var current_key:=""
var effective_distance:=0.0
func setup(owner_rig) -> void:
	rig=owner_rig
	player=AnimationPlayer.new();player.name="DistantAnimations";rig.add_child(player)
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.add_animation_library("",clips)
	for name_here in Clips.BONES:
		var bone: int=rig.skeleton.find_bone(name_here)
		if bone>=0:bone_ids.append(bone)
	for name_here in ["LeftUpperArm","RightUpperArm"]:
		var bone: int=rig.skeleton.find_bone(name_here)
		if bone>=0:arms.append(bone)
	head=rig.skeleton.find_bone("Head")
	sample_tick=float(rig.get_instance_id()%17)/17.0/30.0
	for mesh in rig.visual_meshes:mesh.visibility_range_end=0;mesh.lod_bias=1.5
	preload("res://deathmatch/avatars/mesh_lod.gd").request(rig)
func choose_tier(camera: Camera3D) -> int:
	if rig.first_person or rig.preview_mode>=0 or rig.dead or camera==null:return 0
	# Magnification keeps a scoped-in avatar detailed. XR uses a conservative full
	# detail policy until per-eye projected size is available (local is always full).
	if camera is XRCamera3D:return 0
	effective_distance=rig.global_position.distance_to(camera.global_position)*tan(deg_to_rad(camera.fov*.5))/tan(deg_to_rad(85*.5))
	if camera.projection==Camera3D.PROJECTION_ORTHOGONAL:effective_distance=camera.size/(2*tan(deg_to_rad(85*.5)))
	var desired:=tier
	var thresholds:=[6.0,18.0,45.0]
	while desired<3 and effective_distance>thresholds[desired]*1.15:desired+=1
	while desired>0 and effective_distance<thresholds[desired-1]*.85:desired-=1
	return desired
func full_pose() -> void:
	if using_generic:switch_generic(false)
	tier=0;rig.solver.active=true
	set_cosmetics(false)
func update(delta: float) -> bool:
	# Preserve tracked first-person poses and the pre-existing XR remote-IK cadence.
	# XR has no generic replacement until headset/per-eye tuning is validated.
	active=not rig.first_person and not rig.get_viewport().get_camera_3d() is XRCamera3D
	if not active:full_pose();return false
	mesh_retry-=delta
	if mesh_retry<=0:
		mesh_retry=2.0+float(rig.get_instance_id()%17)/17.0
		for mesh in rig.visual_meshes:
			if not mesh.mesh.has_meta("cq_mesh_lod"):
				preload("res://deathmatch/avatars/mesh_lod.gd").request(rig);break
	var next:=choose_tier(rig.get_viewport().get_camera_3d())
	if next!=tier:
		tier=next
		# Stagger expensive medium-range solves among residents.
		rig.solver.solve_tick=float(rig.get_instance_id()%17)/17.0/30.0 if tier==1 else 0.0
	var description:=Clips.description(rig)
	var clip: Animation=clips.get_animation(description.key) if clips.has_animation(description.key) else null
	if clip==null and not rig.first_person and rig.preview_mode<0 and not rig.dead:
		# Also warm the currently needed clip while nearby, sharing it by model hash.
		clip=Clips.obtain(rig,description)
		if clip!=null:
			if clips.get_animation_list().size()>=64:
				for key in clips.get_animation_list():
					if key!=current_key:clips.remove_animation(key);break
			clips.add_animation(description.key,clip)
	# Keep the previous generic clip while another resident uses the bake budget.
	# Do not bounce between IK and generic on every direction change/cache miss.
	var generic:=tier>=2 and (clip!=null or using_generic)
	if generic!=using_generic:switch_generic(generic)
	set_cosmetics(tier>=2)
	if not generic:return false
	rig.motion.pause()
	if current_key!=description.key and clip!=null:
		begin_blend();current_key=description.key
		player.play(current_key);player.seek(rig.gait.phase*clip.length,true)
		sample_tick=0
	sample_tick-=delta
	if sample_tick<=0:
		player.seek(rig.gait.phase*player.current_animation_length,true)
		sample_tick+=1.0/(15 if tier==3 else 30)
	return true
func switch_generic(value: bool) -> void:
	begin_blend();using_generic=value;rig.solver.active=not value
	if value:
		# Generic clips own only the major bones. Retire tracked finger/eye poses.
		for index in rig.skeleton.get_bone_count():rig.skeleton.reset_bone_pose(index)
		# A static grip replaces finger tracking, rather than leaving an open T-pose hand.
		for side in ["Left","Right"]:
			for finger in ["Thumb","Index","Middle","Ring","Little"]:
				for joint in ["Proximal","Intermediate","Distal"]:
					var bone: int=rig.skeleton.find_bone(side+finger+joint)
					if bone>=0:rig.skeleton.set_bone_pose_rotation(bone,rig.skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()*Quaternion(Vector3.RIGHT,.8))
	else:
		player.pause();current_key=""
		rig.solver.cached_poses.clear();rig.solver.floor_heights.clear();rig.solver.solve_tick=0
func begin_blend() -> void:
	blend_pose=last_pose.duplicate(true);blend_left=.18
func set_cosmetics(distant: bool) -> void:
	if rig.eyes.active==distant:
		rig.eyes.active=not distant;rig.mouth.set_process(not distant)
		if distant:
			rig.mouth.weights.fill(0);rig.eyes.morph_weights.fill(0);rig.eyes.expression_weights.fill(0)
			rig.eyes.apply_morphs()
			for bone in rig.eyes.eye_bones:rig.skeleton.reset_bone_pose(bone)
	for secondary in rig.secondary_nodes:secondary.set_local_body(distant or rig.first_person)
func _process_modification_with_delta(delta: float) -> void:
	if rig==null:return
	var sk: Skeleton3D=rig.skeleton
	if using_generic:
		# Aim additive in the rig's frame, keeping the baked elbows/hand shapes.
		for bone in arms:aim(sk,bone,rig.aim_pitch)
		if head>=0:aim(sk,head,rig.aim_pitch*.55)
	var weight:=1.0-clampf(blend_left/.18,0,1)
	for bone in bone_ids:
		var rotation:=sk.get_bone_pose_rotation(bone)
		var position:=sk.get_bone_pose_position(bone)
		if blend_left>0 and blend_pose.has(bone):
			rotation=blend_pose[bone][0].slerp(rotation,weight);position=blend_pose[bone][1].lerp(position,weight)
			sk.set_bone_pose_rotation(bone,rotation);sk.set_bone_pose_position(bone,position)
		last_pose[bone]=[rotation,position]
	blend_left=maxf(0,blend_left-delta)
func aim(sk: Skeleton3D,bone: int,pitch: float) -> void:
	var parent:=sk.get_bone_parent(bone)
	var parent_basis:=sk.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
	var axis: Vector3=(parent_basis.inverse()*sk.global_basis.inverse()*rig.global_basis*Vector3.RIGHT).normalized()
	sk.set_bone_pose_rotation(bone,Quaternion(axis,clampf(pitch,-1.4,1.4))*sk.get_bone_pose_rotation(bone))
