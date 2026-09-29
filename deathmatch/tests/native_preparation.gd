extends SceneTree
const Loader=preload("res://deathmatch/avatars/visual_loader.gd")
const Library=preload("res://deathmatch/avatars/library.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var checks:=0
var failures:Array=[]
func _initialize():run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok and failures.size()<30:failures.append(label);push_error(label)
func run() -> void:
	var world:=Node3D.new();root.add_child(world)
	Fixture.box(world,Vector3(0,-.5,0),Vector3(100,1,100))
	Fixture.box(world,Vector3(.15,.08,-.2),Vector3(.2,.16,.5))
	var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(0,1.5,3);camera.make_current()
	var library:=Library.new()
	for sample in ["sample_d","sample_f","sample_g"]:library.entries[sample]={"path":"res://vrm/"+sample+".vrm"}
	await physics_frame
	for sample in library.entries:
		if not sample in ["sample_d","sample_f","sample_g"]:continue
		for optimized in [false,true]:
			var rigs:Array=[]
			for i in 2:
				var actor:=Node3D.new();world.add_child(actor)
				var rig=Loader.create_avatar(library,sample);actor.add_child(rig);rig.set_process(false);rig.motion.pause();rig.solver.active=false;rig.eyes.active=false;rig.mouth.set_process(false)
				rig.animation_optimized=optimized;rig.solver.native_preparation=i==1
				check(rig.solver.native_pose!=null,"native helper available")
				# Missing optional finger and chest bones must remain harmless.
				if sample=="sample_g":
					for name_here in ["Chest","LeftLittleDistal","RightThumbIntermediate"]:
						var index:int=rig.skeleton.find_bone(name_here)
						if index>=0:rig.skeleton.set_bone_name(index,"Omitted"+name_here)
				rigs.append(rig)
			for frame in 240:
				var t:=frame/90.
				var pose:=preload("res://deathmatch/vr/poses.gd").neutral()
				pose.head=Transform3D(Basis.from_euler(Vector3(sin(t)*.5,cos(t)*.7,.1)),Vector3(sin(t)*.25,1.65-absf(sin(t))*.8,cos(t)*.2))
				pose.left.origin+=Vector3(sin(t)*.5,cos(t)*.3,0);pose.right.origin+=Vector3(0,sin(t)*.2,cos(t)*.4)
				if frame%60>=20:
					pose.body={"hips":Transform3D(Basis(Vector3.UP,t),Vector3(0,.85,0)),"chest":Transform3D(Basis(Vector3.UP,t*.5),Vector3(0,1.2,0)),"left_foot":Transform3D(Basis(Vector3.UP,t*.3),Vector3(-.13,.1,-.1)),"right_foot":Transform3D(Basis(Vector3.UP,-t),Vector3(.13,.15,.1)),"left_curls":PackedFloat32Array([.2,.4,.6,.8,1.]),"right_curls":PackedFloat32Array([1.,.8,.6,.4,.2])}
				if frame%60>=40:
					pose.body.left_knee=Transform3D(Basis.IDENTITY,Vector3(-.15,.4,-.3));pose.body.right_knee=Transform3D(Basis.IDENTITY,Vector3(.15,.4,-.3))
					pose.body.left_hand=pose.left;pose.body.right_hand=pose.right
					pose.body.left_elbow=Transform3D(Basis.IDENTITY,Vector3(-.4,.8,0));pose.body.right_elbow=Transform3D(Basis.IDENTITY,Vector3(.4,.8,0))
				if frame%23<7:pose.snapped_hands={"right":Transform3D(Basis(Vector3.RIGHT,.3),Vector3(.25,1.35,-1.1))}
				for rig in rigs:
					rig.dead=frame>=210 and frame<230;rig.death_time=maxf(0,(frame-210)/15.)
					rig.first_person=frame%40<20;rig.xr_pose=pose.duplicate(true) if frame%90<60 else {};rig.grounded=frame%30<25
					rig.collider_height=1.65-absf(sin(t))*.8;rig.aim_pitch=sin(t)*1.2;rig.weapon_id=2 if frame%2 else 1;rig.recoil=.6;rig.offhand_recoil=.2
					rig.gait.prone_blend=.8 if frame%80>50 else 0;rig.gait.bob=sin(t)*.03;rig.gait.landing=.12;rig.gait.assist_weight=.7
					rig.gait.offsets={"left":Vector3(0,.07,sin(t)*.2),"right":Vector3(0,.1,-sin(t)*.2)}
					rig.pain=.5;rig.pain_direction=Vector3(.2,.1,-.3)
					rig.get_parent().transform=Transform3D(Basis(Vector3.UP,t*.2).scaled(Vector3.ONE*1.1),Vector3(4 if frame>120 else 0,0,0))
					rig.solver._process_modification_with_delta(1./90)
				for index in rigs[0].skeleton.get_bone_count():
					var a:Transform3D=rigs[0].skeleton.get_bone_pose(index);var b:Transform3D=rigs[1].skeleton.get_bone_pose(index)
					check(a.origin.distance_to(b.origin)<.00015 and absf(a.basis.get_rotation_quaternion().dot(b.basis.get_rotation_quaternion()))>.99999,"%s optimized=%s frame=%d bone=%d"%[sample,optimized,frame,index])
				check(rigs[0].solver.floor_heights==rigs[1].solver.floor_heights,"floor cache parity")
			for rig in rigs:rig.get_parent().free()
	world.free();library.free()
	print("NATIVE_PREPARATION_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
