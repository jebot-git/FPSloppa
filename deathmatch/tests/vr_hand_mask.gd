extends SceneTree
const Mask=preload("res://deathmatch/avatars/first_person_mask.gd")
const Aim=preload("res://deathmatch/vr/aim_support.gd")
const Models=preload("res://deathmatch/counterstrike/models.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func triangle(bone: int) -> Array:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=PackedVector3Array([Vector3.ZERO,Vector3.RIGHT,Vector3.UP])
	arrays[Mesh.ARRAY_BONES]=PackedInt32Array([bone,0,0,0,bone,0,0,0,bone,0,0,0])
	arrays[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array([1,0,0,0,1,0,0,0,1,0,0,0])
	return arrays
func run():
	var sk:=Skeleton3D.new();root.add_child(sk)
	var names: Array[String]=["Hips","Spine","Chest","Head","LeftShoulder","LeftUpperArm","LeftHand","LeftUpperLeg"]
	var parents: Array[int]=[-1,0,1,2,2,4,5,0]
	var skin:=Skin.new()
	for i in names.size():
		sk.add_bone(names[i]);sk.set_bone_parent(i,parents[i]);skin.add_named_bind(names[i],Transform3D.IDENTITY)
	var mesh:=ArrayMesh.new()
	for bone in [2,3,6,7]:mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,triangle(bone))
	var instance:=MeshInstance3D.new();instance.mesh=mesh;instance.skin=skin;root.add_child(instance)
	var arm_material:=StandardMaterial3D.new();arm_material.albedo_color=Color.RED
	instance.set_surface_override_material(2,arm_material)
	Mask.apply(instance,sk,true)
	check(instance.mesh!=mesh and instance.mesh.get_surface_count()==2,"First-person mesh removes the entire chest/head while retaining arm and leg triangles")
	check(instance.get_surface_override_material(0)==arm_material,"Material overrides follow retained surfaces after masking")
	check(mesh.get_surface_count()==4,"Mask does not modify the shared third-person mesh")
	Mask.apply(instance,sk,true,"left")
	check(instance.mesh.get_surface_count()==1,"Keypad glove hides only the replaced hand in addition to head and chest")
	Mask.apply(instance,sk,true)
	check(instance.mesh.get_surface_count()==2 and instance.get_surface_override_material(0)==arm_material,"Leaving keypad contact restores the original avatar hand")
	Mask.apply(instance,sk,false)
	check(instance.mesh==mesh and instance.get_surface_override_material(2)==arm_material,"Returning to third person restores mesh and material indices")
	for w in [3,4,5,6,7,8,9,11]:
		for yaw in [0.0,.7,-1.2]:
			var primary:=Transform3D(Basis.from_euler(Vector3(.2,yaw,.1)),Vector3(.2,1.3,-.3))
			var local: Vector3=(Models.support(w)-Models.grip(w))*.65
			var hand:=Transform3D(Basis.IDENTITY,primary*(local+Vector3(.025,.01,0)))
			var solver:=Aim.new();var result:=solver.solve(primary,hand,w,true,true,"cs16")
			check(solver.engaged and result.origin==primary.origin and (result.basis*local).normalized().dot((hand.origin-primary.origin).normalized())>.9999,"CS support aims from the handguard while preserving the palm: "+str([w,yaw]))
	sk.free();instance.free();Mask.cache.clear();Models.cache.clear()
	print("VR_HAND_MASK_RESULT ",JSON.stringify({"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
