extends SceneTree
const Models=preload("res://deathmatch/counterstrike/models.gd")
const Guide=preload("res://deathmatch/vr/aim_guide.gd")
const Art=preload("res://deathmatch/art.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var stage:=Node3D.new();root.add_child(stage)
	var guide:=Guide.new();stage.add_child(guide)
	for slot in 12:
		var model:=Models.make(slot);stage.add_child(model)
		var pose:=Transform3D(Basis.from_euler(Vector3(.23,.73,-.31)),Vector3(2,3,4))
		model.transform=Art.held_transform(pose,slot,Art.VR_SCALE,"cs16")
		check(Guide.supports_weapon(slot,"cs16")== (slot not in [0,9]),Models.NAMES[slot]+" uses the intended laser policy")
		guide.update(pose,slot,true,"cs16")
		check(guide.visible==(slot not in [0,9]),Models.NAMES[slot]+" actual laser visibility matches policy")
		if slot>0:
			check(model.has_meta("sight_rear") and model.has_meta("sight_front"),Models.NAMES[slot]+" exports physical sight landmarks")
			if model.has_meta("sight_front"):
				var rear: Vector3=model.get_meta("sight_rear");var front: Vector3=model.get_meta("sight_front")
				var direction: Vector3=(front-rear).normalized()
				check(direction.is_equal_approx(Vector3.FORWARD),Models.NAMES[slot]+" front tip and rear centre align along the bore")
				check((model.to_global(front)-model.to_global(rear)).normalized().is_equal_approx(-pose.basis.z),Models.NAMES[slot]+" sights remain aligned with the shot after controller rotation and scaling")
				# Test the exported triangles, not just authored landmark coordinates.
				for mesh in model.find_children("*","MeshInstance3D",true,false):
					if not mesh.visible:continue
					var body:=StaticBody3D.new();mesh.add_child(body)
					var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape();body.add_child(shape)
				await physics_frame;await physics_frame
				var start:=model.to_global(rear+Vector3(0,.0008,.035))
				var finish:=model.to_global(front+Vector3(0,.0008,-.04))
				var hit:=stage.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1))
				check(hit.is_empty(),Models.NAMES[slot]+" has an unobstructed sight channel through its actual mesh")
				if not hit.is_empty():print("OBSTRUCTION ",model.to_local(hit.position)," ",hit.collider.get_parent().name)
		model.free()
	check(not Guide.supports_weapon(9,"ut99") and not Guide.supports_weapon(2,"tf_sniper"),"Existing sniper rules also remain laser-free")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/sights.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_SIGHTS_RESULT ",JSON.stringify(result));stage.free();quit(0 if failures.is_empty() else 1)
