extends "res://deathmatch/tests/native_bots.gd"
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
const Poses=preload("res://deathmatch/vr/poses.gd")
func run() -> void:
	var world:=Node3D.new();root.add_child(world);var library:=Library.new()
	for sample in ["sample_d","sample_f","sample_g"]:library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
	for sample in library.entries:
		var rigs:Array=[]
		for i in 2:
			var actor:=Node3D.new();world.add_child(actor);var rig=Loader.create_avatar(library,sample);actor.add_child(rig);rig.set_process(false);rig.motion.pause();rig.solver.active=false;rig.eyes.active=false;rig.mouth.set_process(false);rigs.append(rig)
		check(rigs[1].eyes.native_channels and rigs[1].native_interpolation,"Native channels loaded")
		rigs[0].eyes.native_channels=false
		for frame in 180:
			var target:=Poses.neutral();var t:=frame*.07
			target.head=Transform3D(Basis(Vector3.UP,t),Vector3(sin(t),1.2,cos(t)));target.left_handed=frame%2==0
			if frame%3:target.offhand_weapon=target.left
			if frame%4:target.body={"hips":target.head,"left_curls":PackedFloat32Array([.2,.3,.4,.5,.6]),"right_foot":target.right}
			target.face={"look":Vector2(sin(t)*.4,cos(t)*.3),"blink":Vector2(absf(sin(t)),absf(cos(t))),"gaze":true,"lids":true,"expression":PackedFloat32Array([absf(sin(t)),.2,.4,0,.8])}
			var delta:float=[0.,1./144,1./60,.2][frame%4]
			for i in 2:
				var rig=rigs[i];rig.target_xr_pose=target.duplicate(true)
				if rig.xr_pose.is_empty():rig.xr_pose=Poses.neutral()
				if i==0:rig.interpolate_tracking_reference(delta)
				else:rig.native_tracking.interpolate_tracking(rig.xr_pose,rig.target_xr_pose,delta)
				rig.dead=frame>=140 and frame<160;rig.mouth.weights=PackedFloat32Array([.7,.4,0,0,.2]);rig.animation_optimized=frame%13!=0
				rig.eyes.update_animation(delta)
			compare(rigs[0].xr_pose,rigs[1].xr_pose,"tracking "+sample+str(frame))
			compare(rigs[0].eyes.morph_weights,rigs[1].eyes.morph_weights,"morph weights")
			check(rigs[0].eyes.morph_writes==rigs[1].eyes.morph_writes,"Dirty cache writes match")
			for c in rigs[0].eyes.channels.size():
				var a:Array=rigs[0].eyes.channels[c];var b:Array=rigs[1].eyes.channels[c]
				check(absf(a[0].get_blend_shape_value(a[1])-b[0].get_blend_shape_value(b[1]))<.00001,"Composed mesh value")
		# Cached instance IDs must safely skip a freed mesh.
		var mesh:=MeshInstance3D.new();var rows:Array=[[mesh,0,.9,[[0,1.]],NAN]];rigs[1].eyes.native_face.configure_morphs(rows);mesh.free()
		check(rigs[1].eyes.native_face.compose_morphs([1.,0,0,0,0,0,0,0,0,0,0,0],PackedFloat32Array(),false)==0,"Freed mesh skipped")
		for rig in rigs:rig.get_parent().free()
	world.free();library.free()
	print("NATIVE_AVATAR_CHANNELS_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
