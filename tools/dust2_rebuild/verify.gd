extends SceneTree
var world: Node3D
var actor
var report:={"checks":0,"failures":[],"routes":[]}
var data: Dictionary
var region: NavigationRegion3D
func _initialize():run.call_deferred()
func p(a: Array) -> Vector3:return Vector3((a[1]-300)*6,a[2],(400-a[0])*6)/32.0+Vector3.UP*.05
func plan(v: Vector3) -> Array:return [400-v.z*32/6,300+v.x*32/6,(v.y-.05)*32]
func check(ok: bool,label: String):
	report.checks+=1;print("PASS " if ok else "FAIL ",label)
	if not ok:report.failures.append(label)
func walk(points: Array,label: String):
	actor.position=p(points[0]);actor.velocity=Vector3.ZERO
	for settle in 8:
		await physics_frame
		actor.simulate(Vector2.ZERO,0,true,1.0/60)
	var ok:=true
	for i in range(1,points.size()):
		var target:=p(points[i]);var reached:=false
		for frame in 1000:
			await physics_frame
			var delta: Vector3=target-actor.position
			if Vector2(delta.x,delta.z).length()<(.20 if actor.cs16_enabled else .25) and absf(delta.y)<.65:reached=true;break
			var move:=Vector2(delta.x,delta.z).limit_length(1) if actor.cs16_enabled else Vector2(delta.x,delta.z).normalized()
			actor.simulate(move,0,true,1.0/60)
		if not reached:
			print("STUCK ",label," target=",points[i]," at=",plan(actor.position));ok=false;break
	report.routes.append({"name":label,"passed":ok,"end":plan(actor.position)})
	check(ok,label)
func run():
	Engine.physics_ticks_per_second=1000;Engine.time_scale=1000.0/60.0;Engine.max_physics_steps_per_frame=64
	data=JSON.parse_string(FileAccess.get_file_as_string("res://maps/Dust2Rebuilt/manifest.json"))
	world=Node3D.new();root.add_child(world)
	var level=load("res://maps/cache/de_dust2_rebuilt-lightmap1.scn").instantiate();world.add_child(level)
	region=NavigationRegion3D.new();region.navigation_mesh=load("res://maps/navigation/de_dust2_rebuilt.res");world.add_child(region)
	NavigationServer3D.map_set_cell_size(region.get_navigation_map(),region.navigation_mesh.cell_size)
	if "--views" in OS.get_cmdline_user_args():await views();world.free();quit();return
	actor=load("res://deathmatch/fighter.gd").new();actor.setup(1,"Dust2 audit",Color.WHITE);world.add_child(actor);actor.set_physics_process(false)
	if "--cs16" in OS.get_cmdline_user_args():actor.configure_cs16(true)
	await physics_frame;await physics_frame
	var space=world.get_world_3d().direct_space_state
	for arch in data.get("arch_checks",[]):
		var normal:=Vector3.RIGHT if arch.axis=="u" else Vector3.BACK
		for at in arch.jambs:
			var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p(at)-normal*2.5,p(at)+normal*2.5,1))
			check(not hit.is_empty(),"Arch jamb connects floor to crown: "+arch.name+" "+str(at))
		if arch.crown!=null:
			var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p(arch.crown)-normal*2.5,p(arch.crown)+normal*2.5,1))
			check(not hit.is_empty(),"Arch crown joins surrounding masonry: "+arch.name)
	for door in data.get("door_checks",[]):
		var n:=Vector3(door.normal[1],0,-door.normal[0])
		var at:=p(door.wood)-Vector3.UP*.05
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(at-n*.3,at+n*.3,1))
		check(not hit.is_empty(),"Mid double door has solid wooden leaf "+str(door.hinge))
		at=p(door.hinge)-Vector3.UP*.05
		hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.BACK*.5,at+Vector3.FORWARD*.5,1))
		check(not hit.is_empty(),"Mid door hinge attaches to masonry "+str(door.hinge))
	check(space.intersect_ray(PhysicsRayQueryParameters3D.create(p([298,321,48]),p([325,321,48]),1)).is_empty(),"Iconic centre gap remains open")
	for point in [[151,82,237],[151,95,237],[151,108,237]]:
		var query:=PhysicsShapeQueryParameters3D.new();var probe:=SphereShape3D.new();probe.radius=.02;query.shape=probe;query.collision_mask=1;query.transform.origin=p(point)-Vector3.UP*.05
		check(space.intersect_shape(query).is_empty(),"A terrace has no floating trim: "+str(point))
	for v in [82,95,108]:
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(p([112.5,v,246]),p([109.5,v,246]),1))
		check(not hit.is_empty(),"Relocated terrace course has solid wall backing: "+str(v))
	for s in data.spawns:
		var at:=p(s);var query:=PhysicsShapeQueryParameters3D.new();var capsule:=CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.7;query.shape=capsule;query.collision_mask=1;query.transform.origin=at+Vector3.UP*.9
		check(space.intersect_shape(query).is_empty(),"Spawn capsule clear "+str(s))
		var hit=space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.5,at-Vector3.UP*.6,1))
		check(not hit.is_empty(),"Spawn has nearby floor "+str(s))
	for r in data.routes:
		await walk(r.points,r.name)
		var reverse: Array=r.points.duplicate();reverse.reverse();await walk(reverse,r.name+" (return)")
	for attempt in 120:
		if NavigationServer3D.region_get_iteration_id(region.get_rid())>0:break
		await physics_frame
	for r in data.routes:
		var path=NavigationServer3D.map_get_path(region.get_navigation_map(),p(r.points[0]),p(r.points[-1]),true)
		check(not path.is_empty() and path[-1].distance_to(p(r.points[-1]))<1,"Bot navigation: "+r.name)
	# Short A must remain over a clear CT underpass, with an opaque bridge deck.
	var bridge=space.intersect_ray(PhysicsRayQueryParameters3D.create(p([211,213,260]),p([211,213,20]),1))
	check(not bridge.is_empty() and absf(bridge.position.y-7)<.15,"Short A has a solid bridge deck over CT")
	print("DUST2_RESULT ",JSON.stringify(report))
	FileAccess.open("res://test-results/dust2/result.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	world.free();quit(0 if report.failures.is_empty() else 1)
func views():
	root.size=Vector2i(1440,900);root.content_scale_size=Vector2i(1440,900)
	var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.48,.61,.72);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.85,1);env.environment.ambient_light_energy=.6;env.name="Environment";world.add_child(env)
	load("res://deathmatch/maps/atmosphere.gd").apply(world,"de_dust2_rebuilt")
	env.environment.background_mode=Environment.BG_SKY
	var camera=Camera3D.new();camera.fov=78;camera.far=500;world.add_child(camera);camera.make_current()
	for view in data.views:
		camera.position=p(view.eye);camera.look_at(p(view.look))
		await process_frame;await process_frame;await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://test-results/dust2/"+view.name+".png")
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=125
	camera.position=p([400,300,5200]);camera.look_at(p([400,300,0]),Vector3(-1,0,0))
	await process_frame;await process_frame;await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/dust2/overview.png")
