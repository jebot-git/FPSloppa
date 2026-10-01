extends SceneTree
const Art=preload("res://deathmatch/art.gd")
const Rules=preload("res://deathmatch/experimental/weapon_rules.gd")
const Clips=preload("res://deathmatch/avatars/lod_clips.gd")
const Blend=preload("res://deathmatch/avatars/pose_blend.gd")
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func shape(node: Node3D) -> Array:
	var result: Array=[]
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var colors: Array=[]
		for surface in mesh.mesh.get_surface_count():
			var material: Material=mesh.get_active_material(surface)
			colors.append(material.albedo_color if material is BaseMaterial3D else Color.WHITE)
		var transform_here: Transform3D=mesh.transform;var parent=mesh.get_parent()
		while parent!=node:
			transform_here=parent.transform*transform_here;parent=parent.get_parent()
		result.append(["" if str(mesh.name).begins_with("@") else str(mesh.name),transform_here,mesh.mesh.get_aabb(),colors])
	return result
func run() -> void:
	var orphan_count:=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var rules:=Rules.new()
	for kind in Rules.IDS:
		rules.select(kind)
		for slot in rules.table.size():
			var original:=Art._build_weapon(slot,kind)
			# Compare the complete uncached presentation, including authored mechanisms.
			Art.Presentation.apply(original,slot,kind)
			Art.Presentation.attach(original,slot,kind)
			var first:=Art.weapon(slot,2,kind);var second:=Art.weapon(slot,2,kind)
			check(shape(first)==shape(original) and shape(second)==shape(original),kind+" cached geometry, transforms and tint match source slot "+str(slot))
			check(first.get_meta("muzzle")==second.get_meta("muzzle") and first.get_meta("muzzle")==original.get_meta("muzzle"),"Cached muzzle metadata preserved")
			first.position=Vector3.ONE;first.visible=false
			check(second.position==Vector3.ZERO and second.visible,"Cached model transforms and visibility remain independent")
			if kind=="cs16":
				var action=first.get_node("ChamberAction");action.elapsed=.123;action.manual_stroke=.7
				check(second.get_node("ChamberAction").elapsed!=.123 and second.get_node("ChamberAction").manual_stroke==0,"CS action state remains independent")
			original.free();first.free();second.free()
	check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))==orphan_count,"Cached imported subscenes retire without orphan nodes")
	check(Art.weapon_templates.size()<=Art.TEMPLATE_LIMIT,"Weapon visual cache is bounded")
	var sk:=Skeleton3D.new();root.add_child(sk);sk.add_bone("Bone")
	var blend:=Blend.new();blend.push({0:[Quaternion.IDENTITY,Vector3.ZERO]},.1);blend.apply(sk,0)
	blend.push({0:[Quaternion(Vector3.UP,PI/2),Vector3.RIGHT]},.1);blend.apply(sk,.025)
	check(is_equal_approx(sk.get_bone_pose_position(0).x,.25) and sk.get_bone_pose_rotation(0).angle_to(Quaternion(Vector3.UP,PI/8))<.001,"Remote interpolation advances between samples instead of holding")
	blend.apply(sk,.075)
	check(sk.get_bone_pose_position(0)==Vector3.RIGHT,"Interpolation reaches the accepted sample without extrapolation")
	blend.reset();blend.push({0:[Quaternion.IDENTITY,Vector3.UP*5]},.1);blend.apply(sk,0)
	check(sk.get_bone_pose_position(0)==Vector3.UP*5,"Reset snaps to new life or teleport without crossing old positions");sk.free()
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.5,30);camera.make_current()
	var library:=Library.new();library.entries["sample_d"]={"path":"res://vrm/sample_d.vrm"}
	var actor:=Node3D.new();world.add_child(actor)
	var rig=Loader.create_avatar(library,"sample_d");actor.add_child(rig);rig.set_process(false);rig.motion.pause();rig.solver.active=false;rig.eyes.active=false;rig.mouth.set_process(false);rig.set_weapon(2,"doom")
	rig.xr_pose=preload("res://deathmatch/vr/poses.gd").neutral()
	var head: int=rig.skeleton.find_bone("Head")
	rig.solver._process_modification_with_delta(1.0/90)
	var previous: Quaternion=rig.skeleton.get_bone_pose_rotation(head)
	rig.xr_pose.head.basis=Basis(Vector3.UP,.8);rig.solver.solve_tick=0;rig.solver._process_modification_with_delta(1.0/90)
	var shown: Quaternion=rig.skeleton.get_bone_pose_rotation(head);var target: Quaternion=rig.solver.cached_poses[head][0]
	check(shown.angle_to(previous)>.001 and shown.angle_to(target)>.001,"Real remote IK displays an intermediate pose")
	rig.solver._process_modification_with_delta(1.0/90)
	check(rig.skeleton.get_bone_pose_rotation(head).angle_to(target)<shown.angle_to(target),"Real remote IK continues toward its sample on unsolved frames")
	rig.first_person=true;rig.xr_pose.head.basis=Basis(Vector3.UP,-.5);rig.solver._process_modification_with_delta(1.0/90)
	check(rig.solver.pose_blend.target.is_empty() and rig.skeleton.get_bone_pose_rotation(head).angle_to(rig.solver.cached_poses[head][0])<.001,"Local tracked pose is immediate")
	rig.first_person=false;actor.position.x+=5;rig.solver._process_modification_with_delta(1.0/90)
	check(rig.skeleton.get_bone_pose_rotation(head).angle_to(rig.solver.cached_poses[head][0])<.001,"Teleport invalidates old remote interpolation")
	var gait=rig.gait;var cached: Dictionary=rig.solver.cached_poses.duplicate(true)
	var pose_before: Array=[]
	for index in rig.skeleton.get_bone_count():pose_before.append(rig.skeleton.get_bone_pose(index))
	var description:={"key":"walk2_pistol","state":"walk","direction":2}
	var job:=Clips.BakeJob.new(rig,description)
	for slice in 11:
		var before: int=job.frame;job.step(rig,Clips.SAMPLES_PER_FRAME)
		check(job.frame-before<=2,"Clip slice never performs a full 21-solve bake")
		check(rig.gait==gait and rig.solver.cached_poses==cached,"Slice restores live locomotion and solved pose cache")
		for index in pose_before.size():check(rig.skeleton.get_bone_pose(index).is_equal_approx(pose_before[index]),"Slice leaves live skeleton unchanged")
	var reference: Animation=Clips.bake(rig,description)
	for track in reference.get_track_count():
		check(reference.track_get_key_count(track)==job.clip.track_get_key_count(track),"Sliced clip retains sample count")
		for key in reference.track_get_key_count(track):check(reference.track_get_key_value(track,key)==job.clip.track_get_key_value(track,key),"Sliced clip matches full reference bake")
	var old_bakes: int=Clips.bakes
	check(Clips.obtain(rig,description)==null and Clips.bakes==old_bakes,"Live clip request queues work without synchronous baking")
	for frame in 15:await process_frame
	check(Clips.obtain(rig,description)!=null and Clips.bakes==old_bakes+1,"Queued clip becomes available and is reused")
	rig.xr_pose={};rig.target_xr_pose={};rig.movement=Vector3.FORWARD*4;rig.speed=4
	rig.enable_distance_lod()
	var walk: Animation=Clips.bake(rig,{"key":"walk0_pistol","state":"walk","direction":0})
	rig.distance_lod.clips.add_animation("walk0_pistol",walk)
	var thigh: int=rig.skeleton.find_bone("LeftUpperLeg");var changed:=0;var last:=Quaternion.IDENTITY
	for frame in 6:
		rig.gait.phase=.15+float(frame)*.01;rig.distance_lod.update(1.0/90)
		var pose: Quaternion=rig.skeleton.get_bone_pose_rotation(thigh)
		if frame>0 and pose.angle_to(last)>.0001:changed+=1
		last=pose
	check(rig.distance_lod.using_generic and changed==5,"Prepared distant clip advances on every display frame")
	# Freeing the requester must not keep an avatar or pending job alive.
	Clips.obtain(rig,{"key":"run0_pistol","state":"run","direction":0});actor.free()
	for frame in 2:await process_frame
	check(Clips.pending.is_empty(),"Retired avatars cancel queued work through weak references")
	world.free();library.free()
	var result:={"checks":checks,"failures":failures,"clip_slice_max_us":Clips.maximum_slice_usec}
	print("FRAME_SMOOTHNESS_RESULT ",JSON.stringify(result));quit(0 if failures.is_empty() else 1)
