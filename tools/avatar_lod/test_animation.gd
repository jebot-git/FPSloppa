extends SceneTree
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
var failures: Array=[]
var checks:=0
var output:="/tmp/avatar-animation-tests"
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func run() -> void:
	if not OS.get_cmdline_user_args().is_empty():output=OS.get_cmdline_user_args()[0]
	var world:=Node3D.new();root.add_child(world)
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.5,3);camera.current=true
	var library:=Library.new()
	for sample in ["sample_d","sample_f","sample_g"]:
		library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
		var rigs: Array=[]
		for optimized in [false,true]:
			var actor:=Node3D.new();world.add_child(actor)
			var rig=Loader.create_avatar(library,sample);actor.add_child(rig);rig.animation_optimized=optimized;rig.set_process(false)
			rig.solver.active=false;rig.eyes.active=false;rig.mouth.set_process(false);rig.motion.pause()
			for secondary in rig.secondary_nodes:secondary.internal_modifier_node.active=false;secondary.optimize_collisions=optimized
			rigs.append(rig)
		var max_rotation:=0.0;var max_position:=0.0;var max_tail:=0.0
		for frame in 45:
			for rig in rigs:
				for bone in rig.skeleton.get_bone_count():rig.skeleton.reset_bone_pose(bone)
				rig.xr_pose=Poses.neutral();rig.xr_pose.head.origin.y+=sin(frame*.1)*.08
				rig.xr_pose.left.origin.z+=sin(frame*.2)*.1
				rig.xr_pose.body={"left_curls":PackedFloat32Array([.1,.3,.5,.7,.9])}
				rig.solver.solve_tick=0;rig.solver._process_modification_with_delta(1.0/45)
				for secondary in rig.secondary_nodes:secondary.do_process(1.0/45)
			for bone in rigs[0].skeleton.get_bone_count():
				var a: Transform3D=rigs[0].skeleton.get_bone_global_pose(bone)
				var b: Transform3D=rigs[1].skeleton.get_bone_global_pose(bone)
				max_rotation=maxf(max_rotation,a.basis.get_rotation_quaternion().angle_to(b.basis.get_rotation_quaternion()))
				max_position=maxf(max_position,a.origin.distance_to(b.origin))
			for i in rigs[0].secondary_nodes.size():
				for j in rigs[0].secondary_nodes[i].spring_bones_internal.size():
					var a=rigs[0].secondary_nodes[i].spring_bones_internal[j]
					var b=rigs[1].secondary_nodes[i].spring_bones_internal[j]
					for k in a.verlets.size():max_tail=maxf(max_tail,a.verlets[k].current_tail.distance_to(b.verlets[k].current_tail))
		print("POSE_PARITY ",sample," rotation=",max_rotation," position=",max_position," spring_tail=",max_tail)
		check(max_rotation<.003 and max_position<.0001 and max_tail<.0001,sample+" bounded collisions/body preserve legacy pose")
		var rig=rigs[1]
		# Dirty channels must reset correctly, including shared eye/mouth binds.
		for i in 12:rig.eyes.morph_weights[i]=float(i%3)*.13
		rig.mouth.weights=PackedFloat32Array([.2,.3,.1,0,0])
		rig.animation_optimized=false;rig.eyes.apply_morphs()
		var values: Array=[]
		for channel in rig.eyes.channels:values.append(channel[0].get_blend_shape_value(channel[1]))
		rig.animation_optimized=true;rig.eyes.apply_morphs()
		for i in values.size():check(absf(values[i]-rig.eyes.channels[i][0].get_blend_shape_value(rig.eyes.channels[i][1]))<.00001,"Cached facial mixer matches legacy")
		var writes: int=rig.eyes.morph_writes;rig.eyes.apply_morphs()
		check(writes==rig.eyes.morph_writes,"Unchanged morphs are not uploaded")
		rig.dead=true;rig.eyes.morph_weights.fill(0);rig.eyes.apply_morphs()
		for channel in rig.eyes.channels:check(channel[0].get_blend_shape_value(channel[1])==0,"Death clears composed speech")
		rig.dead=false
		for secondary in rig.secondary_nodes:
			secondary.animation_rate=45;secondary.reset_animation_budget();secondary.animation_ticks=0
			for frame in 180:
				for bone in rig.skeleton.get_bone_count():rig.skeleton.reset_bone_pose(bone)
				secondary.do_process(1.0/180)
			check(secondary.animation_ticks>=45 and secondary.animation_ticks<=46,"45 Hz secondary step at 180 render FPS")
			var before: int=secondary.animation_ticks;secondary.do_process(2)
			check(secondary.animation_ticks==before+1,"Stall performs only one bounded catch-up step")
			var resets: int=secondary.animation_resets;rig.get_parent().position.x+=5;secondary.do_process(1.0/180)
			check(secondary.animation_resets==resets+1,"Teleport resets spring velocity")
			for spring in secondary.spring_bones_internal:
				for verlet in spring.verlets:check(verlet.current_tail.is_finite(),"Budget spring tail remains finite")
			secondary.animation_suspended=true;before=secondary.animation_ticks;secondary.do_process(1)
			check(secondary.animation_ticks==before,"Suspended springs do no integration")
		# Approximate mode changes cosmetic DOFs, never the authored skeleton.
		for secondary in rig.secondary_nodes:
			secondary.animation_suspended=false;secondary.animation_rate=0;secondary.simplify_animation=true
			var authored: Array=[];var before_joints:=0
			for spring in secondary.spring_bones_internal:authored.append(spring.springbone.joint_nodes.duplicate());before_joints+=spring.verlets.size()
			secondary.do_process(1.0/60)
			var after_joints:=0
			for i in secondary.spring_bones_internal.size():
				var spring=secondary.spring_bones_internal[i];after_joints+=spring.verlets.size()
				check(spring.springbone.joint_nodes==authored[i],"Simplification leaves imported VRM resources unchanged")
				if spring.simplified:check(spring.simple_colliders.size()<=4,"Approximate chain has at most four collision candidates")
				for verlet in spring.verlets:check(verlet.current_tail.is_finite() and verlet.length>.00001,"Collapsed segment stays finite and nonzero")
			check(after_joints<before_joints,"Programmatic simplification reduces simulated joints")
			secondary.simplify_animation=false;secondary.do_process(1.0/60)
			var restored:=0
			for spring in secondary.spring_bones_internal:restored+=spring.verlets.size()
			check(restored==before_joints,"Full authored chains restore when approximate mode is disabled")
		rig.get_parent().position=Vector3.ZERO
		rig.hide();rig.update_animation_budget(.6);check(rig.animation_sleeping,"Hidden avatar sleeps after grace")
		rig.target_xr_pose=Poses.neutral();rig.target_xr_pose.head.origin.y=1.2
		rig.show();rig.animation_visibility=null # Headless visibility test uses explicit visibility only.
		if DisplayServer.get_name()=="headless":
			rig.update_animation_budget(0);check(not rig.animation_sleeping and is_equal_approx(rig.xr_pose.head.origin.y,1.2),"Wake consumes newest tracking sample")
		rig.secondary_motion_enabled=false;rig.update_animation_budget(0)
		for secondary in rig.secondary_nodes:
			var ticks: int=secondary.animation_ticks;secondary.do_process(.1)
			check(secondary.animation_ticks==ticks,"No-springs diagnostic disables all secondary integration")
		rig.secondary_motion_enabled=true
		var xr:=XRCamera3D.new();world.add_child(xr);xr.current=true
		rig.update_animation_budget(1)
		check(not rig.animation_sleeping,"XR skips unvalidated screen culling")
		for secondary in rig.secondary_nodes:check(secondary.animation_rate==0 and not secondary.simplify_animation,"XR keeps original spring cadence and chain detail")
		xr.free();camera.current=true
		# Conservative pruning must not skip a possible legacy sphere/capsule hit.
		var random:=RandomNumberGenerator.new();random.seed=71
		for capsule in [false,true]:
			var resource:=VRMCollider.new();resource.bone="Head";resource.radius=.12;resource.offset=Vector3(.03,.02,0);resource.tail=Vector3(.02,.3,0);resource.is_capsule=capsule
			var collider=resource.create_runtime(rig,rig.skeleton);collider.update(Transform3D.IDENTITY,Transform3D.IDENTITY,rig.skeleton)
			for sample_index in 100:
				var origin: Vector3=collider.bounds_position+Vector3(random.randf_range(-1,1),random.randf_range(-1,1),random.randf_range(-1,1))
				var length:=random.randf_range(.01,.4);var radius:=.02
				var tail:=origin+Vector3(random.randf_range(-1,1),random.randf_range(-1,1),random.randf_range(-1,1)).normalized()*length
				var reach: float=length+radius+collider.bounds_radius
				if origin.distance_squared_to(collider.bounds_position)>reach*reach:
					check(collider.collision(origin,radius,length,tail).is_equal_approx(tail),"Disjoint collider bound cannot affect the tail")
		for item in rigs:item.get_parent().free()
	if DisplayServer.get_name()!="headless":
		var actor:=Node3D.new();world.add_child(actor)
		var rig=Loader.create_avatar(library,"sample_d");actor.add_child(rig)
		await create_timer(.2).timeout
		check(not rig.animation_sleeping,"Visible actor keeps animating")
		camera.rotation.y=PI
		await create_timer(.8).timeout
		check(rig.animation_sleeping,"Off-screen avatar sleeps after grace")
		var mirror:=SubViewport.new();mirror.size=Vector2i(128,128);mirror.world_3d=root.world_3d;mirror.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(mirror)
		var mirror_camera:=Camera3D.new();mirror.add_child(mirror_camera);mirror_camera.position=Vector3(0,1.5,3);mirror_camera.current=true
		await create_timer(.2).timeout
		check(not rig.animation_sleeping,"Secondary viewport camera prevents false culling")
		mirror.free();camera.rotation.y=0;actor.free()
	FileAccess.open(output+".json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	world.free();library.free();print("ANIMATION_TEST_RESULT ",checks," ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
