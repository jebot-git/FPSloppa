extends SceneTree
const Rig=preload("res://deathmatch/avatars/rig.gd")
const Bounds=preload("res://deathmatch/avatars/rest_bounds.gd")
var failures:Array=[]
func check(ok:bool,label:String):
	print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func _initialize():call_deferred("run")
func fixture(size_factor:float,hip_height:float,named:bool,influences:int) -> Node3D:
	var model:=Node3D.new();model.position.y=7;model.scale=Vector3.ONE*size_factor
	var sk:=Skeleton3D.new();sk.name="Skeleton";model.add_child(sk)
	var joints={"Hips":["",Vector3(0,hip_height,0)],"Head":["Hips",Vector3(0,1.48,0)]}
	for side in ["Left","Right"]:
		var x:float=.13 if side=="Left" else -.13
		joints[side+"UpperLeg"]=["Hips",Vector3(x,hip_height,0)]
		joints[side+"LowerLeg"]=[side+"UpperLeg",Vector3(x,(hip_height+.08)*.5,0)]
		joints[side+"Foot"]=[side+"LowerLeg",Vector3(x,.08,0)]
		joints[side+"UpperArm"]=["Hips",Vector3(x*1.5,1.3,0)]
		joints[side+"LowerArm"]=[side+"UpperArm",Vector3(x*3.5,1.3,0)]
		joints[side+"Hand"]=[side+"LowerArm",Vector3(x*5,1.3,0)]
	for name_here in joints:
		var index:=sk.get_bone_count();sk.add_bone(name_here)
		var parent:String=joints[name_here][0]
		var position:Vector3=joints[name_here][1]
		if not parent.is_empty():sk.set_bone_parent(index,sk.find_bone(parent));position-=joints[parent][1]
		sk.set_bone_rest(index,Transform3D(Basis.IDENTITY,position));sk.reset_bone_pose(index)
	var mesh:=MeshInstance3D.new();mesh.name="Body";model.add_child(mesh);mesh.skeleton=NodePath("../Skeleton")
	mesh.skin=Skin.new()
	for name_here in ["Head","Hips"]:
		var bind:=Transform3D(Basis.IDENTITY,Vector3(0,-100,0)-joints[name_here][1])
		if named:mesh.skin.add_named_bind(name_here,bind)
		else:mesh.skin.add_bind(sk.find_bone(name_here),bind)
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3(-.2,100,0),Vector3(.2,100,0),Vector3(0,101.7,.1)])
	var bones:=PackedInt32Array();var weights:=PackedFloat32Array()
	for vertex in 3:
		for influence in influences:
			bones.append((vertex+influence)%2);weights.append(1.0 if influence==0 else 0.0)
	arrays[Mesh.ARRAY_BONES]=bones;arrays[Mesh.ARRAY_WEIGHTS]=weights
	mesh.mesh=ArrayMesh.new();mesh.mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if influences==8 else 0)
	sk.force_update_all_bone_transforms()
	return model
func run():
	var world:=Node3D.new();root.add_child(world)
	for size_factor in [.1,1.0,10.0]:
		for hip_height in [.65,.92,1.15]:
			for named in [true,false]:
				var avatar=Rig.new();world.add_child(avatar);avatar.set_process(false)
				var model:=fixture(size_factor,hip_height,named,8 if named else 4);avatar.add_child(model)
				var initial:=Bounds.measure(model)
				print("MEASURE ",initial)
				check(absf(initial.position.y)<.0001 and absf(initial.size.y-1.7)<.0001,"Skinned bounds ignore a 100 m bind-space offset, %s binds"%("named/8-weight" if named else "indexed/4-weight"))
				model.set_meta(Bounds.CACHE_KEY,initial)
				check(avatar.configure(model),"Configure %s× model with hip %s"%[size_factor,hip_height])
				var scaled:AABB=avatar.mesh_bounds(model,Transform3D.IDENTITY)
				check(absf(scaled.position.y)<.0001 and absf(scaled.size.y-1.7)<.0001,"Whole model uniformly fits 1.70 m with soles on floor")
				check(avatar.model.scale.is_equal_approx(Vector3.ONE),"Authored proportions survive tiny/giant unit conversion")
				avatar.xr_pose=preload("res://deathmatch/vr/poses.gd").neutral()
				avatar.xr_pose.body={"hips":Transform3D(Basis.IDENTITY,Vector3(0,.92,0)),"left_foot":Transform3D(Basis.IDENTITY,Vector3(-.13,.08,0)),"right_foot":Transform3D(Basis.IDENTITY,Vector3(.13,.08,0))}
				avatar.solver._process_modification_with_delta(.1)
				var sk:Skeleton3D=avatar.skeleton
				var hip:=sk.to_global(sk.get_bone_global_pose(sk.find_bone("Hips")).origin)
				var foot:=sk.to_global(sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin)
				print("STANCE ",hip," ",foot," neutral ",avatar.neutral_hip_height," ",avatar.neutral_foot_heights)
				check(absf(hip.y-hip_height)<.001 and absf(foot.y-.08)<.004,"Standing tracking preserves authored hip height and planted ankle")
				var scale_before:Vector3=model.scale
				avatar.xr_pose.body.hips.origin.y-=.25;avatar.xr_pose.body.left_foot.origin.y+=.20
				avatar.solver._process_modification_with_delta(.1)
				hip=sk.to_global(sk.get_bone_global_pose(sk.find_bone("Hips")).origin)
				foot=sk.to_global(sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin)
				check(absf(hip.y-(hip_height-.25))<.001 and absf(foot.y-.28)<.004 and model.scale==scale_before,"Physical crouch and raised foot remain motion, never rescaling")
				avatar.free()
	world.free();print("AVATAR_SCALING_RESULT ",JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
