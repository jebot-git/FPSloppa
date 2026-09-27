extends SceneTree
const Models=preload("res://deathmatch/counterstrike/models.gd")
const Art=preload("res://deathmatch/art.gd")
const Scope=preload("res://deathmatch/vr/sniper_scope.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
var failures: Array=[]
var checks:=0
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
	checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:failures.append(label)
func run():
	var stage:=Node3D.new();root.add_child(stage)
	var shared_texture: Texture2D
	for slot in 12:
		var model:=Models.make(slot);stage.add_child(model)
		var action=model.get_node("ChamberAction")
		var kind:="Slide" if slot in [1,2,10] else "Pump" if slot==3 else "Bolt"
		check(slot==0 or action.parts.has(kind),Models.NAMES[slot]+" has the appropriate separate action")
		if slot>0:
			var part: Node3D=action.parts[kind];var rest: Transform3D=part.transform;action.shot();action._process(action.duration*.45)
			check(not part.transform.is_equal_approx(rest),Models.NAMES[slot]+" cycles its action when fired")
			action._process(2);check(part.transform.is_equal_approx(rest),Models.NAMES[slot]+" action returns to battery")
			if action.parts.has("ChargingHandle"):
				check(action.parts.ChargingHandle.transform==action.rest.ChargingHandle,Models.NAMES[slot]+" non-reciprocating handle stays still while firing")
				action.sync([1,slot,20,200,false]);check(action.parts.ChargingHandle.transform!=action.rest.ChargingHandle,Models.NAMES[slot]+" reload chambers through its charging handle")
		if slot in [1,2,10]:
			action.sync([1,slot,0,0,false]);check(action.parts.Slide.position.z>.04,Models.NAMES[slot]+" slide locks on empty")
			action.sync([1,slot,12,0,false]);check(action.parts.Slide.transform==action.rest.Slide,Models.NAMES[slot]+" loaded magazine releases slide")
			action.sync([1,slot,12,0,false,35,0,0,0]);check(action.parts.Slide.position.z>.04,"VR slide stays locked with a freshly inserted magazine")
			action.sync([1,slot,12,0,false,7,0,0,0]);check(action.parts.Slide.transform==action.rest.Slide,"VR slide closes after manual chambering")
		if slot>0:
			var ammo:=Models.ammunition(slot);check(not ammo.find_children("*","MeshInstance3D",true,false).is_empty(),Models.NAMES[slot]+" supplies a visible physical magazine or shell");ammo.free()
			if slot not in [3,4]:
				check(action.parts.has("Magazine"),Models.NAMES[slot]+" has a detachable magazine")
				action.sync([1,slot,0,0,false,1,0,0,0]);check(not action.parts.Magazine.visible,"Ejected magazine is absent from the gun")
				action.sync([1,slot,12,0,false,3,0,0,0]);check(action.parts.Magazine.visible,"Inserted magazine is seated on the gun")
			if slot in [3,9]:
				action.sync([1,slot,3,0,false,3,0,0,0]);action.shot();action._process(.3)
				check(action.parts[kind].transform==action.rest[kind],"VR pump/bolt does not cycle automatically")
				action.sync([1,slot,3,0,false,11,100,0,0]);check(action.parts[kind].position.z>action.rest[kind].origin.z+.09,"VR pump/bolt follows the offhand stroke")
			if slot==8:
				action.sync([1,slot,100,0,false,3,0,100,0])
				check(action.parts.FeedCover.transform.origin==action.rest.FeedCover.origin and action.parts.FeedCover.rotation.x<-1.3,"M249 feed cover lifts around its fixed front hinge")
				action.sync([1,slot,100,0,false,7,0,0,0]);check(action.parts.FeedCover.transform.is_equal_approx(action.rest.FeedCover),"Closed M249 cover returns sight to its aligned position")
		var pose:=Transform3D(Basis(Vector3.UP,.7),Vector3(2,1,3));var held:=Art.held_transform(pose,slot,Art.VR_SCALE,"cs16")
		check((held*Models.grip(slot)).is_equal_approx(pose.origin),Models.NAMES[slot]+" palm anchor aligns with either controller pose")
		var materials:=0
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for i in mesh.mesh.get_surface_count():
				var mat=mesh.get_active_material(i)
				if mat is StandardMaterial3D:
					materials+=1
					if shared_texture==null:shared_texture=mat.albedo_texture
					check(mat.albedo_texture==shared_texture and mat.albedo_texture.get_image().has_mipmaps(),Models.NAMES[slot]+" shares the mipmapped weapon finish")
		check(materials>0,Models.NAMES[slot]+" has drawable surfaces")
		model.free()
	var g=load("res://deathmatch/arena.tscn").instantiate();root.add_child(g);Fixture.setup(g);g.set_process(false);g.set_physics_process(false)
	await physics_frame;await physics_frame
	var awp:=Models.make(9);stage.add_child(awp);awp.position=Fixture.point()+Vector3.UP
	var scope:=Scope.new();stage.add_child(scope)
	var rear: Vector3=awp.to_global(awp.get_meta("scope_rear"));var eye:=Transform3D(Basis.IDENTITY,rear+Vector3.BACK*.12)
	var shot:=Transform3D(Basis.IDENTITY,awp.to_global(Models.muzzle(9)))
	scope.update_view(awp,[eye],shot,true)
	check(scope.active and scope.weapon==awp and scope.camera.fov==Scope.FOV,"AWP activates the existing monocular sniper scope at its physical ocular")
	check(scope.viewport.world_3d==awp.get_world_3d() and scope.camera.cull_mask&Scope.SCOPE_LAYER==0,"Scope shares the arena world and excludes its own weapon")
	eye.origin.x+=.12;scope.update_view(awp,[eye],shot,true)
	check(not scope.active and scope.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Looking outside the eye box disables the AWP scope")
	awp.position=Fixture.point(9.75,0)+Vector3.UP;awp.rotation.y=-PI/2
	rear=awp.to_global(awp.get_meta("scope_rear"));eye=Transform3D(awp.basis,rear+awp.basis.z*.12);shot=Transform3D(awp.basis,awp.to_global(Models.muzzle(9)))
	scope.update_view(awp,[eye],shot,true);check(not scope.active,"Existing scope occlusion blocks an AWP pushed through a wall")
	var result:={"checks":checks,"failures":failures,"passed":failures.is_empty()}
	FileAccess.open("res://test-results/cs16/art.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("CS16_ART_RESULT ",JSON.stringify(result));stage.free();g.free();quit(0 if failures.is_empty() else 1)
