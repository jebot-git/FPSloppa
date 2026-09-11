extends SceneTree
const Fighter=preload("res://deathmatch/fighter.gd")
const Fixture=preload("res://deathmatch/tests/fixture.gd")
func _initialize():call_deferred("run")
func run() -> void:
	var floor_node:=Node3D.new();root.add_child(floor_node);Fixture.box(floor_node,Vector3(0,-.5,0),Vector3(100,1,100))
	var results: Array=[]
	for mask in [4294967295,1]:
		var lower:=Fighter.new();lower.setup(1,"Lower",Color.WHITE);floor_node.add_child(lower);lower.quake_movement=true
		var upper:=Fighter.new();upper.setup(2,"Upper",Color.WHITE);floor_node.add_child(upper);upper.quake_movement=true;upper.platform_floor_layers=mask;upper.position=Vector3(0,1.7,0)
		for frame in 90:
			await physics_frame;lower.simulate(Vector2.ZERO,0,false,1.0/60);upper.simulate(Vector2.ZERO,0,false,1.0/60)
		var before:=upper.position;var grounded:=upper.is_on_floor()
		lower.position=Vector3(20,0,0);upper.position=Vector3(-20,.05,0);upper.velocity=Vector3.ZERO;upper.reset_view()
		await physics_frame;upper.simulate(Vector2.ZERO,0,false,1.0/60)
		results.append({"mask":mask,"grounded":grounded,"before":str(before),"after":str(upper.position),"displacement":upper.position.distance_to(Vector3(-20,.05,0)),"platform_velocity":str(upper.get_platform_velocity())})
		lower.free();upper.free();await physics_frame
	var actor:=Fighter.new();actor.setup(3,"Lift rider",Color.WHITE);floor_node.add_child(actor);actor.quake_movement=true;actor.position=Vector3(0,1.05,0)
	var world_platform:=AnimatableBody3D.new();world_platform.sync_to_physics=false;world_platform.collision_layer=1
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3,1,3);shape.shape=box;world_platform.add_child(shape);world_platform.position=Vector3(0,.5,0);floor_node.add_child(world_platform)
	for frame in 30:await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
	var old:=actor.position;world_platform.position.x+=.5
	await physics_frame;actor.simulate(Vector2.ZERO,0,false,1.0/60)
	var carry: float=actor.position.x-old.x
	var passed: bool=actor.platform_floor_layers==1 and results[0].displacement>5 and results[1].displacement<.1 and absf(carry-.5)<.05
	print("PLAYER_PLATFORM ",JSON.stringify({"cases":results,"world_carry":carry,"passed":passed}))
	floor_node.free();quit(0 if passed else 1)
